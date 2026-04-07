# WSL2 With Windows Vivado/Vitis

Use this when:

- you are running inside WSL2;
- Vivado 2024.1 and Vitis 2024.1 are installed on Windows;
- the repo scripts should call the Windows tools from WSL.

This is different from `docs/remote-vivado.md`, which assumes a native Linux
host with Xilinx tools installed directly on that host.

## Default assumptions

The helper scripts assume:

- Vivado lives at `/mnt/c/Xilinx/Vivado/2024.1`
- Vitis lives at `/mnt/c/Xilinx/Vitis/2024.1`

Override these if needed:

```bash
export DAPHNE_WINDOWS_XILINX_ROOT=/mnt/c/Xilinx
export DAPHNE_VIVADO_VERSION=2024.1
export DAPHNE_VITIS_VERSION=2024.1
```

## Tool sanity check

Run:

```bash
cd ~/work/daphne-firmware
./scripts/wsl/check_windows_xilinx.sh
```

That script:

- creates WSL-local `vivado` and `xsct` wrappers that point at the Windows
  `.bat` launchers;
- launches those tools through `cmd.exe /c call ...` while converting any Tcl
  or artifact paths to absolute Windows or UNC paths first;
- exports `XILINX_VITIS` in Windows path form so the Tcl flow can find XSCT
  inside the Windows Vivado process;
- verifies that Vivado is callable from WSL and reports whether XSCT is also
  available.

## Full WSL chain

Run:

```bash
cd ~/work/daphne-firmware
export DAPHNE_BOARD=k26c
export DAPHNE_ETH_MODE=create_ip
./scripts/wsl/run_wsl_vivado_chain.sh
```

This performs:

1. WSL tool check
2. `./scripts/fusesoc/preflight_vivado_build.sh`
3. `./scripts/fusesoc/run_vivado_batch.sh`
4. `./scripts/package/complete_dtbo_bundle.sh`

and stores logs under `build/wsl-vivado/<timestamp>/`.

This is the intended repo-default single-command path for WSL-driven Windows
builds.

To exercise the composable platform through the same wrapper, set:

```bash
export DAPHNE_PLATFORM_CORE=dune-daq:daphne:k26c-composable-platform:0.1.0
```

before calling `run_wsl_vivado_chain.sh`. That now drives the native packaged
board-shell `impl` target by default. If you explicitly need the older
BD-wrapper Flow API path, also set:

```bash
export DAPHNE_PLATFORM_TARGET=impl_legacy_flow
```

In legacy-flow mode, the wrapper skips only the standalone legacy preflight.
The Flow API target performs the BD/IP preflight inside the Vivado project,
then the repo exports a legacy-style
`daphne_selftrigger_<gitsha>.bit/.bin/.xsa` bundle back into
`xilinx/output-<gitsha>/` before running the usual DTBO packaging step.

## Output directory rule

When Windows Vivado is launched from WSL, keep `DAPHNE_OUTPUT_DIR` unset or set
it to a path that is relative to `xilinx/`.

Good:

```bash
unset DAPHNE_OUTPUT_DIR
```

or:

```bash
export DAPHNE_GIT_SHA="$(git rev-parse --short=7 HEAD)"
export DAPHNE_OUTPUT_DIR="./output-$DAPHNE_GIT_SHA"
```

Avoid:

```bash
export DAPHNE_OUTPUT_DIR="$PWD/xilinx/output-$DAPHNE_GIT_SHA"
```

That last form is a Linux absolute path. The Windows-side Vivado Tcl does not
translate it back into the WSL repo path, so the build may finish while the
artifacts do not appear under the repo directory you expected.

## Important notes

- `create_ip` is the currently qualified Ethernet mode for the WSL/Windows
  Vivado path.
- `xsct` is optional for the core build. It is only needed for the
  Vitis/device-tree helper path.
- The Tcl flow detects `Windows NT` inside Vivado and does not attempt the full
  Linux-side dtbo compilation flow there. That behavior is expected.
- The wrapper sets `XILINX_VITIS` to a Windows-style path such as
  `C:\Xilinx\Vitis\2024.1`, because the Windows Vivado process consumes that
  variable.

## Expected outputs

With the default output location, the build populates:

- `xilinx/output/`

If you set:

```bash
export DAPHNE_OUTPUT_DIR="./output-$DAPHNE_GIT_SHA"
```

then the build populates:

- `xilinx/output-<gitsha>/`

In either case, expect the usual implementation artifacts, especially:

- `.bit`
- `.bin`
- `.xsa`
- implementation reports

For a commit-specific run, the main files should be:

- `xilinx/output-<gitsha>/daphne_selftrigger_<gitsha>.bit`
- `xilinx/output-<gitsha>/daphne_selftrigger_<gitsha>.bin`
- `xilinx/output-<gitsha>/daphne_selftrigger_<gitsha>.xsa`

If you want to run the packaging step separately, use:

```bash
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output
```

or, for a commit-specific run:

```bash
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output-$DAPHNE_GIT_SHA
```

When this script runs under WSL and `xsct` is not already on `PATH`, it
automatically sources [setup_windows_xilinx.sh](/Users/marroyav/repo/daphne-firmware/scripts/wsl/setup_windows_xilinx.sh)
to activate the Windows Vitis wrapper for the current process.

The WSL wrapper also records:

- `build/wsl-vivado/<timestamp>/run.env`
- `build/wsl-vivado/<timestamp>/toolcheck.log`
- `build/wsl-vivado/<timestamp>/preflight.log`
- `build/wsl-vivado/<timestamp>/build.log`
- `build/wsl-vivado/<timestamp>/artifacts.txt`

## Current status on the WSL host

The repo wrappers no longer rely on the Windows current working directory being
mapped into the WSL repo. Instead they call the Windows `.bat` launchers
directly and pass absolute converted Tcl and artifact paths. This is a better
fit for the observed working path, where Windows Vivado can already source
`\\wsl.localhost\...` Tcl files directly.

If you still see stale local state, re-run:

```bash
./scripts/wsl/check_windows_xilinx.sh
```

If that still fails on a specific host, the manual fallback remains:

```bash
./scripts/wsl/run_manual_vivado_pushd.sh all
```

then, if needed:

```bash
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output-$DAPHNE_GIT_SHA
```

Also note that `run_wsl_vivado_chain.sh` now runs under `bash` with
`pipefail`, so failed preflight/build/package stages are no longer hidden by
their `tee` logging pipeline.
