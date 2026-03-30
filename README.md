# daphne-firmware

Merged working area for the DAPHNE mezzanine firmware, starting from the
current `Daphne_MEZZ` non-project Vivado flow and audited against the legacy
`firmware_vivado/DAPHNE_MEZ_SELF_TRIG_SRC_V15.zip` project-mode snapshot.

## Current status

- Imported the current firmware source tree under the original `ip_repo/` and
  `xilinx/` layout so the Vivado batch flow remains usable.
- Added board configuration indirection for the Kria build scripts through
  `DAPHNE_FPGA_PART`, `DAPHNE_BOARD_PART`, and `DAPHNE_PFM_NAME`.
- Added FuseSoC-ready logic smoke tests around the frontend trigger register
  block and the self-trigger threshold AXI window.
- Recorded the PS-side deployment contract needed by `daphne-server`.

## Repository layout

- `ip_repo/daphne3_ip/`: imported PL RTL, simulation sources, and Hermes/DAQ
  source tree.
- `xilinx/`: imported non-project Vivado scripts, now parameterized by board.
- `cores/tests/`: FuseSoC cores.
- `tests/logic/`: HDL smoke tests.
- `boards/`: board metadata and support status.
- `petalinux/`: deployment-side toolchain/dependency notes for the Kria Linux
  environment.
- `docs/`: source audit, server contract, and gap analysis.

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

Refresh the generated source manifest after editing the imported RTL/Tcl flow:

```bash
./scripts/fusesoc/refresh_cores.sh
```

### Vivado batch build

Current board-supported path:

```bash
export DAPHNE_BOARD=k26c
./scripts/fusesoc/run_vivado_batch.sh
```

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

- `cores/generated/daphne3-ip.core` is generated from the source-selection rules
  in `xilinx/daphne3_ip_gen.tcl`.
- `cores/platform/k26c-platform.core` adds the current K26C build collateral on
  top of the generated PL source manifest.
- `cores/tests/*.core` packages standalone HDL smoke tests for server-visible
  AXI register blocks.
- `scripts/fusesoc/fusesoc.sh` pins the repo-local FuseSoC config and cache
  directories so the workflow does not depend on global user configuration.

## What is still missing

This is not yet a complete multi-board deployment repo. The main remaining gaps
are:

- self-contained top-level FuseSoC/Vivado packaging for the full design;
- validated carrier support beyond the current K26C baseline;
- Petalinux recipes or boot-image generation;
- integrated build/deploy test of the generated firmware together with
  `daphne-server`.
