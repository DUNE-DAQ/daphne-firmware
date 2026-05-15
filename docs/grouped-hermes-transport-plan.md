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

- the active board candidate uses `4` channels per grouped source, giving `10`
  grouped packet sources for `40` channels,
- `8` channels per grouped source gives the lower-resource `5`-source
  comparison point,
- the final grouping should be chosen from routed resource results plus
  backpressure-aware dead-time/queue-reject measurements.

This is meant to avoid both extremes:

- not `40` fully replicated packet producers,
- not `5` overly contended AFE-level shared serializers.

## Dominant Data Structures

Per channel:

- circular sample ring,
- compact frame descriptor queue,
- peak-descriptor side storage.

Descriptor ownership rule:

- once a grouped serializer claims a matured descriptor, the frame source may
  remove it from the export queue,
- but the frame must remain ring-protected until the serializer explicitly
  releases it after the final payload word,
- ring-retention safety must therefore track both queued and in-flight
  descriptors, not just queue contents.

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
- [eth_readout.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/eth_readout.vhd)
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
  [eth_readout.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/eth_readout.vhd),
  [tx_mux.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/tx_mux.vhd),
  and
  [tx_mux_out.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/tx_mux_out.vhd)
  is already generic in `N_SRC`.

The main scaling cost comes from
[tx_mux_ibuf.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/tx_mux_ibuf.vhd),
which allocates one private source buffer per Hermes source. Each additional
source adds one async 64-bit input FIFO; the current grouped board default keeps
the legacy `2048` words per source.

Historical OOC estimate before the FIFO-depth reduction:

- `N_SRC 2 -> 5`: about `+12` BRAM36-equivalents,
- `N_SRC 2 -> 10`: about `+32` BRAM36-equivalents,
- LUT growth is expected to be secondary and roughly linear.

The legacy `2048`-word default preserves the previous packet-buffering
assumption. The current resource candidate keeps that depth but selects
UltraRAM for grouped Hermes input buffers so the source-count scaling is moved
out of BRAM.

Working expectation to validate:

- grouped-source transport should recover LUT/control area by removing
  replicated upstream packet paths,
- Hermes-side grouped-source widening will spend BRAM,
- the correct architecture point is the one where the net trade is favorable
  while dead time remains acceptable.

Current resource-first order:

1. budget Hermes `N_SRC` widening explicitly in memory and routing,
2. recover LUTs by removing per-channel packet serialization,
3. avoid betting the architecture on `5` producers unless dead-time studies
   prove the contention is acceptable,
4. treat mux micro-cleanups and FIFO-mode tuning as secondary QoR work, not
   the first architectural lever.

Additional resource observation:

- the current successful ring2k line already used `139 / 144` BRAM tiles in the
  documented study reference,
- optional spy/debug paths remain the clearest first BRAM-release lever before
  transport architecture is widened aggressively,
- this branch carries generic gates for input spy capture and grouped output spy
  capture, but the normal board-bring-up defaults keep both enabled because they
  are essential diagnostics.

That means `10` grouped Hermes sources are structurally attractive but must be
budgeted against a BRAM-constrained baseline from the outset. The branch default
now chooses the `10`-source UltraRAM measurement point; `5` sources remains the
routed reference override.

## Measured Evidence So Far

The draft now has two concrete measurements behind it.

### OOC Grouped-Source Transport Scaling

The grouped-source OOC lane was run for the `tx_mux` seam at `N_SRC = 2, 5, 10`.

Observed utilization:

- `src2`: `1830` LUT, `3222` FF, `8` BRAM
- `src5`: `4314` LUT, `7788` FF, `20` BRAM
- `src10`: `8441` LUT, `15398` FF, `40` BRAM

Interpretation:

- BRAM scaling is close to linear and matches the source-buffer hypothesis,
- LUT/FF scaling is also close to linear,
- `N_SRC = 10` is not disqualified on transport-side soft logic grounds,
- the measured pre-URAM widening cost was BRAM; the current candidate shifts
  the two largest storage classes into URAM, leaving LUT/routing as the next
  signoff risk.

### RTL Grouped-Producer Smoke Study

The grouped dead-time bench was updated to compare grouped producer counts
directly against the dormant grouped-source RTL modules on this branch.

Short smoke sweep (`40` channels, `1` repeat, shortened measurement window):

- `5 x 8` grouped producers:
  - `4.6 kHz/ch`: dead fraction `0.243421`, accepted `115`
  - `9.7 kHz/ch`: dead fraction `0.531690`, accepted `133`
  - `14.9 kHz/ch`: dead fraction `0.740079`, accepted `131`
  - `20.0 kHz/ch`: dead fraction `0.812883`, accepted `122`
- `10 x 4` grouped producers:
  - `4.6 kHz/ch`: dead fraction `0.236842`, accepted `116`
  - `9.7 kHz/ch`: dead fraction `0.500000`, accepted `142`
  - `14.9 kHz/ch`: dead fraction `0.722222`, accepted `140`
  - `20.0 kHz/ch`: dead fraction `0.799080`, accepted `131`

Observed counter split:

- the `10 x 4` case is consistently better than `5 x 8`,
- the improvement comes mainly from fewer queue rejects,
- ring rejects remain material in both cases,
- the absolute dead-time level is still poor, so the grouped-source direction
  is not ready for the live datapath just because `10` beats `5`.

Important limitation:

- this bench is still using the dormant grouped serializer path and the current
  mux/readout seam,
- `sent_total` is not yet a decision-grade transport completion metric in this
  bench,
- the useful signal today is acceptance-side behavior and relative comparison
  between grouped-source counts.

### Full K26C 10-Source URAM Compact Build

The `10 x 4` grouped-source candidate now has a complete K26C implementation
result.

Build point:

- branch: `marroyav/grouped-hermes-resource-build-candidate`
- commit: `79da1c9` (`Fix frontend control CDC timing cuts`)
- build host/run: `/w/q`, run id `20260514-205854`
- output directory: `/w/q/xilinx/output-79da1c9-src10-uram-compact`
- synced evidence bundle:
  `/nfs/home/marroyav/fnal-sync/grouped-hermes-resource-build-79da1c9-20260515`

The full chain completed synthesis, placement, routing, bitstream generation,
XSA export, and device-tree overlay packaging. Post-route timing is clean:

- WNS: `+0.073 ns`
- TNS: `0.000 ns`
- WHS: `+0.010 ns`
- THS: `0.000 ns`
- failing setup/hold endpoints: `0`

Post-route utilization:

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| CLB LUTs | 84,408 | 117,120 | 72.07% |
| CLB registers | 141,374 | 234,240 | 60.35% |
| BRAM tiles | 48 | 144 | 33.33% |
| RAMB36/FIFO | 43 | 144 | 29.86% |
| RAMB18 | 10 | 288 | 3.47% |
| URAM | 40 | 64 | 62.50% |
| DSP | 0 | 1,248 | 0.00% |

Interpretation:

- moving grouped sample rings and grouped Hermes input buffers to UltraRAM
  cleared the previous BRAM pressure,
- compact descriptors and grouped resource defaults reduced LUT pressure enough
  for legal routing and positive timing slack,
- the frontend control CDC constraint fix at `79da1c9` resolved the previous
  `clk_pl_0 -> clk125_1` timing failure without changing the architecture,
- the current blocker is no longer FPGA fit or route legality; it is board
  smoke validation.

Residual warnings to track:

- `timing_endpoint_cdc.tcl:88` still produces an empty false-path startpoint
  warning for one endpoint completion flag,
- the XXV Ethernet generated IP still reports the expected evaluation-license
  critical warning,
- post-route methodology still reports TIMING-6, TIMING-7, TIMING-17, plus
  lower-priority TIMING-9/18/26/30 warnings.

These warnings should be classified and cleaned up, but they do not invalidate
the reported timing closure.

### DAPHNE-15 Initial Board Smoke

The `79da1c9` PL payload has been loaded on DAPHNE-15 for first board smoke.
The deployed payload files were:

- `daphne_grouped_selftrigger_ol_79da1c9.bin`
- `daphne_grouped_selftrigger_ol_79da1c9.dtbo`

They were staged into the active legacy-named app slot:

```text
/lib/firmware/xilinx/daphne_selftrigger_ol_a389fcd/
```

The `xmutil` slot name therefore still reports
`daphne_selftrigger_ol_a389fcd`, but the loaded PL payload is the grouped
`79da1c9` candidate. The previous slot payload was backed up on the board at:

```text
/home/petalinux/backup-daphne_selftrigger_ol_a389fcd-20221110T110606Z
```

That backup timestamp is board-local time after reboot, not reliable wall-clock
time.

Post-reboot board state:

- `fpga_manager`: `operating`
- `xmutil`: `daphne_selftrigger_ol_a389fcd` active in slot 0
- services active: `firmware`, `clockchip`, `endpoint`, `hermes`, `daphne`
- `daphneServer` listening on TCP `40001`
- `hermes_udp_srv` listening on UDP `50001`
- `/dev/i2c-1` and `/dev/i2c-2` present

Control-plane checks were run with the newer `ControlEnvelopeV2` / `MT2_*`
client from `/nfs/home/marroyav/repo/daphne-server`. The older local
`daphneZMQ` V1 client timed out, which is a protocol mismatch with the deployed
server rather than evidence of a PL failure.

Observed V2 checks:

| Check | Result | Interpretation |
| --- | --- | --- |
| `READ_TEST_REG` | `success=true`, message `ok` | Basic control read path responds. |
| `READ_CURRENT_MONITOR` | response with `success=false` | Current monitor is not implemented in the firmware drivers. |
| `DO_SOFTWARE_TRIGGER` | `success=true` | Software trigger command is accepted. |
| `DUMP_SPYBUFFER`, channel 0, 8 samples | `success=true`, 8 samples returned | Spy-buffer read path responds through the deployed stack. |

The trigger counters for channel 0 did not increment across the software
trigger command. Treat this as an open semantic/coverage item: this
configuration may not count software triggers in the self-trigger counters, or
the exercised path may not be the counter path that needs validation.

Current interpretation:

- initial board load, service startup, control-plane access, and one spy-buffer
  read have passed,
- the current-monitor failure is a known software/driver implementation gap,
  not a grouped PL fit/timing failure,
- the candidate still needs data-path qualification under real trigger and
  Hermes UDP traffic before it can be called board-ready.

Recommended next board tests:

1. capture Hermes UDP output while issuing software and self-trigger stimuli,
2. verify packet headers, source IDs, and frame/word counts against the grouped
   frame format,
3. exercise link-side backpressure or receive-side throttling and watch the
   ready-aware grouped serializer/Hermes input-buffer seam,
4. compare channel trigger counters using real self-trigger input, not only the
   software-trigger command,
5. dump spy buffers from several channels/producers to confirm the debug window
   still covers the intended points in the grouped architecture,
6. fix or annotate the board clock so future backup/deploy timestamps are
   audit useful.

## Current Draft Implementation

This branch now carries a first real grouped alternative to the live path.

New grouped self-trigger/export modules:

- [afe_grouped_selftrigger_island.vhd](../rtl/isolated/subsystems/trigger/afe_grouped_selftrigger_island.vhd)
  - `8` channel-local `stc3_frame_source` instances,
  - default `1` grouped serializer at `8` channels per AFE,
  - optional `2` grouped serializers at `4` channels each for the `10`-source
    study point,
  - continuous grouped stream export as a branch-local draft seam.
- [grouped_selftrigger_fabric.vhd](../rtl/isolated/subsystems/trigger/grouped_selftrigger_fabric.vhd)
  - `5` grouped AFE islands,
  - default `5` grouped producer streams total.
- [grouped_selftrigger_fabric_bridge.vhd](../rtl/isolated/subsystems/control/grouped_selftrigger_fabric_bridge.vhd)
  - legacy frontend/control inputs in,
  - grouped producer streams out.
- [k26c_grouped_hermes_transport_plane.vhd](../rtl/isolated/subsystems/readout/k26c_grouped_hermes_transport_plane.vhd)
  - board-local grouped Hermes wrapper,
  - aligned to the grouped-source stream type.
- [k26c_board_grouped_outbuffer_plane.vhd](../rtl/isolated/subsystems/readout/k26c_board_grouped_outbuffer_plane.vhd)
  - grouped-to-legacy debug/outbuffer shim,
  - preserves the existing outbuffer AXI and debug shape by tapping the first
    two grouped producers only.
- [k26c_board_grouped_transport_plane.vhd](../rtl/isolated/subsystems/readout/k26c_board_grouped_transport_plane.vhd)
  - board-local grouped transport composition,
  - keeps Hermes and outbuffer ownership split, but the grouped outbuffer shim
    is now generic-gated for resource studies.

Supporting branch-local core additions:

- [grouped-transport-types.core](../cores/common/grouped-transport-types.core)
- [stc3-frame-source.core](../cores/features/stc3-frame-source.core)
- [afe-stc3-stream-serializer.core](../cores/features/afe-stc3-stream-serializer.core)
- [afe-grouped-selftrigger-island.core](../cores/features/afe-grouped-selftrigger-island.core)
- [grouped-selftrigger-fabric.core](../cores/features/grouped-selftrigger-fabric.core)
- [grouped-selftrigger-fabric-bridge.core](../cores/features/grouped-selftrigger-fabric-bridge.core)
- [k26c-grouped-hermes-transport-plane.core](../cores/features/k26c-grouped-hermes-transport-plane.core)
- [k26c-board-grouped-outbuffer-plane.core](../cores/features/k26c-board-grouped-outbuffer-plane.core)
- [k26c-board-grouped-transport-plane.core](../cores/features/k26c-board-grouped-transport-plane.core)
- [k26c-grouped-selftrigger-datapath-plane.core](../cores/features/k26c-grouped-selftrigger-datapath-plane.core)
- [k26c-board-grouped-selftrigger-plane.core](../cores/features/k26c-board-grouped-selftrigger-plane.core)

Draft paired wrapper cut:

- [k26c_grouped_selftrigger_datapath_plane.vhd](../rtl/isolated/subsystems/readout/k26c_grouped_selftrigger_datapath_plane.vhd)
  pairs the grouped self-trigger bridge with the threshold register bank,
- [k26c_board_grouped_selftrigger_plane.vhd](../rtl/isolated/subsystems/readout/k26c_board_grouped_selftrigger_plane.vhd)
  pairs that grouped datapath plane with the grouped transport wrapper and
  exposes the legacy outbuffer/debug side only when `ENABLE_OUTBUFFER_G` is
  explicitly enabled.

Recent resource cleanup:

- [axilite_null_slave.vhd](../rtl/isolated/common/primitives/axilite_null_slave.vhd)
  terminates disabled debug AXI-Lite windows without instantiating capture RAMs,
- [k26c_board_shell.vhd](../rtl/isolated/tops/k26c_board_shell.vhd)
  now gates the legacy input spy-capture plane with `ENABLE_SPY_CAPTURE_G`,
  while defaulting on for board diagnostics,
- [k26c_grouped_selftrigger_datapath_plane.vhd](../rtl/isolated/subsystems/readout/k26c_grouped_selftrigger_datapath_plane.vhd)
  stops exporting unused trigger/descriptor/delayed-sample monitor buses across
  the grouped datapath seam,
- [stc3_frame_source.vhd](../rtl/isolated/subsystems/trigger/stc3_frame_source.vhd)
  keeps the aggregate busy/drop counter but removes the unused per-cause reject
  counters from the active grouped frame-source path.

Recent seam correction:

- [stc3_frame_source.vhd](../rtl/isolated/subsystems/trigger/stc3_frame_source.vhd)
  no longer treats `desc_taken` as the end of ring ownership,
- [afe_stc3_stream_serializer.vhd](../rtl/isolated/subsystems/trigger/afe_stc3_stream_serializer.vhd)
  now emits an explicit descriptor-release pulse on packet completion,
- [afe_grouped_selftrigger_island.vhd](../rtl/isolated/subsystems/trigger/afe_grouped_selftrigger_island.vhd)
  threads that release back to the owning frame source,
- this fixes the earlier draft bug where an in-flight descriptor could disappear
  from the ring-retention accounting before its waveform had been fully read.

Current readout-pressure contract:

- the grouped datapath now carries an explicit `grouped_readout_ready_i` vector
  from the board transport plane back to each grouped serializer,
- [afe_grouped_selftrigger_island.vhd](../rtl/isolated/subsystems/trigger/afe_grouped_selftrigger_island.vhd)
  only drains a serializer when both the serializer has a word ready and the
  matching grouped readout slot is ready,
- [grouped_hermes_readout_bridge.vhd](../rtl/isolated/subsystems/readout/grouped_hermes_readout_bridge.vhd)
  now drives that ready vector from the imported Deimos/Hermes input buffers,
- [tx_mux_ibuf.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/tx_mux_ibuf.vhd)
  has a `READY_AWARE_G` mode that starts ready, drops ready near input FIFO
  full, and accepts source words only while ready is asserted,
- the grouped path enables `READY_AWARE_G`, while legacy Deimos instantiations
  keep the old always-ready behavior by default,
- this turns the grouped stream seam into a real `valid && ready` boundary and
  prevents the serializer-held word from being duplicated when Hermes
  backpressures a source.

Current resource-reduction defaults:

- [grouped_selftrigger_fabric.vhd](../rtl/isolated/subsystems/trigger/grouped_selftrigger_fabric.vhd)
  and the board grouped self-trigger plane now select the `10`-source
  candidate by default through `CHANNELS_PER_PRODUCER_G = 4`,
- the grouped ring and grouped Hermes input-buffer paths select UltraRAM by
  default while reusable/legacy wrappers keep block RAM defaults,
- the grouped xcorr path disables the dynamic AFE compensator and dynamic signal
  inverter through generics, preserving legacy defaults elsewhere,
- the grouped xcorr path uses a fixed-delay CFD instead of the configurable CFD,
- the grouped xcorr trigger latency generic defaults to `4` clocks in the
  grouped fabric, while the reusable/legacy defaults remain `64` clocks.
- the grouped descriptor path selects
  [peak_descriptor_compact.vhd](../rtl/isolated/subsystems/trigger/peak_descriptor_compact.vhd)
  through `USE_COMPACT_DESCRIPTOR_G`; legacy wrappers keep the imported
  descriptor calculator by default.

Branch-local verification status:

- `fusesoc core-info` resolves for the new grouped cores,
- `./scripts/fusesoc/run_logic_test.sh` includes
  `dune-daq:daphne:peak-descriptor-compact-smoke:0.1.0`, which checks the
  compact descriptor trailer-valid pulse, start-time packing, peak amplitude,
  and integral sanity,
- `fusesoc run --tool ghdl --setup dune-daq:daphne:grouped-selftrigger-fabric-bridge:0.1.0`
  resolves dependencies and sets up cleanly,
- `fusesoc run --tool ghdl --setup --build dune-daq:daphne:k26c-grouped-selftrigger-datapath-plane:0.1.0`
  builds cleanly with the grouped ready, descriptor-release, and self-trigger
  resource-reduction generics,
- `fusesoc run --tool ghdl --setup dune-daq:daphne:k26c-board-grouped-outbuffer-plane:0.1.0`
  should resolve independently of Hermes collateral because it depends only on
  grouped stream types and the existing outbuffer sink,
- [grouped-selftrigger-board-srccheck.core](../cores/features/grouped-selftrigger-board-srccheck.core)
  provides the correct source-only dependency-resolution path for the grouped
  board draft when generated Hermes IP collateral is absent locally,
- `fusesoc run --tool ghdl --setup --build dune-daq:daphne:grouped-selftrigger-board-srccheck:0.1.0`
  still stops in imported Hermes collateral at the conditional constant in
  `eth_readout.vhd`, before board-level grouped elaboration can finish;
  that is a Hermes/GHDL compatibility limitation, not a grouped self-trigger
  datapath failure,
- `k26c-board-grouped-selftrigger-plane` inherits that same transport
  collateral limitation because it composes the grouped Hermes wrapper directly.

RTL dead-time bench status:

- [multichannel_deadtime_tb_lane.vhd](../../daphne_mezz_xc_sim/hdl/multichannel_deadtime_tb_lane.vhd)
  now wires `desc_released_o` from the grouped serializer back into each
  `stc3_frame_source`,
- the lane bench elaborates with GHDL against this firmware checkout,
- short `10 x 4` and `5 x 8` grouped smoke points show nonzero descriptor
  release/drain counts,
- the existing bench-side `sent_total` counter remains unreliable in this
  wrapper because packet completion is inferred from the two-lane mux `last`
  pulse rather than from the serializer release seam.

## Build Candidate

The branch default K26C shell now instantiates the grouped self-trigger plane:

- [k26c_board_shell.vhd](../rtl/isolated/tops/k26c_board_shell.vhd)
  uses [k26c_board_grouped_selftrigger_plane.vhd](../rtl/isolated/subsystems/readout/k26c_board_grouped_selftrigger_plane.vhd),
- the grouped plane defaults to `CHANNELS_PER_PRODUCER_G = 4`, so the full
  shell exposes `10` logical Hermes sources,
- grouped sample rings and grouped Hermes input buffers default to UltraRAM in
  this candidate while keeping the legacy `2048` samples/words per input,
- the grouped path defaults to the compact descriptor implementation; set
  `USE_COMPACT_DESCRIPTOR_G => false` only to compare against the imported
  descriptor calculator,
- its board-bring-up defaults keep legacy input spy capture and grouped output
  spy capture enabled; both can be explicitly disabled for a resource-only
  synthesis experiment while leaving the AXI-Lite windows responsive,
- [k26c-board-shell.core](../cores/features/k26c-board-shell.core)
  depends on the grouped board self-trigger plane,
- [boards/k26c/board.yml](../boards/k26c/board.yml)
  names artifacts as `daphne_grouped_selftrigger_*`,
- [boards/k26c/legacy-flow.yml](../boards/k26c/legacy-flow.yml)
  points the packaged Hermes XCI cell binding at the grouped Hermes hierarchy.

This makes the normal full implementation command the grouped candidate:

```sh
./scripts/fusesoc/build_platform.sh --target impl
```

The first useful Vivado result is post-synthesis utilization. If post-synthesis
already exceeds K26 resources, the next action is RTL/resource reduction rather
than place/route tuning.

The `79da1c9` implementation clears this resource gate for the `10 x 4` URAM
compact point: full bitstream, XSA, and overlay generation completed with
positive post-route timing. Initial DAPHNE-15 smoke testing also confirms that
the board loads the payload, services start, ControlEnvelopeV2 reads respond,
software-trigger command dispatch responds, and the spy-buffer read path can
return samples. The next action is readout/backpressure qualification, not
further resource surgery.

## Formal / Contract Plan

The first useful formal package for this redesign is seam-oriented, not
full-path.

Current formal gap: there is not yet a checked-in proof for the compact peak
descriptor algorithm itself. The current protection is the focused GHDL smoke
test plus the existing seam-oriented formal inventory; a future proof should
cover trailer pulse/data pulse coincidence, bounded counter behavior, and stable
trailer packing.

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
  [eth_readout.vhd](../ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/eth_readout.vhd)
  directly with generic `SOURCE_COUNT_G`,
- [grouped-hermes-readout-bridge.core](../cores/features/grouped-hermes-readout-bridge.core)
  keeps that seam reusable without wiring it into the live K26 path.
- [grouped-hermes-readout-ooc.core](../cores/tests/grouped-hermes-readout-ooc.core)
  provides three Vivado OOC targets for `N_SRC = 2, 5, 10` at the soft
  `tx_mux` seam,
- [run_grouped_hermes_ooc.sh](../scripts/fusesoc/run_grouped_hermes_ooc.sh)
  is the repo-native launcher for those measurements.

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

- step 1 is complete in this draft branch,
- the OOC measurement lane for `N_SRC = 2, 5, 10` has measured the grouped
  transport scaling point,
- the full K26C `10 x 4` URAM compact point at `79da1c9` builds, routes,
  packages, and closes timing,
- the next concrete action is board smoke testing of the artifact bundle.

Measurement scope of the current OOC lane:

- it measures grouped-source scaling where the per-source input FIFOs and mux
  arbitration actually live,
- it intentionally excludes the fixed vendor-backed Ethernet/GT collateral,
- that makes it the correct first-order resource delta for `N_SRC`, not a full
  board-level transport signoff.

Planned invocation:

```bash
./scripts/fusesoc/run_grouped_hermes_ooc.sh --sources 2
./scripts/fusesoc/run_grouped_hermes_ooc.sh --sources 5
./scripts/fusesoc/run_grouped_hermes_ooc.sh --sources 10
```

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
