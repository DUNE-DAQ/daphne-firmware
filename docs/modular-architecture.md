# Modular Architecture

## Intent

The repository now carries two parallel packaging views of the same imported
firmware:

- `daphne-ip.core` is the compatibility manifest generated
  from the existing Vivado Tcl flow. This is the safe path for the currently
  qualified K26C build.
- `cores/features/*.core` plus `cores/features/daphne-modular.core` are the
  FuseSoC-native decomposition used for incremental refactoring, simulation, and
  eventual top-level platform packaging.

This split is deliberate. The modular graph should evolve quickly, while the
legacy generated manifest protects the current K26C delivery path from churn.

## Core graph

- `daphne-package`: shared records, array types, and legacy default constants.
- `daphne-subsystem-types`: neutral typed records for the isolation wrappers.
- `config-control`: PL-side board-control register bank and fan monitor logic.
- `control-plane`: additive wrapper for the existing PS-visible control/status
  ABI.
- `analog-control`: additive wrapper for the AFE/DAC configuration readiness
  boundary.
- `frontend-control`: frontend alignment/control path and AXI-Lite control
  block.
- `frontend-boundary`: additive wrapper that captures the 16-bit alignment and
  sample-format preconditions before downstream logic uses the data.
- `selftrigger`: threshold register bank plus self-trigger algorithms.
- `trigger-pipeline`: additive wrapper around trigger, descriptor, and
  downstream handoff semantics.
- `timing-endpoint`: PDTS timing endpoint block.
- `timing-subsystem`: additive wrapper around endpoint-facing typed control,
  readiness, and timestamp propagation.
- `spy-buffer`: spy-buffer capture and memory path.
- `spy-buffer-boundary`: additive wrapper that expresses capture readiness
  gating separately from the imported spy memory implementation.
- `afe-interface`: AFE SPI/control logic.
- `dac-interface`: DAC SPI/control logic.
- `hermes-transport`: imported Hermes/IPBus/UDP transport library.
- `hermes-boundary`: additive wrapper that isolates the unchanged Hermes
  transport interface from future trigger/frame cleanup.
- `daphne-modular`: top-level source manifest assembled from the feature and
  boundary cores.

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
- Formal now covers the AXI-Lite leaf blocks plus the isolated subsystem
  boundary wrappers where reset and readiness contracts are explicit enough to
  prove cheaply during the migration.

## What this does not do yet

- It does not replace the current Vivado Tcl flow with a pure CAPI2 build.
- It does not yet make the additive subsystem-boundary wrappers drive the
  imported top-level implementation; those cores are present so the graph
  reflects the intended subsystem split while the legacy feature implementations
  stay in charge of behavior.
- It does not move MAC/IP defaults into a board-specific software/device-tree
  layer. The imported PL package defaults remain in place until the transport
  path is reworked with software ownership in mind.
- It does not provide a deployable Petalinux bundle, boot image recipe, or
  `daphne-server` installation pipeline.
