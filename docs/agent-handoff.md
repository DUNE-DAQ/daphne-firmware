# Agent Handoff

## Current branch

- Branch: `marroyav/merge-candidate`
- Latest WSL handoff should also consult `docs/wsl-agent-summary.md`
- Synthesis-specific timing review: see `docs/synthesis-timing-review.md`

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
- Merged the reviewed `formal-infra` work into the current integration branch.
- Achieved one routed-clean remote baseline on the merge-branch ancestor
  `a389fcd`, with generated `.bit`, `.bin`, `.xsa`, and `.dtbo`.
- Added merge-branch follow-up changes that still need one fresh full remote
  run on branch head:
  - `46263cb` clock/methodology cleanup
  - `a41909c` selftrigger slow-control CDC synchronization
  - `e8414ed` extra QoR and CDC reporting
  - `1b96907` QoR experiment note in the handoff docs

## What was verified locally

The following commands pass on a non-Vivado machine:

```bash
./scripts/fusesoc/run_logic_test.sh
./scripts/fusesoc/check_afe_timing_constraint_contract.sh
./scripts/fusesoc/build_platform.sh --target impl --dry-run
```

This verifies:

- `dune-daq:daphne:config-control:0.1.0`
- `dune-daq:daphne:selftrigger:0.1.0`
- `dune-daq:daphne:frontend-control:0.1.0`
- the current unmanaged Tcl timing-constraint contract
- the current `k26c-composable-platform` build entrypoint resolution

## What is verified remotely

- The last fully qualified remote implementation baseline is ancestor
  `a389fcd`.
- That run reached routed timing closure and produced:
  - `.bit`
  - `.bin`
  - `.xsa`
  - `.dtbo`
- The current branch head is ahead of that baseline and has not yet been
  rerun end-to-end on a Vivado host.

## What is not verified locally

- Vivado preflight
- K26C synthesis/implementation
- `.bit` / `.xsa` / `.dtbo` production
- Petalinux packaging
- `daphne-server` deployment on target
- full system-level behavior on hardware

## Immediate next step on a remote Vivado host

Use the runbook in `docs/remote-vivado.md`, but build the current branch head:

```bash
cd ~/repo/daphne-firmware
git fetch origin
git checkout marroyav/merge-candidate
git reset --hard 1b96907
export DAPHNE_BOARD=k26c
export DAPHNE_GIT_SHA=1b96907
./scripts/remote/run_remote_vivado_chain.sh
```

If the Xilinx environment is not already sourced:

```bash
export XILINX_SETTINGS_SH=/path/to/Vivado/2024.1/settings64.sh
export XILINX_VITIS_SETTINGS_SH=/path/to/Vitis/2024.1/settings64.sh
```

## Optional Vivado QoR Experiments

If the current baseline meets flow correctness but still needs QoR work, keep
these as explicit one-at-a-time experiments rather than new defaults:

- `DAPHNE_OPT_DIRECTIVE=ExploreWithRemap`
  - makes `opt_design` try more aggressive logic remapping before placement;
  - useful when the issue looks like combinational reshaping or routability;
  - can increase area and packing pressure, so compare utilization and control
    sets against the baseline.
- `DAPHNE_POST_PLACE_PHYSOPT_DIRECTIVE=AddRetime`
  - makes `phys_opt_design` try register retiming after placement;
  - useful when the issue looks like setup timing on deep datapaths;
  - can complicate CDC/debug interpretation, so compare timing and methodology
    reports against the non-retimed baseline.

Do not enable both by default without a measured before/after comparison.
Use the extra reports emitted by the current flow:

- `post_*_util_hier.rpt`
- `post_*_control_sets.rpt`
- `post_route_cdc.rpt`

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
  supported `k26c-composable-platform` BD-backed target.
- `docs/remote-vivado.md`, `docs/wsl-agent-summary.md`, and
  `docs/synthesis-timing-review.md` must stay aligned with the current branch
  name and validated baseline; do not assume older branch names in those docs
  are still current.
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
