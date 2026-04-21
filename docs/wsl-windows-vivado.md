# WSL2 With Windows Vivado/Vitis

Use this when:

- you are running inside WSL2;
- Vivado 2024.1 and Vitis 2024.1 are installed on Windows;
- the repo scripts should call the Windows tools from WSL.

This is different from `docs/remote-vivado.md`, which assumes a native Linux
host with Xilinx tools installed directly on that host.

For the full clone-to-products runbook, see
[build-manual.md](/Users/marroyav/repo/daphne-firmware/docs/build-manual.md).

## Default assumptions

## Workflow directive

For the active K26 build workflow on this project:

- the build host is a Windows machine;
- `git` operations are managed from WSL against the Windows clone;
- Vivado should be executed from Windows PowerShell, not from WSL;
- the current observed behavior is that native PowerShell Vivado runs are
  about `6x` faster than the WSL-driven Vivado path.

Use the WSL wrappers in this document when they are specifically needed for
tool setup, packaging, or recovery. Do not treat them as the preferred
implementation launch path if native PowerShell is available.

Recommended repo path:

- Windows: `C:\w\d`
- WSL: `/mnt/c/w/d`

All commands below run from the repo root in WSL.

Avoid long or space-containing repo paths. The WSL-to-Windows wrapper path is
more reliable when the repo is visible through a short Windows path, and the
generated IP/DTG trees become deep quickly.

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
cd /mnt/c/w/d
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
cd /mnt/c/w/d
export DAPHNE_BOARD=k26c
export DAPHNE_ETH_MODE=create_ip
export DAPHNE_GIT_SHA="$(git rev-parse --short=7 HEAD)"
export DAPHNE_OUTPUT_DIR="./output-$DAPHNE_GIT_SHA"
./scripts/wsl/run_wsl_vivado_chain.sh
```

This performs:

1. WSL tool check
2. `./scripts/fusesoc/preflight_vivado_build.sh`
   - automatically skipped for the default native `impl` path and the native
     Flow-API synth targets
3. `./scripts/fusesoc/run_vivado_batch.sh`
4. `./scripts/package/complete_dtbo_bundle.sh`

and stores logs under `build/wsl-vivado/<timestamp>/`.

This is the intended repo-default single-command path for WSL-driven Windows
builds.

The board manifest now defaults the wrapper to the native board-owned platform
core and its default target. If you need to force it explicitly, set:

```bash
export DAPHNE_PLATFORM_CORE=dune-daq:daphne:k26c-composable-platform:0.1.0
```

before calling `run_wsl_vivado_chain.sh`. That drives the supported default
BD-backed `impl` target. The repo still exports a compatibility
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

With the recommended commit-specific output setting, the build populates:

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

## Windows PowerShell recovery helper

When the implementation artifacts already exist under `C:\w\d\xilinx\output-<gitsha>`
but the direct WSL packaging step still trips over Windows/WSL `createdts`
path handling, use the repo-owned PowerShell wrapper instead of typing the
manual two-stage fallback by hand:

```powershell
cd C:\w\d
.\scripts\windows\package_dtbo_from_existing_xsa.ps1 -GitSha 176ee43
```

This script does the qualified recovery flow:

1. locate `daphne_selftrigger_<gitsha>.xsa` and `.bin` under the selected
   output directory;
2. run Windows `xsct.bat` from that directory using the artifact basename as
   the `createdts -hw` argument;
3. generate or regenerate `pl.dtsi` when needed;
4. call the normal WSL-side
   [complete_dtbo_bundle.sh](/Users/marroyav/repo/daphne-firmware/scripts/package/complete_dtbo_bundle.sh)
   with `DAPHNE_FIRMWARE_ROOT` fixed explicitly.

Useful parameters:

```powershell
.\scripts\windows\package_dtbo_from_existing_xsa.ps1 `
  -OutputDir C:\w\d\xilinx\output-176ee43 `
  -Board k26c `
  -WslDistro Debian `
  -ForceRegenerateDtg
```

The defaults are:

- repo root: script-relative, intended for `C:\w\d`
- Vitis root: `C:\Xilinx\Vitis\2024.1`
- WSL distro: `Debian`
- board: `k26c`

This is now the preferred recovery path on Windows hosts where the direct WSL
wrapper still succeeds for build/implementation but is brittle for separate
DTBO packaging.

The WSL wrapper also records:

- `build/wsl-vivado/<timestamp>/run.env`
- `build/wsl-vivado/<timestamp>/toolcheck.log`
- `build/wsl-vivado/<timestamp>/preflight.log`
- `build/wsl-vivado/<timestamp>/build.log`
- `build/wsl-vivado/<timestamp>/artifacts.txt`

## Manual fallback

The repo-default wrapper is `./scripts/wsl/run_wsl_vivado_chain.sh`.

If a specific host still fails with the wrapper path, the manual fallback
remains:

```bash
./scripts/wsl/run_manual_vivado_pushd.sh all
```

then, if needed:

```bash
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output-$DAPHNE_GIT_SHA
```

## Resume From Synth Checkpoint

If a run was intentionally stopped after synthesis with
`DAPHNE_STOP_AFTER_SYNTH=1`, do not restart the full build wrapper. The normal
batch flow deletes and recreates the output directory.

Instead, resume from the generated synth checkpoint:

```bash
cd /mnt/c/w/d
export DAPHNE_GIT_SHA="$(git rev-parse --short=7 HEAD)"
./scripts/wsl/resume_impl_from_synth.sh
```

That script reuses:

- `xilinx/output-$DAPHNE_GIT_SHA/daphne_selftrigger_bd_synth.dcp`

and continues with:

- `opt_design`
- `place_design`
- post-place `phys_opt_design`
- `route_design`
- post-route `phys_opt_design`
- `.bit` / `.xsa` generation

Then run the Windows DTBO wrapper if needed:

```powershell
cd C:\w\d
.\scripts\windows\package_dtbo_from_existing_xsa.ps1 -GitSha <gitsha>
```

Also note that `run_wsl_vivado_chain.sh` now runs under `bash` with
`pipefail`, so failed preflight/build/package stages are no longer hidden by
their `tee` logging pipeline.
