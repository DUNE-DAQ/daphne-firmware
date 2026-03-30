# WSL Agent Summary

## Scope

This summary is for the next agent running inside WSL2 on the host where:

- the firmware repo lives at `~/work/daphne-firmware`;
- Vivado 2024.1 is installed on Windows at `C:\Xilinx\Vivado\2024.1`;
- Vitis 2024.1 is installed on Windows at `C:\Xilinx\Vitis\2024.1`.

## What is already verified

- Local FuseSoC/GHDL smoke tests pass on branch
  `codex/fusesoc-modular-migration`.
- Windows tools are reachable from WSL with direct commands:

```bash
cmd.exe /c C:\\Xilinx\\Vivado\\2024.1\\bin\\vivado.bat -version
cmd.exe /c C:\\Xilinx\\Vitis\\2024.1\\bin\\xsct.bat -help
```

- The correct Windows-form Vitis path is:

```bash
export XILINX_VITIS='C:\Xilinx\Vitis\2024.1'
```

## What is not stable yet

- The repo WSL helper scripts under `scripts/wsl/` are not yet reliable enough
  to be the primary execution path.
- Symptoms observed:
  - stale `XILINX_VITIS` prints from old shell state;
  - wrapper hangs after the `PATH wrapper dir` line;
  - direct `.bat` execution from WSL shell fails unless run through
    `cmd.exe /c`;
  - Windows `cmd.exe` starts from a UNC WSL working directory and falls back to
    `C:\Windows`, which breaks relative Tcl `source` paths.

## Current recommended execution path

Do not start with `./scripts/wsl/check_windows_xilinx.sh`.

Use manual Windows-tool invocation from WSL with `cmd.exe /c` and `pushd` so
the WSL UNC path is mapped to a temporary Windows drive.

### Manual preflight

From `~/work/daphne-firmware/xilinx`, prepare:

```tcl
set script_dir "\\\\wsl.localhost\\Debian\\home\\neutrino\\work\\daphne-firmware\\xilinx"
create_project -in_memory -part "xck26-sfvc784-2LV-c"
set ::env(DAPHNE_FPGA_PART) "xck26-sfvc784-2LV-c"
set ::env(DAPHNE_BOARD_PART) "xilinx.com:k26c:part0:1.4"
set ::env(DAPHNE_PFM_NAME) "xilinx:k26c:name:0.0"
set ::env(DAPHNE_BOARD) "k26c"
set ::env(DAPHNE_ETH_MODE) "create_ip"
source -notrace [file join $script_dir "daphne3_ip_gen.tcl"]
exit
```

Run:

```bash
cmd.exe /c "pushd \\wsl.localhost\Debian\home\neutrino\work\daphne-firmware\xilinx && C:\Xilinx\Vivado\2024.1\bin\vivado.bat -mode batch -source .manual-preflight.tcl && popd"
```

### Manual build

From `~/work/daphne-firmware/xilinx`, prepare:

```tcl
set script_dir "\\\\wsl.localhost\\Debian\\home\\neutrino\\work\\daphne-firmware\\xilinx"
set ::env(DAPHNE_FPGA_PART) "xck26-sfvc784-2LV-c"
set ::env(DAPHNE_BOARD_PART) "xilinx.com:k26c:part0:1.4"
set ::env(DAPHNE_PFM_NAME) "xilinx:k26c:name:0.0"
set ::env(DAPHNE_BOARD) "k26c"
set ::env(DAPHNE_ETH_MODE) "create_ip"
set ::env(DAPHNE_MAX_THREADS) "12"
set ::env(DAPHNE_SKIP_POST_SYNTH_REPORTS) "1"
set ::env(DAPHNE_SKIP_POST_SYNTH_CHECKPOINT) "1"
set ::env(XILINX_VITIS) "C:\\Xilinx\\Vitis\\2024.1"
source -notrace [file join $script_dir "vivado_batch.tcl"]
```

Run:

```bash
cmd.exe /c "pushd \\wsl.localhost\Debian\home\neutrino\work\daphne-firmware\xilinx && C:\Xilinx\Vivado\2024.1\bin\vivado.bat -mode batch -source .manual-build.tcl && popd"
```

## Latest known build outcome

On the WSL/Windows path, the design has already been observed to reach:

- successful `write_bitstream`
- successful `write_hw_platform`
- generated:
  - `.bit`
  - `.bin`
  - `.xsa`
  - implementation reports

The remaining failure was after that, when the Windows branch of
`vivado_batch.tcl` required `XILINX_VITIS` and the shell state still held a bad
value.

## Immediate next objective

1. Re-run manual preflight with `pushd`.
2. Confirm these files exist after preflight:
   - `ip_repo/daphne3_ip/component.xml`
   - `ip_repo/daphne3_ip/src/dune.daq_user_hermes_daphne_1.0/src/xxv_ethernet_0/xxv_ethernet_0.xci`
3. Re-run manual build with `pushd`.
4. Capture resulting artifacts under `xilinx/output/`.
5. If the build succeeds again, decide whether to:
   - patch the repo wrappers to use the same `cmd.exe /c pushd ...` strategy; or
   - keep the manual Tcl path for this host and document dtbo completion
     separately.
