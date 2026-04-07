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
- Added vendor-neutral delay/FIFO primitives so the isolated self-trigger path
  can be analyzed locally without Vivado `unisim` / `xpm`.
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
export DAPHNE_GIT_SHA="$(git rev-parse --short=7 HEAD)"
./scripts/fusesoc/fusesoc.sh run --target=impl dune-daq:daphne:k26c-platform:0.1.0
```

The convenience wrapper now dispatches through the same FuseSoC target:

```bash
export DAPHNE_BOARD=k26c
./scripts/fusesoc/run_vivado_batch.sh
```

This target still preserves the qualified `xilinx/vivado_batch.tcl` flow; the
change is that FuseSoC now owns the top-level entry point and work root.
If you call `fusesoc run` directly, set `DAPHNE_GIT_SHA` first so the legacy
artifact naming keeps the real commit instead of falling back to `0000000`.

For the composable platform, the checked-in implementation hook is still the
transitional bridge target:

```bash
./scripts/fusesoc/build_platform.sh --composable --target impl_legacy_bridge
```

That bridge still builds the qualified legacy K26C design, but the Vivado hook
and block-design flow now honor `DAPHNE_BD_NAME` / `DAPHNE_BD_WRAPPER_NAME`
 overrides, plus `DAPHNE_BUILD_NAME_PREFIX` /
 `DAPHNE_OVERLAY_NAME_PREFIX` for artifact naming, and only clear the active
 block-design directory instead of deleting the entire `bd/` tree. This keeps
 the migration path open for side-by-side legacy and future composable design
 identities.

The IP packaging Tcl also now accepts top-identity overrides
(`DAPHNE_IP_TOP_HDL_FILE`, `DAPHNE_IP_TOP_MODULE`,
`DAPHNE_IP_COMPONENT_IDENTIFIER`, `DAPHNE_IP_DISPLAY_NAME`,
`DAPHNE_IP_XGUI_FILE`), still defaulting to the legacy packaged top. That is a
scaffolding step only: source discovery is still centered on the imported
legacy tree until the composable implementation becomes the real build owner.

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
something relative to the staged `xilinx/` directory in the active FuseSoC
work root, for example:

```bash
export DAPHNE_GIT_SHA="$(git rev-parse --short=7 HEAD)"
export DAPHNE_OUTPUT_DIR="./output-$DAPHNE_GIT_SHA"
```

Then expect the main artifacts under:

```text
<work-root>/xilinx/output-<gitsha>/
```

with files such as:

```text
daphne_selftrigger_<gitsha>.bit
daphne_selftrigger_<gitsha>.bin
daphne_selftrigger_<gitsha>.xsa
```

Avoid setting `DAPHNE_OUTPUT_DIR` to a Linux absolute path outside the active
FuseSoC work root when the build runs through Windows Vivado from WSL.

After the build, run the DT overlay packaging step against that work-root
artifact directory:

```bash
./scripts/package/complete_dtbo_bundle.sh <work-root>/xilinx/output-$DAPHNE_GIT_SHA
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
- `cores/common/daphne-subsystem-primitives.core` carries vendor-neutral delay
  and FIFO blocks used to peel Xilinx primitive dependencies out of the
  isolated self-trigger path.
- `cores/features/analog-control.core` captures the AFE/DAC configuration
  readiness boundary that must settle before frontend alignment.
- `cores/features/afe-config-slice.core`,
  `cores/features/afe-analog-island.core`,
  `cores/features/afe-config-bank.core`,
  `cores/features/afe-subsystem-island.core`,
  `cores/features/afe-subsystem-fabric.core`,
  `cores/features/afe-config-slice-boundary.core`,
  `cores/features/afe-capture-slice.core`,
  `cores/features/afe-capture-slice-boundary.core`,
  `cores/features/frontend-register-slice.core`,
  `cores/features/frontend-register-bank.core`,
  `cores/features/frontend-bitlane.core`,
  `cores/features/frontend-capture-bank.core`,
  `cores/features/frontend-registers.core`,
  and `cores/features/frontend-island.core` split the current frontend/AFE path
  into smaller reusable IP blocks while keeping the imported monolithic path
  available.
- `cores/features/control-plane.core`,
  `cores/features/frontend-boundary.core`,
  `cores/features/spy-buffer-boundary.core`,
  `cores/features/timing-subsystem.core`,
  `cores/features/trigger-pipeline.core`, and
  `cores/features/hermes-boundary.core` expose the additive subsystem
  boundaries directly in the FuseSoC graph.
- `cores/features/daphne-composable.core` is the fine-grained subsystem graph
  intended to seed future partial and parameterized gateware builds.
- `cores/features/self-trigger-xcorr-channel.core`,
  `cores/features/peak-descriptor-channel.core`, and
  `cores/features/afe-trigger-bank.core` split the existing one-channel
  self-trigger path into reusable trigger and descriptor slices while keeping
  frame ownership outside the slices for now.
- `cores/features/stc3-record-builder.core`,
  `cores/features/afe-selftrigger-island.core`,
  `cores/features/selftrigger-fabric.core`,
  `cores/features/afe-capture-to-trigger-bank.core`, and
  `cores/features/frontend-to-selftrigger-adapter.core` now capture the first
  composable trigger assembly layers above the per-channel slices.
- The isolated self-trigger graph now analyzes locally through the per-channel
  trigger/descriptor slices, `stc3_record_builder`, AFE trigger bank,
  per-AFE self-trigger island, and the AFE subsystem fabric without Vivado
  vendor libraries.
- `cores/features/daphne-composable-top.core` is the first source-only top
  shell. It currently wires `frontend_island` into the per-AFE adapter/fabric
  path and then into `afe_subsystem_fabric`, so analog configuration and
  self-trigger ownership now line up at the AFE boundary.
- `cores/features/daphne-composable-core-top.core` is the vendor-neutral
  composable shell used for offline validation. It already instantiates the
  timing and Hermes boundary wrappers around the AFE subsystem fabric.
- `cores/features/daphne-composable-frontend-shell.core` is the next shell up:
  it owns the frontend sample handoff into the composable core-top while
  staying vendor-neutral and locally testable.
- `cores/features/daphne-modular.core` remains as the older transitional
  source-graph wrapper. New decomposition work should land in
  `daphne-composable`.
- `cores/generated/daphne-ip.core` is generated from the source-selection rules
  in `xilinx/daphne_ip_gen.tcl` and remains the compatibility path for the
  current K26C Vivado build.
- `cores/platform/k26c-platform.core` keeps the working legacy K26C path.
- `cores/platform/k26c-modular-platform.core` is the source-only platform
  wrapper for the older transitional modular graph and should not receive new
  feature decomposition work.
- `cores/platform/k26c-composable-platform.core` is the composable platform
  wrapper for the finer-grained subsystem graph. It now exposes a GHDL-backed
  `validate` target so the isolated shell can be compiled and smoke-tested
  without Vivado. It also now exposes a transitional `impl_legacy_bridge`
  target so the composable platform can serve as a first-class FuseSoC entry
  point while Vivado still builds the qualified legacy/generated K26C design.
- `scripts/fusesoc/build_platform.sh --composable` now defaults to the safe
  `validate_public_top` target for the composable platform. Use
  `--composable --target impl_legacy_bridge` when you explicitly want the
  transitional Vivado-backed bridge entry point.
- `scripts/fusesoc/fusesoc.sh` pins the repo-local FuseSoC config and cache
  directories so the workflow does not depend on global user configuration.
- `scripts/fusesoc/run_logic_test.sh` now exercises the module-level smoke
  targets directly.

## Verification posture

- `config-control`, `frontend-control`, and `selftrigger` expose `sim` targets
  backed by GHDL smoke benches.
- `frontend-registers` and `afe-config-slice` expose smaller GHDL smoke targets
  for the isolated control primitives that future partial builds will reuse.
- `afe-interface`, `dac-interface`, and `spy-buffer` expose `sim` targets that
  retain the imported legacy benches under vendor-library simulators such as
  XSim.
- `frontend-registers`, `afe-config-slice-boundary`, `afe-capture-slice-boundary`,
  and `selftrigger` expose checked proof entry points for their interface
  contracts.
- `daphne-composable-core-top` and `k26c-composable-platform` now expose
  vendor-neutral GHDL smoke validation for the isolated shell, including the
  timing and Hermes boundary wrappers.
- `daphne-composable-core-top` and `k26c-composable-platform` also expose
  `sim_optional_off` / `validate_optional_off` targets to check the same shell
  with timing, Hermes, and self-trigger disabled explicitly.
- `daphne-composable-frontend-shell` now exposes a GHDL smoke target, and
  `k26c-composable-platform` mirrors it as `validate_frontend_shell`.
- `daphne-composable-top` now also exposes a GHDL smoke target behind a
  validate-only `frontend_island` stub, and `k26c-composable-platform`
  mirrors it as `validate_public_top`.
- The new trigger/descriptor wrappers are source-only preparation work around
  the imported `trig_xc` and legacy peak-descriptor calculator; they are not yet
  integrated as the top-level frame source.
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
