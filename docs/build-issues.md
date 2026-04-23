# Build Issues

This note tracks the current known build issues, the fixes already landed on
`marroyav/ring-builder-2k`, and the exact commands to use for the next build.

## Current Recommended Build Path

Use native Linux Vivado/Vitis inside WSL2 and keep the repo plus build
artifacts on short WSL paths:

- repo: `/w/d`
- logs: `/w/l/<run-id>`
- work: `/w/f`
- output: `/w/o`

Do not use `/mnt/c/w/s` for the performance-sensitive native Linux run.

## Most Recent Completed 2k Run

As of 2026-04-23, the most recent successfully built
`marroyav/ring-builder-2k` tip is `27a4ca9`
(`Document current build issues`).

Observed outputs from that run:

- `daphne_selftrigger_27a4ca9.bit`
- `daphne_selftrigger_27a4ca9.bin`
- `daphne_selftrigger_27a4ca9.xsa`
- `daphne_selftrigger_27a4ca9.dtbo`
- `daphne_selftrigger_ol_27a4ca9.zip`
- `SHA256SUMS`

Timing:

- post-route timing passed with `WNS=0.103 ns` and `TNS=0.000 ns`

Packaging note:

- the Vivado implementation produced `.bit`, `.bin`, and `.xsa`
- DTBO packaging initially failed because `complete_dtbo_bundle.sh` searched a
  not-yet-existing DTG output directory under `set -e`
- the helper was corrected to check that expected directory before searching,
  then the DTBO bundle completed successfully from the existing implementation
  outputs

## Landed Fixes

### `d79bb40` `Fix Linux DT overlay packaging flow`

Problem:

- the Linux post-build DT overlay generation failed in the Vivado Tcl flow
  even though `.bit`, `.bin`, and `.xsa` were produced.

Fix:

- `xilinx/daphne_vivado_flow.tcl` now reuses
  `scripts/package/complete_dtbo_bundle.sh` instead of carrying a separate
  fragile inline Linux packaging path.

Result:

- the existing `/w/o` artifacts were validated and the following files were
  generated successfully:
  - `daphne_selftrigger_2c51d69.dtbo`
  - `daphne_selftrigger_ol_2c51d69.zip`
  - `SHA256SUMS`

### `5a988ef` `Constrain frontend CDC synchronizer pins`

Problem:

- the last native Linux build failed post-route timing with only `5` failing
  endpoints, all on the same async frontend control crossing:
  `clk_pl_0 -> clk125_1`, specifically the `idelay_load` handoff into the
  first-stage synchronizer flop in `frontend_common`.

Fix:

- `xilinx/frontend_control_cdc.tcl` now follows the same style already used by
  `xilinx/timing_endpoint_cdc.tcl`:
  - cut explicit first-stage synchronizer `D` pins with `set_false_path -to`
  - keep broader `-through` exceptions only for the remaining async control
    nets

Validation:

- the constraint contract script passes:
  - `./scripts/fusesoc/check_afe_timing_constraint_contract.sh`
- the implemented checkpoint at `/w/o/daphne_selftrigger_bd_post_impl.dcp`
  resolves the new frontend synchronizer destinations correctly:
  - `idelay_load_clk125_meta_reg[0..4]/D`
  - `idelayctrl_reset_500_meta_reg/D`
  - `trig_meta_reg/D`
- the old `clk_pl_0 -> clk125_1` failing `idelay_load` paths now report:
  - `Timing Exception: False Path`
  - `Slack: inf`

Important:

- a full rebuild has not yet been rerun after `5a988ef`
- the checkpoint validation says the old negative-slack CDC paths are now cut
  as intended

## Local Xilinx Documentation Used

These installed Vivado 2024.1 docs on this machine were used to choose the CDC
constraint style:

- `/mnt/c/Xilinx/Vivado/2024.1/doc/tcw/clock_domain_crossings.html`
- `/mnt/c/Xilinx/Vivado/2024.1/doc/tcw/top.html`
- `/mnt/c/Xilinx/Vivado/2024.1/doc/eng/man/report_cdc`
- `/mnt/c/Xilinx/Vivado/2024.1/doc/eng/man/set_clock_groups`

Relevant guidance from the Timing Constraints Wizard docs:

- use `ASYNC_REG` on synchronizer flops
- use broad clock-group or clock-to-clock false-path constraints only when all
  relevant crossings between the asynchronous clock pair are safe to ignore
- when only selected synchronized CDCs still need to be cut, use
  point-to-point false-path exceptions on those synchronized CDC paths

See also:

- `docs/frontend-cdc-followup.md`

## What To Do For The Next Build

### 1. Activate the larger WSL memory setting

`C:\\Users\\arroyave\\.wslconfig` has already been written with:

```ini
[wsl2]
memory=28GB
swap=8GB
processors=32
```

This does not take effect until:

```powershell
wsl --shutdown
```

### 2. Start a fresh WSL session

```powershell
wsl -d Debian -- bash -li
```

### 3. Verify native Linux tools

```bash
use_xilinx_2024_1
which vivado
which xsct
vivado -version | head -n 1
```

Expected:

- `vivado` from `/opt/Xilinx/Vivado/2024.1/bin/vivado`
- `xsct` from `/opt/Xilinx/Vitis/2024.1/bin/xsct`

### 4. Run the next full build

Use a new run id, keep the paths short:

```bash
cd /w/d
use_xilinx_2024_1

export DAPHNE_REMOTE_LOG_DIR=/w/l
export DAPHNE_REMOTE_RUN_ID=4
export DAPHNE_FUSESOC_WORK_ROOT=/w/f
export DAPHNE_OUTPUT_DIR=/w/o

./scripts/wsl/run_native_vivado_chain.sh \
  --threads 24 \
  --opt-directive ExploreWithRemap \
  --post-place-physopt AddRetime
```

Watch the log:

```bash
tail -f /w/l/4/build.log
```

### 5. What to check after the run

- `post_route_timing_summary.rpt`
- `post_route_methodology.rpt`
- whether the old `clk_pl_0 -> clk125_1` `idelay_load` path is absent from the
  failing endpoint list
- whether overlay packaging completes automatically at the end

## Expected Runtime

The last native Linux short-path run completed in about `1h51m`, versus about
`2h15m` for the older `/mnt/c/w/s` flow.

The next run should be in the same general range. The CDC constraint change
itself should not materially change build runtime.
