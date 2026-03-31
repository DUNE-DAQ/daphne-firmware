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

and stores logs under `build/wsl-vivado/<timestamp>/`.

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

The build should still populate `xilinx/output/` with the usual implementation
artifacts, especially:

- `.bit`
- `.bin`
- `.xsa`
- implementation reports

Then, from WSL with `xsct` and `dtc` available on `PATH`, finish the overlay
packaging step outside Vivado:

```bash
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output
```

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

If that still fails on a specific host, the manual `pushd \\wsl.localhost\...`
commands in `docs/wsl-agent-summary.md` remain the reference fallback.
