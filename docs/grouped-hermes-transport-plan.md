# Grouped Hermes Transport Plan

This note is the working architecture draft for the next self-trigger export
path between the AFEs and the Hermes/10Gb transport.

It starts from the only stable repo-owned hardware line:

- routed-clean baseline: `a389fcd`
- current `main` tip carrying packaging fixes: `eb5f971`

The intent is to reduce replicated packetization logic without casually
breaking the qualified build/deploy path.

## Problem Statement

The current path has two competing failure modes:

1. too much per-channel packet machinery, which is expensive in LUT/control
   logic,
2. too much sharing too early, which is cheaper in area but increases
   contention and dead time.

Previous local studies established the following qualitative result:

- `40` per-channel packet producers are too expensive,
- `5` per-AFE packet producers are better for area but too coarse for dead
  time,
- trigger acceptance must be decoupled from transport-local FIFO watermark
  shortcuts.

That means the redesign target is not simply “more sharing” or “less sharing”.
It is:

- local sample storage,
- compact descriptor queues,
- late packet assembly,
- explicit grouped-source arbitration.

## Current Baseline Path

On the current `main` line, the live self-trigger export path is still:

- frontend samples enter the self-trigger datapath in
  [k26c_selftrigger_datapath_plane.vhd](../rtl/isolated/subsystems/readout/k26c_selftrigger_datapath_plane.vhd),
- the datapath instantiates
  [daphne_composable_core_top.vhd](../rtl/isolated/tops/daphne_composable_core_top.vhd),
- per-AFE self-trigger work is done in
  [afe_selftrigger_island.vhd](../rtl/isolated/subsystems/trigger/afe_selftrigger_island.vhd),
- per-channel packet construction is still done by
  [stc3_record_builder.vhd](../rtl/isolated/subsystems/trigger/stc3_record_builder.vhd),
- `40` channel outputs are scanned by
  [two_lane_readout_mux.vhd](../rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd),
- the two-lane transport handoff is then forwarded to Hermes through
  [k26c_board_hermes_transport_plane.vhd](../rtl/isolated/subsystems/readout/k26c_board_hermes_transport_plane.vhd),
- which still drives the fixed two-source Deimos wrapper in
  [daphne_top.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/daphne_top.vhd).

This baseline matters because the dominant packetization work still happens
before the two-lane arbitration point, which is the main structural reason the
path does not scale well.

Current ownership inside that path:

- raw frontend samples are adapted in
  [frontend_to_selftrigger_adapter.vhd](../rtl/isolated/subsystems/trigger/frontend_to_selftrigger_adapter.vhd),
- trigger metadata is formed per channel in
  [self_trigger_xcorr_channel.vhd](../rtl/isolated/subsystems/trigger/self_trigger_xcorr_channel.vhd),
- peak-descriptor metadata and trailer words are formed per channel in
  [peak_descriptor_channel.vhd](../rtl/isolated/subsystems/trigger/peak_descriptor_channel.vhd),
- waveform payload is delayed and packetized immediately in
  [stc3_record_builder.vhd](../rtl/isolated/subsystems/trigger/stc3_record_builder.vhd),
- the current live path does **not** use a channel-local waveform ring in the
  shipped datapath; it uses a fixed delay line and then serializes directly.

## Stable Constraints

The first architecture phase should preserve:

- one physical 10Gb/Hermes path,
- fixed `512`-sample records,
- fixed Ethernet-visible packet size,
- current PS/device-tree ownership of MAC/IP identity,
- current qualified build and packaging boundary unless explicitly replaced.

## Proposed Direction

The preferred architecture direction is:

- `40` channel-local sample rings,
- `40` compact descriptor queues,
- grouped packet sources feeding Hermes directly,
- packet assembly as late as possible,
- grouped-source count chosen to balance area and dead time.

Current working hypothesis:

- `4` channels per grouped source is the first architecture point worth serious
  study,
- for `40` channels that gives `10` grouped packet sources.

This is meant to avoid both extremes:

- not `40` fully replicated packet producers,
- not `5` overly contended AFE-level shared serializers.

## Dominant Data Structures

Per channel:

- circular sample ring,
- compact frame descriptor queue,
- peak-descriptor side storage.

Per grouped source:

- arbitration over a small set of channel descriptor queues,
- late fixed-record packet assembly,
- no large duplicated waveform payload FIFOs upstream of transport.

At Hermes:

- real grouped sources should be presented directly,
- avoid fake wide shims that preserve dead streams only for compatibility.

## Current Structural Bottlenecks

The current baseline already shows three structural bottlenecks:

1. `40` replicated per-channel record builders in
   [afe_selftrigger_island.vhd](../rtl/isolated/subsystems/trigger/afe_selftrigger_island.vhd),
2. a fixed `40 -> 2` scan-and-dump seam in
   [two_lane_readout_mux.vhd](../rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd),
3. a fixed `2`-source Hermes wrapper in
   [k26c_board_hermes_transport_plane.vhd](../rtl/isolated/subsystems/readout/k26c_board_hermes_transport_plane.vhd)
   and
   [daphne_top.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/daphne_top.vhd).

The redesign should remove replication in that order:

- first, remove unnecessary per-channel packetization,
- second, replace the fake wide transport seam,
- third, widen Hermes only as far as the grouped-source architecture justifies.

Resource-first interpretation:

- the first major LUT/control lever is the repeated per-channel builder FSM in
  [stc3_record_builder.vhd](../rtl/isolated/subsystems/trigger/stc3_record_builder.vhd),
- the first hard exhausted budget on the successful ring2k line is BRAM, not
  DSP,
- the first removable BRAM budget is likely optional spy/debug storage before
  core trigger-path storage is touched.

The dominant replicated structures today are:

- `40` independent trigger channels through the AFE bank hierarchy,
- `40` independent packet builders, each with its own state machine and local
  output FIFO,
- `40`-way ready/data arbitration collapsed only at the final two-lane mux,
- Hermes-side source buffering replicated once per logical source.

Observed bottleneck hierarchy:

- the main replication burden is not the trigger primitive itself,
- it is the per-channel packet-control, FIFO, and serializer machinery inside
  [stc3_record_builder.vhd](../rtl/isolated/subsystems/trigger/stc3_record_builder.vhd),
- the fixed `40 -> 2` mux is structural but probably secondary to the cost of
  `40` packet producers.

## Module Disposition

Modules that should survive largely intact:

- [self_trigger_xcorr_channel.vhd](../rtl/isolated/subsystems/trigger/self_trigger_xcorr_channel.vhd)
- [peak_descriptor_channel.vhd](../rtl/isolated/subsystems/trigger/peak_descriptor_channel.vhd)
- [frontend_to_selftrigger_adapter.vhd](../rtl/isolated/subsystems/trigger/frontend_to_selftrigger_adapter.vhd)
- [trigger_control_adapter.vhd](../rtl/isolated/subsystems/control/trigger_control_adapter.vhd)
- [wib_eth_readout.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/wib_eth_readout.vhd)
- [tx_mux.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/tx_mux.vhd)

Modules that should be split:

- [stc3_record_builder.vhd](../rtl/isolated/subsystems/trigger/stc3_record_builder.vhd)
- [afe_selftrigger_island.vhd](../rtl/isolated/subsystems/trigger/afe_selftrigger_island.vhd)
- [two_lane_readout_mux.vhd](../rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd)
- [k26c_board_hermes_transport_plane.vhd](../rtl/isolated/subsystems/readout/k26c_board_hermes_transport_plane.vhd)
- [daphne_top.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/daphne_top.vhd)

Modules that should retire or be demoted from architectural ownership:

- [ip_repo/daphne_ip/rtl/selftrig/stc3.vhd](../ip_repo/daphne_ip/rtl/selftrig/stc3.vhd)
- [selftrigger_fabric.vhd](../rtl/isolated/subsystems/trigger/selftrigger_fabric.vhd)
- [legacy_deimos_readout_bridge.vhd](../rtl/isolated/subsystems/readout/legacy_deimos_readout_bridge.vhd)

## Architecture Questions To Resolve

The draft must answer these concretely:

1. where exactly descriptors are formed,
2. where grouped arbitration begins,
3. whether Hermes should see `5`, `10`, or some other source count,
4. how much BRAM the Hermes-side source scaling spends,
5. which modules survive, split, or retire,
6. what verification is required before a full build is justified.

## Resource Hypothesis

Known constraint:

- Hermes source scaling is not just a mux-width change.

The current Deimos path instantiates per-source input buffering, so widening
`N_SRC` must be treated primarily as a BRAM decision and secondarily as a LUT
decision.

From direct inspection of the current transport:

- [daphne_top.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/daphne_top.vhd)
  still hard-codes `N_SRC => 2`,
- [k26c_board_hermes_transport_plane.vhd](../rtl/isolated/subsystems/readout/k26c_board_hermes_transport_plane.vhd)
  still presents a fixed two-source seam,
- but the deeper transport in
  [wib_eth_readout.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/wib_eth_readout.vhd),
  [tx_mux.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/tx_mux.vhd),
  and
  [tx_mux_out.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/tx_mux_out.vhd)
  is already generic in `N_SRC`.

The main scaling cost comes from
[tx_mux_ibuf.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/tx_mux_ibuf.vhd),
which allocates one private source buffer per Hermes source. Each additional
source adds one `2048 x 64` async block FIFO at the current top-level
configuration.

Working estimate:

- `N_SRC 2 -> 5`: about `+12` BRAM36-equivalents,
- `N_SRC 2 -> 10`: about `+32` BRAM36-equivalents,
- LUT growth is expected to be secondary and roughly linear.

Working expectation to validate:

- grouped-source transport should recover LUT/control area by removing
  replicated upstream packet paths,
- Hermes-side grouped-source widening will spend BRAM,
- the correct architecture point is the one where the net trade is favorable
  while dead time remains acceptable.

Current resource-first order:

1. budget Hermes `N_SRC` widening explicitly in BRAM,
2. recover LUTs by removing per-channel packet serialization,
3. avoid betting the architecture on `5` producers unless dead-time studies
   prove the contention is acceptable,
4. treat mux micro-cleanups and FIFO-mode tuning as secondary QoR work, not
   the first architectural lever.

Additional resource observation:

- the current successful ring2k line already used `139 / 144` BRAM tiles in the
  documented study reference,
- optional spy/debug paths remain the clearest first BRAM-release lever before
  transport architecture is widened aggressively.

That means `10` grouped Hermes sources are structurally attractive but must be
budgeted against a BRAM-constrained baseline from the outset.

## Formal / Contract Plan

The first useful formal package for this redesign is seam-oriented, not
full-path.

Priority seam contracts:

1. descriptor-source contract
   - once a descriptor is valid, its fields must remain stable until accepted
     or reset,
   - descriptor validity must depend only on explicit trigger/capture
     readiness, not downstream transport state.
2. grouped descriptor-queue contract
   - occupancy never underflows or overflows,
   - enqueue/dequeue accounting is exact,
   - FIFO order is preserved,
   - backpressure to trigger acceptance depends on queue-space policy, not
     transport-local watermark shortcuts.
3. grouped arbiter contract
   - grant is one-hot per lane,
   - no source is read when not ready,
   - packets are not interleaved across sources,
   - a continuously ready source is not starved indefinitely.
4. grouped Hermes source-boundary contract
   - transfer occurs only for `valid && ready`,
   - no word duplication or silent loss at the seam,
   - link status remains transport-owned, not descriptor-owned.

These proofs justify the main architectural simplifications:

- remove trigger admission dependence on packet FIFO watermarks,
- stop revalidating descriptor identity in downstream wrappers,
- replace scan-heavy defensive muxing with a cleaner grouped-source arbiter,
- keep observability counters off the hot path.

## RTL Simulation Plan

The simulation path should be incremental and RTL-wrapped.

Base bench to generalize:

- [multichannel_deadtime_tb_lane.vhd](../../daphne_mezz_xc_sim/hdl/multichannel_deadtime_tb_lane.vhd)

Reason:

- it already models per-channel sources feeding a shared serializer group and a
  downstream shared arbiter,
- it is the closest existing bench to the grouped-source architecture.

Required evolution:

1. generalize AFE-specific naming to grouped-source naming,
2. keep per-channel frame-source modeling local,
3. replace the hardwired AFE serializer instance with the future grouped-source
   serializer once that seam exists,
4. drive the downstream mux with real grouped producer count,
5. extend the RESULT payload beyond aggregate record counts.

Mandatory observables:

- `generated_total`
- `accepted_total`
- `drained_total`
- `sent_total`
- spacing rejects
- queue rejects
- ring rejects
- output/backpressure rejects

Additional grouped-source observables needed:

- `sent_word_total`
- `lane_valid_cycle_total`
- `per_group_sent_total` or `group_sent_min/max`
- `per_channel_accepted_min/max`
- `max_descriptor_queue_occupancy` per group if exposed

Minimal experiment set:

1. four-point smoke comparison at approximately:
   - `4.6 kHz/ch`
   - `10 kHz/ch`
   - `14 kHz/ch`
   - `20 kHz/ch`
2. compare:
   - `40 producers`
   - `5 grouped producers`
   - `10 grouped producers`
3. only if `10 grouped` avoids the queue-dominant failure mode of `5 grouped`,
   run a broader 8-point then 20-point sweep.

Acceptance criteria for dead-time viability:

- below `10 kHz/ch`, queue rejects must not dominate total loss,
- below `10 kHz/ch`, `accepted_total` and `drained_total` must remain close,
- below `10 kHz/ch`, `drained_total` and `sent_total` must remain close,
- grouped starvation must not appear in per-channel acceptance spread.

## Verification Plan

The work should proceed in this order:

1. architecture and contract mapping,
2. resource hypothesis around Hermes/grouped-source scaling,
3. RTL dead-time bench plan for grouped-source variants,
4. formal seam identification,
5. first narrow RTL implementation slice,
6. out-of-context synth where possible before broad integration,
7. full build only after the architecture is coherent.

## Parallel Analysis Lanes

The current draft phase is split across:

1. baseline architecture mapping,
2. Hermes/transport scaling analysis,
3. RTL dead-time study planning,
4. formal/contracts planning,
5. resource/QoR analysis.

Their findings should be integrated back into this note before broad RTL
refactors begin.

## Expected First Implementation Slice

The first implementation slice should be narrow and reversible.

Preferred characteristics:

- introduce a grouped-source seam without replacing the full live datapath,
- keep the qualified path intact,
- make the transport-side resource delta measurable,
- avoid mixing transport experiments with unrelated packaging/build changes.

Concrete first slice:

1. create a generic grouped-source Hermes wrapper that bypasses the fixed
   two-source outer seam while keeping `N_MGT = 1`,
2. support out-of-context comparison points for:
   - `N_SRC = 2`
   - `N_SRC = 5`
   - `N_SRC = 10`
3. do **not** yet replace the live self-trigger datapath,
4. use those synth deltas to decide whether `10` grouped sources are even
   resource-plausible before touching the packet-builder architecture.

Current local scaffold for this slice:

- [grouped_transport_pkg.vhd](../rtl/isolated/subsystems/readout/grouped_transport_pkg.vhd)
  introduces a local grouped-source stream type plus conversion helpers into
  the native Hermes `src_d` transport type,
- [grouped_hermes_readout_bridge.vhd](../rtl/isolated/subsystems/readout/grouped_hermes_readout_bridge.vhd)
  bypasses the fixed two-source
  [daphne_top.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/daphne_top.vhd)
  wrapper and drives
  [wib_eth_readout.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/wib_eth_readout.vhd)
  directly with generic `SOURCE_COUNT_G`,
- [grouped-hermes-readout-bridge.core](../cores/features/grouped-hermes-readout-bridge.core)
  keeps that seam reusable without wiring it into the live K26 path.

Only after that should the branch introduce:

- a descriptor-first split of
  [stc3_record_builder.vhd](../rtl/isolated/subsystems/trigger/stc3_record_builder.vhd)
  into:
  - channel-local capture / descriptor production
  - grouped-source packet assembly

## Immediate Execution Order

The first branch-local execution order should be:

1. introduce grouped-source transport types and a clean wrapper seam,
2. out-of-context synth the transport wrapper for `N_SRC = 2, 5, 10`,
3. record BRAM/LUT deltas against the `2`-source reference,
4. if `10` grouped sources are resource-plausible, generalize the RTL study
   bench from `5` grouped to arbitrary grouped count,
5. only then split
   [stc3_record_builder.vhd](../rtl/isolated/subsystems/trigger/stc3_record_builder.vhd)
   into capture/descriptors vs packet assembly.

This order is deliberate:

- it answers the BRAM question first,
- it avoids rewriting live acquisition logic before the transport cost is
  bounded,
- it keeps the first hardware-facing measurement reversible.

Current status:

- step 1 is now done locally in this draft branch,
- the next concrete action is the out-of-context `N_SRC = 2, 5, 10` transport
  comparison,
- no live readout-plane wiring has been changed yet.

## Stop Conditions

Do not proceed from slice 1 into live datapath surgery if any of the following
are true:

- `N_SRC = 10` transport widening is already unacceptable in BRAM against the
  current baseline,
- the grouped-source RTL smoke shows queue-dominant failure comparable to the
  known `5`-producer trap,
- the wrapper generalization requires deeper Deimos transport changes than the
  current analysis indicates.

If one of those conditions holds, the architecture point must be revised before
the packet-builder split begins.

## Integration Notes

This document is intentionally a draft. The next update should replace the
generic statements above with:

- exact file/module references,
- explicit grouped-source boundary definitions,
- measured or tightly bounded resource estimates,
- the first out-of-context synthesis numbers for the grouped-source bridge.
