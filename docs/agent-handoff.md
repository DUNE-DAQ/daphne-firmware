# Agent Handoff: Grouped Hermes Architecture Branch

Date: 2026-05-15

This handoff is for the active DAPHNE firmware development branch in:

- Repository: `~/repo/daphne-firmware`
- Branch: `marroyav/grouped-hermes-resource-build-candidate`
- Current routed-clean candidate tip: `79da1c9` (`Fix frontend control CDC timing cuts`)
- Remote status at handoff time: local branch matched `origin/marroyav/grouped-hermes-resource-build-candidate`

## Primary Objective

This branch drafts a new AFE-to-Hermes/10Gb architecture that reduces replicated
per-channel packetization while avoiding the dead-time penalty of grouping too
early.

The working design direction is:

- preserve fixed `512`-sample records first,
- keep waveform/sample ownership local as long as possible,
- queue compact descriptors rather than large waveform payloads,
- assemble packets late,
- expose real grouped sources to Hermes,
- use `10` grouped producers by default in this resource candidate (`4`
  channels per grouped source),
- keep `5` grouped producers (`8` channels per grouped source, one producer
  per AFE) as the lower-resource comparison/retreat point,
- keep the production-visible transport contract stable until the resource and
  dead-time tradeoff is measured.

Do not treat this as a production-ready replacement yet. It is now a
routed-clean, timing-clean architecture candidate that still needs board smoke
testing and backpressure/dead-time validation.

## Baselines To Preserve

Use these as stable comparison points:

- routed-clean firmware baseline: `a389fcd`
- current `main` tip carrying packaging fixes: `eb5f971`
- successful ring2k reference reported earlier: `27a4ca9` routed, but BRAM was
  tight (`139 / 144` BRAM tiles)

Do not casually disturb the qualified `main` build/deploy path while working on
this branch.

## What This Branch Has Implemented

Grouped-source transport scaffolding:

- `rtl/isolated/subsystems/readout/grouped_transport_pkg.vhd`
- `rtl/isolated/subsystems/readout/grouped_hermes_readout_bridge.vhd`
- `rtl/isolated/subsystems/readout/grouped_hermes_readout_ooc_shell.vhd`
- `rtl/isolated/subsystems/readout/k26c_grouped_hermes_transport_plane.vhd`
- `rtl/isolated/subsystems/readout/k26c_board_grouped_transport_plane.vhd`
- `rtl/isolated/subsystems/readout/k26c_board_grouped_outbuffer_plane.vhd`

Grouped self-trigger and board-plane draft:

- `rtl/isolated/subsystems/trigger/grouped_selftrigger_fabric.vhd`
- `rtl/isolated/subsystems/trigger/afe_grouped_selftrigger_island.vhd`
- `rtl/isolated/subsystems/control/grouped_selftrigger_fabric_bridge.vhd`
- `rtl/isolated/subsystems/readout/k26c_grouped_selftrigger_datapath_plane.vhd`
- `rtl/isolated/subsystems/readout/k26c_board_grouped_selftrigger_plane.vhd`
- `rtl/isolated/tops/k26c_board_shell.vhd`

FuseSoC/build integration:

- grouped board/selftrigger/transport cores under `cores/features/`
- branch-local K26C shell routing through the grouped selftrigger plane
- source-only grouped board check lane
- OOC grouped Hermes shell packaging fixes
- remote Vivado path fixes for short native-Linux worktrees

Resource-reduction work already staged:

- grouped Hermes input FIFO depth is kept at the legacy `2048` words per source
  for the launch candidate
- the grouped Hermes input buffers and grouped sample rings can now select XPM
  memory primitives through generics; the current grouped build candidate uses
  UltraRAM for both while the reusable primitive defaults remain block RAM
- grouped Deimos/Hermes input buffers now expose source-side ready in
  `READY_AWARE_G` mode, and the grouped bridge threads that ready back to the
  serializers
- grouped self-trigger defaults now disable the dynamic AFE compensator and
  dynamic signal inverter, use a fixed CFD, and reduce synthetic trigger latency
  from `64` clocks to `4` clocks
- grouped self-trigger defaults now select the compact repo-owned peak
  descriptor implementation through `USE_COMPACT_DESCRIPTOR_G`, while legacy
  self-trigger wrappers keep the imported descriptor by default
- optional grouped outbuffer path can be disabled through `ENABLE_OUTBUFFER_G`
- arithmetic/register-bank cleanup and xcorr DSP-reduction notes are tracked in
  `docs/xcorr-dsp-reduction.md`

## Important Current Defaults

The current grouped board path computes:

- `AFE_COUNT_G = 5`
- `CHANNELS_PER_AFE_G = 8`
- `CHANNELS_PER_PRODUCER_G = 4`
- `SOURCE_COUNT_C = 10`
- `HERMES_IN_BUF_DEPTH_G = 2048`
- `HERMES_IN_BUF_MEMORY_TYPE_G = "ultra"`
- `RING_MEMORY_PRIMITIVE_G = "ultra"`
- `USE_COMPACT_DESCRIPTOR_G = true`

To reproduce the previous routed `5`-source study point, override
`CHANNELS_PER_PRODUCER_G` back to `8`.

The grouped Hermes bridge converts grouped streams to the imported Hermes
`src_d` record shape and drives one MGT:

- `N_MGT = 1`
- `N_SRC = SOURCE_COUNT_G`

The current bridge no longer ties grouped readout ready high. It enables the new
Deimos `READY_AWARE_G` mode and drives grouped readout ready from each Hermes
source buffer, so the grouped serializer only advances on a real `valid &&
ready` transfer.

## Known Build History And Current Build Point

The branch has already cleared several launch/elaboration blockers:

- short-path build and board-env path issues were fixed,
- generated grouped Hermes support now declares the missing `to_src_d_array`
  helper,
- RTL elaboration and opt-design progressed after those fixes.

Important measured points:

- the pre-URAM resource candidate at `77682da` routed cleanly for `5` sources
  with legacy `2048`-word Hermes buffers,
- a `10`-source build at `7647e8b` synthesized and placed but failed
  routing/bitgen with illegal routing,
- the compact `10`-source URAM candidate at `a34bd80` routed and generated a
  bitstream, but failed setup timing on a frontend control CDC path,
- `79da1c9` fixed that CDC timing exception and produced the first complete
  `10 x 4` grouped-source K26C implementation with clean post-route timing.

Current routed-clean artifact point:

- branch: `marroyav/grouped-hermes-resource-build-candidate`
- commit: `79da1c9`
- build host/run: `/w/q`, run id `20260514-205854`
- output directory: `/w/q/xilinx/output-79da1c9-src10-uram-compact`
- synced evidence bundle:
  `/nfs/home/marroyav/fnal-sync/grouped-hermes-resource-build-79da1c9-20260515`

The full Vivado chain completed synthesis, placement, routing, bitstream, XSA,
and device-tree overlay packaging. Post-route timing is clean:

- WNS `+0.073 ns`
- TNS `0.000 ns`
- WHS `+0.010 ns`
- THS `0.000 ns`

Post-route resources:

- CLB LUTs: `84,408 / 117,120 = 72.07%`
- CLB registers: `141,374 / 234,240 = 60.35%`
- BRAM tiles: `48 / 144 = 33.33%`
- URAM: `40 / 64 = 62.50%`
- DSP: `0 / 1,248 = 0.00%`

Residual warnings:

- `timing_endpoint_cdc.tcl:88` has an empty false-path startpoint warning,
- XXV Ethernet generated IP reports the expected evaluation-license critical
  warning,
- post-route methodology reports TIMING-6/7/17, plus TIMING-9/18/26/30.

## Known Architectural Limitations

Do not hand-wave these away:

- `10` grouped Hermes sources spend BRAM because Hermes allocates per-source
  input buffering.
- `5` per-AFE producers are area-attractive and are now the default candidate,
  but dead-time/queue-reject measurements must prove the contention is
  acceptable.
- `40` per-channel producers preserve independence but replicate too much
  packet/control/FIFO machinery.
- The current grouped bridge has real per-source Hermes ready/backpressure
  feedback, but it still needs hardware-rate validation under link and UDP
  backpressure.
- The grouped outbuffer is a debug/continuity aid, not the final transport
  contract.
- The branch has produced a routed-clean K26 result at `79da1c9`, but it has
  not yet completed board smoke testing.

## Where To Read Before Editing

Start with:

- `AGENTS.md`
- `PROJECT.md`
- `docs/grouped-hermes-transport-plan.md`
- `docs/build-manual.md`
- `docs/remote-vivado.md`
- `docs/xcorr-dsp-reduction.md`

Use companion references before making architectural claims:

- dead-time/RTL simulation: `~/repo/daphne_mezz_xc_sim`
- AMD/Xilinx docs: `~/Library/amd-docs` and `~/repo/third_party_docs/amd`
- hardware references: `~/repo/DAPHNE_Mezz_Schematic_Prints.pdf` and
  `~/repo/Daphne_MEZZ`
- DAQ references: `~/repo/daqdataformats`, `~/repo/daphnemodules`,
  `~/repo/daphne_interface`

## Recommended Verification Ladder

Before another full implementation build:

```bash
git diff --check
./scripts/fusesoc/check_board_shell_planes.sh
./scripts/fusesoc/run_logic_test.sh
./scripts/formal/run_formal.sh --list
```

Then use OOC/source checks where possible before consuming full Vivado time.

For a full native-Linux build, use a short path, not `/mnt/...`:

```bash
source /opt/Xilinx/Vivado/2024.1/settings64.sh
export DAPHNE_BOARD=k26c
export DAPHNE_ETH_MODE=create_ip
export DAPHNE_GIT_SHA="$(git rev-parse --short=7 HEAD)"
./scripts/remote/run_remote_vivado_chain.sh
```

If Vivado/Vitis settings are not already sourced:

```bash
export XILINX_SETTINGS_SH=/path/to/Vivado/2024.1/settings64.sh
export XILINX_VITIS_SETTINGS_SH=/path/to/Vitis/2024.1/settings64.sh
```

## If The Next Build Still Does Not Fit

Inspect first:

- `post_synth_util.rpt`
- `post_synth_timing_summary.rpt`
- `build.log`

Do not immediately rewrite the transport plane again. First isolate the
resource driver:

1. compare the default `SOURCE_COUNT_G = 10` against the `5`-source override if
   the build target makes that easy,
2. test lower `HERMES_IN_BUF_DEPTH_G` only if Hermes behavior still makes
   sense,
3. disable `ENABLE_OUTBUFFER_G` for resource-only measurement,
4. identify whether BRAM/LUT is dominated by Hermes source buffers,
   debug/outbuffer storage, record builders, descriptor logic, or spy
   infrastructure,
5. only then decide whether to keep `10` grouped producers or retreat to a
   different grouping point.

The key question is not "can we reduce resources somehow?" The key question is:

- What replicated logic was removed?
- What shared contention was introduced?
- Is the cost mostly BRAM, LUT, or DSP?
- Does the dead-time model still improve relative to the fixed-record fallback?

## Suggested Next Engineering Slice

The next agent should focus on one narrow loop:

1. Board-smoke the `79da1c9` artifact bundle.
2. Confirm overlay load, AXI register access, timing/frontend status, and
   Hermes/10Gb link bring-up.
3. Run a short self-trigger/readout capture.
4. Exercise the new Hermes ready path under UDP/link backpressure and confirm
   there is no word duplication or packet truncation at the grouped source seam.
5. Classify the residual methodology warnings and clean the
   `timing_endpoint_cdc.tcl:88` empty-startpoint warning.

Do not spend a week refining RTL around a source count that is already
resource-impossible. That stop condition has been cleared for the current
`10 x 4` URAM compact candidate; the next risk is board behavior.

## Do Not Do

- Do not push scratch work unless explicitly asked.
- Do not claim the grouped branch is production-ready.
- Do not call Hermes `N_SRC` widening "just a mux change".
- Do not replace the stable `main` build path while this branch is still a
  resource study.
- Do not remove spy/debug infrastructure from production assumptions without a
  clear fallback; it is important for board behavior validation.
- Do not promise sub-2% dead time without an accepted DAQ/PDS operating model
  and updated `daphne_mezz_xc_sim` evidence.
