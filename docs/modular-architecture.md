# Modular Architecture

## Intent

The repository now carries two parallel packaging views of the same imported
firmware:

- `cores/generated/daphne3-ip.core` is the compatibility manifest generated
  from the existing Vivado Tcl flow. This is the safe path for the currently
  qualified K26C build.
- `cores/features/*.core` plus `cores/features/daphne3-modular.core` are the
  FuseSoC-native decomposition used for incremental refactoring, simulation, and
  eventual top-level platform packaging.

This split is deliberate. The modular graph should evolve quickly, while the
legacy generated manifest protects the current K26C delivery path from churn.

## Core graph

- `daphne-package`: shared records, array types, and legacy default constants.
- `config-control`: PL-side board-control register bank and fan monitor logic.
- `frontend-control`: frontend alignment/control path and AXI-Lite control
  block.
- `selftrigger`: threshold register bank plus self-trigger algorithms.
- `timing-endpoint`: PDTS timing endpoint block.
- `spy-buffer`: spy-buffer capture and memory path.
- `afe-interface`: AFE SPI/control logic.
- `dac-interface`: DAC SPI/control logic.
- `hermes-transport`: imported Hermes/IPBus/UDP transport library.
- `daphne3-modular`: top-level source manifest assembled from the feature cores.

## Platform packaging

- `k26c-platform` continues to wrap the generated manifest and is the current
  non-breaking build path.
- `k26c-modular-platform` wraps the modular graph with the same board/platform
  collateral so the repo has a clean destination for future top-level Vivado or
  FuseSoC integration work.

## Verification split

- Smoke tests are attached to the module cores that expose server-visible
  AXI-Lite behavior: `config-control`, `frontend-control`, and `selftrigger`.
- Imported legacy benches are kept attached to the AFE, DAC, spy-buffer, and
  frontend/self-trigger modules where they already existed.
- Formal is only scaffolded for AXI-Lite leaf blocks. That is where bounded
  invariants are straightforward enough to justify effort during the migration.

## What this does not do yet

- It does not replace the current Vivado Tcl flow with a pure CAPI2 build.
- It does not move MAC/IP defaults into a board-specific software/device-tree
  layer. The imported PL package defaults remain in place until the transport
  path is reworked with software ownership in mind.
- It does not provide a deployable Petalinux bundle, boot image recipe, or
  `daphne-server` installation pipeline.
