# Agent Handoff

## Current branch

- Branch: `marroyav/fusesoc-backports`
- Native impl checkpoint: see `docs/native-impl-architecture.md`
- Latest WSL handoff should also consult `docs/wsl-agent-summary.md`

## What is already done

- Added reusable FuseSoC cores for:
  - common package definitions
  - config/control
  - frontend control
  - self-trigger
  - timing endpoint
  - spy buffer
  - AFE and DAC interfaces
  - Hermes transport
  - modular top-level aggregation
- Preserved the current generated K26C Vivado path.
- Fixed the Vivado Tcl path for the AXI Quad SPI dtbo patch and forwarded extra
  shim environment variables used by remote builds.
- Added smoke tests for:
  - `config-control`
  - `selftrigger`
  - `frontend-control`
- Added formal scaffolds for:
  - `fe_axi`
  - `thresholds`

## What was verified locally

The following command passes on a non-Vivado machine:

```bash
./scripts/fusesoc/run_logic_test.sh
```

This verifies the GHDL-backed smoke targets for:

- `dune-daq:daphne:config-control:0.1.0`
- `dune-daq:daphne:selftrigger:0.1.0`
- `dune-daq:daphne:frontend-control:0.1.0`

## What is not verified locally

- Vivado preflight
- K26C synthesis/implementation
- `.bit` / `.xsa` / `.dtbo` production
- Petalinux packaging
- `daphne-server` deployment on target
- formal execution, because `sby` is not installed on the local workstation

## Immediate next step on a remote Vivado host

Use the runbook in `docs/remote-vivado.md` and run:

```bash
export DAPHNE_BOARD=k26c
./scripts/remote/run_remote_vivado_chain.sh
```

If the Xilinx environment is not already sourced:

```bash
export XILINX_SETTINGS_SH=/path/to/Vivado/2024.1/settings64.sh
export XILINX_VITIS_SETTINGS_SH=/path/to/Vitis/2024.1/settings64.sh
```

## WSL-specific status

For the WSL2 host that launches Windows-installed Vivado/Vitis:

- direct `cmd.exe /c ...vivado.bat -version` works;
- direct `cmd.exe /c ...xsct.bat -help` works;
- the helper wrappers under `scripts/wsl/` are not yet the trusted execution
  path on that host;
- use `docs/wsl-agent-summary.md` for the exact manual preflight/build fallback
  based on `cmd.exe /c "pushd \\wsl.localhost\... && ... && popd"`.

## Known repo-level caveats

- The repo still carries compatibility/export helpers for legacy automation and
  deployment naming, even though the default board `impl` path is now the
  native `k26c-composable-platform` Flow-API target.
- MAC/IP defaults are still anchored in imported PL-era defaults and are not
  yet migrated to a board/software-owned device-tree layer.

## Downstream deploy gap

The repo is still missing the full deployable chain:

- Petalinux recipe/meta-layer
- boot asset assembly
- automatic firmware-to-rootfs handoff
- integrated `daphne-server` install/start validation

The relevant docs are:

- `docs/server-contract.md`
- `docs/gap-analysis.md`
- `petalinux/README.md`
- `docs/wsl-windows-vivado.md`
- `docs/wsl-agent-summary.md`
