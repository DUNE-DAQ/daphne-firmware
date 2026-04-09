# Remote Vivado Runbook

Use this when the repository is developed locally but the K26C Vivado build is
executed on a remote Linux host with Xilinx tools installed.

## One-time remote setup

Clone or update the repo on the remote host and switch to the migration branch:

```bash
cd ~/repo/daphne-firmware
git fetch
git checkout marroyav/fusesoc-backports
git pull --ff-only
```

If the branch does not exist locally yet:

```bash
git fetch origin marroyav/fusesoc-backports
git checkout -b marroyav/fusesoc-backports origin/marroyav/fusesoc-backports
```

## Run the K26C chain

If the remote host does not already source Vivado/Vitis globally, pass the
settings scripts explicitly:

```bash
export XILINX_SETTINGS_SH=/path/to/Vivado/2024.1/settings64.sh
export XILINX_VITIS_SETTINGS_SH=/path/to/Vitis/2024.1/settings64.sh
```

Then run:

```bash
cd ~/repo/daphne-firmware
export DAPHNE_BOARD=k26c
./scripts/remote/run_remote_vivado_chain.sh
```

This runs:

1. `./scripts/fusesoc/preflight_vivado_build.sh`
   - automatically skipped only when the selected platform/target does not
     require packaged-IP preflight
2. `./scripts/fusesoc/run_vivado_batch.sh`

and stores logs under `build/remote-vivado/<timestamp>/`.

The board manifest now defaults the wrapper to the native board-owned platform
core and its default target. If you need to force it explicitly, set:

```bash
export DAPHNE_PLATFORM_CORE=dune-daq:daphne:k26c-composable-platform:0.1.0
```

before calling `run_remote_vivado_chain.sh`. That drives the supported default
BD/PS-backed `impl` lane unless `DAPHNE_PLATFORM_TARGET` overrides it. After
the build, the repo exports a compatibility
`daphne_selftrigger_<gitsha>.bit/.bin/.xsa` bundle back into
`xilinx/output-<gitsha>/`, so downstream DTBO packaging can keep using the same
artifact contract.

If you want to audit the staged native Flow-API graph before invoking Vivado,
run:

```bash
./scripts/fusesoc/check_native_impl_graph.sh
```

That audit checks the explicit native board-shell experiment lane
(`impl_board_shell_flow`), not the supported default BD-backed `impl` lane.

If you want the remote wrapper to attempt DTBO packaging too, also set:

```bash
export DAPHNE_REMOTE_PACKAGE_DTBO=1
```

## Important environment knobs

- `DAPHNE_BOARD=k26c` keeps the currently qualified board path.
- `DAPHNE_ETH_MODE=create_ip` is the only qualified implementation mode.
- `DAPHNE_OUTPUT_DIR` overrides the Vivado output directory if needed.
- `DAPHNE_GIT_SHA` can pin the reported build version.
- `DAPHNE_MAX_THREADS` can be set for the remote server capacity.

## Expected outputs

The supported default `impl` lane should populate `xilinx/output-<gitsha>/` with
artifacts such as:

- `.bit`
- `.bin`
- `.xsa`
- `.dtbo`
- timing/utilization/power reports

If the Vivado run stops after `.xsa` / `.bin`, complete the overlay packaging
step with:

```bash
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output-$DAPHNE_GIT_SHA
```

The wrapper script also records:

- `build/remote-vivado/<timestamp>/run.env`
- `build/remote-vivado/<timestamp>/preflight.log`
- `build/remote-vivado/<timestamp>/build.log`
- `build/remote-vivado/<timestamp>/artifacts.txt`

## What to hand back

The next agent or operator should return:

- the exact branch and commit built;
- whether preflight ran or was skipped;
- whether implementation completed;
- the contents of `artifacts.txt`;
- any Vivado timing/DRC failures that block deployability.
