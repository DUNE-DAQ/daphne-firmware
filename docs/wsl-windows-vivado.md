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
cd ~/repo/daphne-firmware
./scripts/wsl/check_windows_xilinx.sh
```

That script:

- creates WSL-local `vivado` and `xsct` wrappers that point at the Windows
  `.bat` launchers;
- exports `XILINX_VITIS` in Windows path form so the Tcl flow can find XSCT
  inside the Windows Vivado process;
- verifies that both tools are callable from WSL.

## Full WSL chain

Run:

```bash
cd ~/repo/daphne-firmware
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

The WSL wrapper also records:

- `build/wsl-vivado/<timestamp>/run.env`
- `build/wsl-vivado/<timestamp>/toolcheck.log`
- `build/wsl-vivado/<timestamp>/preflight.log`
- `build/wsl-vivado/<timestamp>/build.log`
- `build/wsl-vivado/<timestamp>/artifacts.txt`
