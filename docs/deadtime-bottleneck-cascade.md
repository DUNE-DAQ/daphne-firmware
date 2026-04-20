# Dead-Time Bottleneck Cascade

This note summarizes the current dead-time bottleneck chain in the self-trigger
readout path and identifies which blocks are worth changing if the design goal
is sustained nominal operation above `10 kHz/channel`.

The key point is simple:

- the shared transport path is not the first bottleneck
- the current per-channel frame builder is

The transport path does matter, especially for timing closure and `full_count`,
but the dominant dead-time term in the current RTL comes from per-channel frame
builder occupancy.

## Current Cascade

| Stage | RTL block | Current mechanism | Main limit | Primary symptom |
| --- | --- | --- | --- | --- |
| 1 | trigger acceptance | a channel only accepts in `wait4trig` | acceptance is gated by builder idle state | `busy_count` |
| 2 | per-channel frame builder | one accepted trigger drives the full `w*`, `h*`, `d*` FSM sequence | one in-flight frame per channel | dominant dead time |
| 3 | per-channel output FIFO | accepted records accumulate in the channel-local XPM FIFO | finite queue depth and `prog_full` threshold | `full_count` |
| 4 | lane arbitration | 20 channels share one lane through `scan -> dump -> pause` | fair-share drain rate and scan latency | transport backpressure |
| 5 | lane selection logic | wide ready scan and combinational data mux | QoR / congestion / timing | LUT pressure, routing pressure |

## Why The Builder Dominates

The current builder accepts an event only in `wait4trig` and then remains busy
until the full frame is serialized.

Relevant RTL:

- [stc3_record_builder.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/subsystems/trigger/stc3_record_builder.vhd:179)
- [stc3_record_builder.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/subsystems/trigger/stc3_record_builder.vhd:228)

The builder FSM does:

- `w0..w3`
- `h0..h8`
- `d0..d31` repeated over `32` blocks

That means one accepted trigger occupies the channel-local builder for a full
1024-sample frame pack. A second trigger on that channel cannot be accepted
until the FSM returns to `wait4trig`.

The dead-time study currently quantifies this builder occupancy as:

- `builder_busy_us = 16.592 us`

That is the real architectural gate on per-channel trigger acceptance.

## Current Quantitative Split

The current stochastic/HDL study gives the following split near the operating
region of interest.

| Nominal rate | Total dead time | Busy drop | Full drop | Transport share of dead time |
| ---: | ---: | ---: | ---: | ---: |
| `10.0 kHz/ch` | `16.65%` | `13.87%` | `2.78%` | `16.7%` |
| `11.0 kHz/ch` | `18.29%` | `14.93%` | `3.36%` | `18.4%` |
| `12.0 kHz/ch` | `20.03%` | `15.89%` | `4.15%` | `20.7%` |
| `13.0 kHz/ch` | `21.92%` | `16.90%` | `5.02%` | `22.9%` |
| `14.0 kHz/ch` | `23.76%` | `17.70%` | `6.06%` | `25.5%` |

So at `10 kHz/channel`, the builder-driven term is already about five times the
transport-driven term.

## Transport Ceiling Versus Builder Penalty

The current shared lane path is:

- [two_lane_readout_mux.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd:27)

It uses:

- `2` lanes
- `20` channels per lane
- `scan -> dump -> pause`
- a wide combinational lane mux at
  [two_lane_readout_mux.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd:50)

Its nominal fair-share ceiling is about:

- `62.5e6 / (232 + 1) / 20 ≈ 13.4 kHz/channel`

That is a real transport limit, but it is not the first limit being hit in the
current `10–14 kHz/channel` study region.

For example:

| Nominal rate | Accepted rate | Builder-only accept | Transport penalty |
| ---: | ---: | ---: | ---: |
| `10.0 kHz/ch` | `8.35 kHz/ch` | `8.59 kHz/ch` | `0.24 kHz/ch` |
| `11.0 kHz/ch` | `8.98 kHz/ch` | `9.30 kHz/ch` | `0.32 kHz/ch` |
| `12.0 kHz/ch` | `9.58 kHz/ch` | `9.99 kHz/ch` | `0.41 kHz/ch` |
| `13.0 kHz/ch` | `10.17 kHz/ch` | `10.71 kHz/ch` | `0.54 kHz/ch` |
| `14.0 kHz/ch` | `10.67 kHz/ch` | `11.36 kHz/ch` | `0.69 kHz/ch` |

That is why transport cleanup alone will not buy a large dead-time reduction in
the regime we care about.

## What Is Worth Doing In The Frame Builder

Yes, there is real architectural work worth doing in the frame builder.

### 1. Decouple trigger acceptance from frame serialization

This is the main change that matters.

Replace the current "accept trigger, then serialize the whole frame immediately"
model with:

- a continuous circular sample buffer per channel
- a small trigger metadata queue per channel
- a shared or semi-shared frame packer that reads windows from the sample RAM
  later

The metadata queue would contain at least:

- channel id
- frame start pointer / timestamp
- peak trailer / trigger metadata

Effect:

- accepted triggers no longer need to wait for a full 1024-sample pack to
  finish
- multiple in-flight triggers per channel become possible
- the hot-path acceptance logic becomes smaller than a full builder FSM

This is the only change in this space that directly attacks the dominant
`busy_count` term.

### 2. Keep payload storage in RAM, not LUT fabric

That direction is aligned with the current resource situation.

The current per-channel output FIFO is already XPM-based and mapped to UltraRAM:

- [sync_fifo_fwft.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/common/primitives/sync_fifo_fwft.vhd:56)

So the right architectural move is not "reinvent the FIFO." It is to move more
of the frame-capture problem into RAM-backed structures and less into wide
replicated control logic.

### 3. Refactor the builder FSM only if the goal is QoR, not dead time

A counter-driven or phased builder implementation may reduce LUT pressure and
ease timing compared to the current explicit state expansion.

But that does not fundamentally change the dead-time model if the architecture
remains:

- one accepted trigger
- one fully serialized frame
- one channel-local builder busy until complete

So this is a secondary QoR cleanup, not the main throughput fix.

## What Is Worth Doing In Transport

Transport work is still justified, but for the second-order term.

### 1. Granularize the lane mux

Instead of a flat `20:1` scan-and-select path per lane, use a small hierarchy,
for example:

- `4 x 5`
- or `5 x 4`

with registered stage boundaries.

This is mainly a timing/congestion optimization and a moderate reduction in the
transport-driven `full_count` term.

### 2. Replace linear ready-scan with an active-source queue

Instead of scanning all `20` `ready_i` lines every cycle, push channel ids into
a ready queue when they become serviceable.

That reduces:

- ready-scan fan-in
- arbitration churn
- wasted scan cycles under sparse traffic

Again, this improves the shared transport path. It does not remove the dominant
builder occupancy term.

### 3. Consider standard-mode FIFO output if timing is the issue

The current FIFO uses `READ_MODE => "fwft"`.

That is helpful functionally, but it does not give you a free output register.
If the main problem becomes timing on the FIFO-to-mux path, a registered
standard-read path may be worth evaluating.

This is a QoR trade, not a dead-time architecture change.

## Recommendation

If the goal is:

- lower dead time above `10 kHz/channel`
- and the design is already near the LUT cliff

then the recommended order is:

1. change the frame-builder architecture first
2. clean up the mux hierarchy second
3. treat FIFO mode / state refactoring as QoR work, not the primary throughput
   fix

The highest-value architecture to study next is:

- per-channel ring buffer
- per-channel trigger queue
- shared or grouped frame packer

That is the cleanest way to move work out of LUT-heavy replicated builders and
into RAM-backed structures while directly reducing the dominant dead-time term.
