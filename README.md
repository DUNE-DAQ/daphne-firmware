# daphne-firmware

Merged working area for the DAPHNE mezzanine firmware, starting from the
current `Daphne_MEZZ` non-project Vivado flow and audited against the legacy
`firmware_vivado/DAPHNE_MEZ_SELF_TRIG_SRC_V15.zip` project-mode snapshot.

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

## Repository layout

- `ip_repo/daphne3_ip/`: imported PL RTL, simulation sources, and Hermes/DAQ
  source tree.
- `xilinx/`: imported non-project Vivado scripts, now parameterized by board.
- `cores/tests/`: FuseSoC cores.
- `cores/common/`: reusable shared package/common cores.
- `cores/features/`: reusable feature-block cores plus module-level simulation
  and formal targets.
- `tests/logic/`: HDL smoke tests.
- `boards/`: board metadata and support status.
- `petalinux/`: deployment-side toolchain/dependency notes for the Kria Linux
  environment.
- `docs/`: source audit, server contract, modular architecture, and gap
  analysis.
- `formal/`: SymbiYosys scaffolds for leaf blocks that are suitable for formal.

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
./scripts/fusesoc/run_vivado_batch.sh
```

If Vivado runs on a remote server instead of the local workstation, use the
repo-local runbook and wrapper:

```bash
./scripts/remote/run_remote_vivado_chain.sh
```

See `docs/remote-vivado.md` and `docs/agent-handoff.md`.

Optional overrides:

```bash
export DAPHNE_FPGA_PART=xck26-sfvc784-2LV-c
export DAPHNE_BOARD_PART=xilinx.com:k26c:part0:1.4
export DAPHNE_PFM_NAME=xilinx:k26c:name:0.0
export DAPHNE_MAX_THREADS=8
```

## Source decisions

The working baseline is the current `Daphne_MEZZ` tree. The legacy zip was used
as a reference source, not as the primary import, because the current tree
already contains the newer non-project flow, the expanded timing/self-trigger
logic, and the integrated Hermes source tree. Details are recorded in
`docs/source-audit.md`.

## FuseSoC structure

- `cores/common/daphne-package.core` provides the shared DAPHNE package.
- `cores/features/*.core` split the design into reusable feature blocks:
  configuration, frontend control, self-trigger logic, timing, spy-buffer,
  AFE/DAC interfaces, and Hermes transport.
- `cores/features/daphne3-modular.core` reassembles the top-level RTL from the
  modular blocks without changing the currently qualified Vivado flow.
- `cores/generated/daphne3-ip.core` is generated from the source-selection rules
  in `xilinx/daphne3_ip_gen.tcl` and remains the compatibility path for the
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
