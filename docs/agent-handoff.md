# Agent Handoff: Grouped Hermes Architecture Branch

Date: 2026-05-12

This handoff is for the active DAPHNE firmware development branch in:

- Repository: `~/repo/daphne-firmware`
- Branch: `marroyav/grouped-hermes-arch-draft`
- RTL tip when this note was written: `963e4ae` (`Reduce grouped Hermes input FIFO depth`)
- Remote status at handoff time: local branch matched `origin/marroyav/grouped-hermes-arch-draft`

No push was performed while writing this handoff. If this file is still
uncommitted, commit and push only if explicitly requested by the user.

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
- study `10` grouped producers first (`4` channels per grouped source),
- keep the production-visible transport contract stable until the resource and
  dead-time tradeoff is measured.

Do not treat this as a production-ready replacement yet. It is a buildable
architecture draft candidate that still needs resource closure and better
backpressure/dead-time validation.

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

- grouped Hermes input FIFO depth lowered to `1024` at the current tip
- optional grouped outbuffer path can be disabled through `ENABLE_OUTBUFFER_G`
- arithmetic/register-bank cleanup and xcorr DSP-reduction notes are tracked in
  `docs/xcorr-dsp-reduction.md`

## Important Current Defaults

The current grouped board path computes:

- `AFE_COUNT_G = 5`
- `CHANNELS_PER_AFE_G = 8`
- `CHANNELS_PER_PRODUCER_G = 4`
- `SOURCE_COUNT_C = 10`
- `HERMES_IN_BUF_DEPTH_G = 1024`

The grouped Hermes bridge converts grouped streams to the imported Hermes
`src_d` record shape and drives one MGT:

- `N_MGT = 1`
- `N_SRC = SOURCE_COUNT_G`

The current bridge ties grouped readout ready high because the imported Hermes
`src_d` boundary exposes `d/valid/last` but no per-source ready signal. Treat
backpressure closure as unfinished.

## Known Build History And Blockers

The branch has already cleared several launch/elaboration blockers:

- short-path build and board-env path issues were fixed,
- generated grouped Hermes support now declares the missing `to_src_d_array`
  helper,
- RTL elaboration and opt-design progressed after those fixes.

The last externally reported grouped-Hermes full build got past the old
`to_src_d_array` error and failed at placement due to BRAM overuse:

- `RAMB18` and `RAMB36/FIFO`: required `312`, device has `288`
- `RAMB36/FIFO`: required `152`, device has `144`

The current tip `963e4ae` reduces grouped Hermes input FIFO depth after that
failure. It still needs a fresh Vivado run to prove whether that reduction is
enough. Assume it may still fail resource closure until reports prove otherwise.

## Known Architectural Limitations

Do not hand-wave these away:

- `10` grouped Hermes sources spend BRAM because Hermes allocates per-source
  input buffering.
- `5` per-AFE producers are area-attractive but likely too coarse for dead time
  because channels block behind shared serializers.
- `40` per-channel producers preserve independence but replicate too much
  packet/control/FIFO machinery.
- The current grouped bridge has no real per-source Hermes ready/backpressure
  feedback.
- The grouped outbuffer is a debug/continuity aid, not the final transport
  contract.
- The branch has not produced a routed-clean K26 result yet.

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

1. compare `SOURCE_COUNT_G = 5` vs `10` if the build target makes that easy,
2. test lower `HERMES_IN_BUF_DEPTH_G` only if Hermes behavior still makes
   sense,
3. disable `ENABLE_OUTBUFFER_G` for resource-only measurement,
4. identify whether BRAM is dominated by Hermes source buffers, debug/outbuffer
   storage, record builders, or spy infrastructure,
5. only then decide whether to keep `10` grouped producers or retreat to a
   different grouping point.

The key question is not "can we reduce resources somehow?" The key question is:

- What replicated logic was removed?
- What shared contention was introduced?
- Is the cost mostly BRAM, LUT, or DSP?
- Does the dead-time model still improve relative to the fixed-record fallback?

## Suggested Next Engineering Slice

The next agent should focus on one narrow loop:

1. Verify the current `963e4ae` tip with local non-Vivado checks.
2. Launch or prepare a short-path native-Linux Vivado build if access exists.
3. If it fails on BRAM again, measure the three biggest toggles:
   - `SOURCE_COUNT_G`,
   - `HERMES_IN_BUF_DEPTH_G`,
   - `ENABLE_OUTBUFFER_G`.
4. Update `docs/grouped-hermes-transport-plan.md` with the measured result.
5. Only after that, decide whether to add real backpressure at the grouped
   source seam.

Do not spend a week refining RTL around a source count that is already
resource-impossible.

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
