# daphne-firmware

Merged working area for the DAPHNE mezzanine firmware, starting from the
current non-project Vivado flow and audited against the legacy project-mode
snapshot.

## Current status

- Imported the current firmware source tree under the original `ip_repo/` and
  `xilinx/` layout so the Vivado batch flow remains usable.
- Added board configuration indirection for the Kria build scripts through
  `DAPHNE_FPGA_PART`, `DAPHNE_BOARD_PART`, and `DAPHNE_PFM_NAME`.
- Added reusable FuseSoC module cores for common, feature, and platform layers
  while preserving the original generated source manifest and Vivado batch path.
- Added FuseSoC-ready smoke tests around the frontend trigger register block,
  the self-trigger threshold AXI window, and the PL-side board-control
  register block.
- Added formal verification scaffolds for the AXI-Lite leaf blocks where a
  proof has a realistic cost/benefit ratio during the migration.
- Recorded the PS-side deployment contract needed by `daphne-server`.
- Qualified a WSL2-driven Windows Vivado/Vitis K26C hardware build flow and
  captured that baseline for follow-on isolation work.
- Started an additive `rtl/isolated/` scaffolding layer to prepare subsystem
  contracts and future formal harnesses without disturbing the imported blob.
- Started a repo-owned `petalinux/meta-daphne/` scaffold so `system.dtb`,
  overlay install, and service packaging ownership can move into this repo.
- Added terminal-driven PetaLinux project/build wrappers so the repo can create
  a KR260 project, apply the `.xsa`, build the image, and collect the outputs
  into a stable bundle layout.

## Repository layout

- `ip_repo/daphne_ip/`: imported PL RTL, simulation sources, and Hermes/DAQ
  source tree.
- `xilinx/`: imported non-project Vivado scripts, now parameterized by board.
- `cores/tests/`: FuseSoC cores.
- `cores/common/`: reusable shared package/common cores.
- `cores/features/`: reusable feature-block cores plus module-level simulation
  and formal targets.
- `tests/logic/`: HDL smoke tests.
- `boards/`: board metadata and support status.
- `petalinux/`: deployment-side toolchain/dependency notes for the Kria Linux
  environment, including the first `meta-daphne/` layer scaffold.
- `docs/`: source audit, server contract, modular architecture, and gap
  analysis.
- `formal/`: SymbiYosys scaffolds for leaf blocks that are suitable for formal.
- `rtl/isolated/`: neutral subsystem wrapper shells and typed interfaces for the
  isolation/formal-prep phase.

## Quick start

### Logic smoke test with FuseSoC

Requires `fusesoc`, `edalize`, and `ghdl`.

```bash
./scripts/fusesoc/fusesoc.sh list-cores
./scripts/fusesoc/run_logic_test.sh
```

To run a single smoke test instead of the default suite:

```bash
./scripts/fusesoc/run_logic_test.sh dune-daq:daphne:frontend-test:0.1.0
```

Run the checked-in formal scaffolds:

```bash
./scripts/formal/run_formal.sh
```

Refresh the generated legacy source manifest after editing the imported
RTL/Tcl flow:

```bash
./scripts/fusesoc/refresh_cores.sh
```

### Vivado batch build

Current board-supported path:

```bash
export DAPHNE_BOARD=k26c
./scripts/fusesoc/fusesoc.sh run --target=impl dune-daq:daphne:k26c-platform:0.1.0
```

The convenience wrapper now dispatches through the same FuseSoC target:

```bash
export DAPHNE_BOARD=k26c
./scripts/fusesoc/run_vivado_batch.sh
```

This target still preserves the qualified `xilinx/vivado_batch.tcl` flow; the
change is that FuseSoC now owns the top-level entry point and work root.

If Vivado runs on a remote server instead of the local workstation, use the
repo-local runbook and wrapper:

```bash
./scripts/remote/run_remote_vivado_chain.sh
```

If you are in WSL2 and Vivado/Vitis 2024.1 are installed on Windows, use:

```bash
./scripts/wsl/check_windows_xilinx.sh
./scripts/wsl/run_wsl_vivado_chain.sh
```

`run_wsl_vivado_chain.sh` is the single-command path. It runs:

- Windows-tool sanity check
- Vivado preflight
- synth/implementation
- DT overlay packaging

For WSL-driven Windows Vivado runs, keep `DAPHNE_OUTPUT_DIR` unset or set it to
something relative to `xilinx/`, for example:

```bash
export DAPHNE_GIT_SHA="$(git rev-parse --short=7 HEAD)"
export DAPHNE_OUTPUT_DIR="./output-$DAPHNE_GIT_SHA"
```

Then expect the main artifacts under:

```text
xilinx/output-<gitsha>/
```

with files such as:

```text
daphne_selftrigger_<gitsha>.bit
daphne_selftrigger_<gitsha>.bin
daphne_selftrigger_<gitsha>.xsa
```

Avoid setting `DAPHNE_OUTPUT_DIR` to a Linux absolute path like
`$PWD/xilinx/output-<gitsha>` when the build runs through Windows Vivado from
WSL.

After the build, run:

```bash
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output-$DAPHNE_GIT_SHA
```

On WSL, this packaging script now auto-loads the Windows `xsct` wrapper if it
is not already on `PATH`.

See `docs/remote-vivado.md`, `docs/wsl-windows-vivado.md`, and
`docs/agent-handoff.md`.

To finish the DT overlay packaging from an existing `.xsa` / `.bin` pair:

```bash
./scripts/package/complete_dtbo_bundle.sh
```

The current isolation/formal-prep structure is described in
`docs/rtl-isolation-plan.md`, the dependency transition is tracked in
`docs/dependency-transition-plan.md`, and the current qualified build
checkpoint is recorded in `docs/build-baseline.md`. The current firmware
artifact boundary is documented in `docs/firmware-delivery.md`.

To drive the repo-owned PetaLinux flow after the hardware handoff is ready:

```bash
./scripts/petalinux/build_kr260_image.sh \
  /path/to/petalinux-project \
  /path/to/hw-handoff-dir \
  --output-dir ./xilinx/output
```

Optional overrides:

```bash
export DAPHNE_FPGA_PART=xck26-sfvc784-2LV-c
export DAPHNE_BOARD_PART=xilinx.com:k26c:part0:1.4
export DAPHNE_PFM_NAME=xilinx:k26c:name:0.0
export DAPHNE_MAX_THREADS=8
```

## Source decisions

The working baseline is the current imported non-project Vivado tree. The
legacy zip was used as a reference source, not as the primary import, because
the current tree already contains the newer non-project flow, the expanded
timing/self-trigger logic, and the integrated Hermes source tree. Details are
recorded in `docs/source-audit.md`.

## FuseSoC structure

- `cores/common/daphne-package.core` provides the shared DAPHNE package.
- `cores/features/*.core` split the design into reusable feature blocks:
  configuration, frontend control, self-trigger logic, timing, spy-buffer,
  AFE/DAC interfaces, and Hermes transport.
- `rtl/isolated/subsystems/frontend/frontend_boundary.vhd` starts capturing the
  frontend alignment contract separately from downstream trigger semantics.
- `cores/common/daphne-subsystem-types.core` carries the neutral typed records
  used by the isolation/formal-prep wrapper layer.
- `cores/features/analog-control.core` captures the AFE/DAC configuration
  readiness boundary that must settle before frontend alignment.
- `cores/features/control-plane.core`,
  `cores/features/frontend-boundary.core`,
  `cores/features/spy-buffer-boundary.core`,
  `cores/features/timing-subsystem.core`,
  `cores/features/trigger-pipeline.core`, and
  `cores/features/hermes-boundary.core` expose the additive subsystem
  boundaries directly in the FuseSoC graph.
- `cores/features/daphne-modular.core` reassembles the top-level RTL from the
  modular blocks without changing the currently qualified Vivado flow.
- `cores/generated/daphne-ip.core` is generated from the source-selection rules
  in `xilinx/daphne_ip_gen.tcl` and remains the compatibility path for the
  current K26C Vivado build.
- `cores/platform/k26c-platform.core` keeps the working legacy K26C path.
- `cores/platform/k26c-modular-platform.core` is the source-only platform
  wrapper for the emerging modular graph.
- `scripts/fusesoc/fusesoc.sh` pins the repo-local FuseSoC config and cache
  directories so the workflow does not depend on global user configuration.
- `scripts/fusesoc/run_logic_test.sh` now exercises the module-level smoke
  targets directly.

## Verification posture

- `config-control`, `frontend-control`, and `selftrigger` expose `sim` targets
  backed by GHDL smoke benches.
- `afe-interface`, `dac-interface`, and `spy-buffer` expose `sim` targets that
  retain the imported legacy benches under vendor-library simulators such as
  XSim.
- `frontend-control` and `selftrigger` expose `formal` scaffolds that pin the
  expected SymbiYosys proof entry points for the AXI-Lite register blocks.
- Timing, Hermes transport, and the full frontend datapath are documented as
  future formal candidates, not present-day proof targets.

## What is still missing

This is not yet a complete multi-board deployment repo. The main remaining gaps
are:

- top-level Vivado consumption of the new modular graph rather than the current
  generated compatibility manifest;
- validated carrier support beyond the current K26C baseline;
- Petalinux recipes, `BOOT.BIN` assembly, and boot-image generation;
- integrated build/deploy test of the generated firmware together with
  `daphne-server`.
- proof-carrying module contracts and real formal harnesses beyond the current
  leaf-block scaffolds.
