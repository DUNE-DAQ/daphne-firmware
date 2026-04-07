# Modular Architecture

## Intent

The repository now carries two parallel packaging views of the same imported
firmware, plus one board-owned native implementation path:

- `daphne-ip.core` is the compatibility manifest generated
  from the existing Vivado Tcl flow. This is the safe path for the currently
  qualified K26C build.
- `daphne-ip-export.core` is the export-only companion generated from the same
  Tcl flow. It exists so board-level Flow API targets can stage the legacy HDL,
  Tcl, and XCI collateral in the exported work tree without treating that
  collateral as active design source.
- `cores/features/*.core` plus `cores/features/daphne-modular.core` are the
  FuseSoC-native decomposition used for incremental refactoring, simulation, and
  eventual top-level platform packaging.
- `cores/platform/k26c-composable-platform.core` now exposes a real Flow-API
  `impl` target whose toplevel is `k26c_board_shell`. That path is now the
  board-manifest default for `./scripts/fusesoc/build_platform.sh`.

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
- `k26c-board-frontend-plane`: board-owned frontend capture/alignment plane.
- `k26c-board-timing-plane`: board-owned timing/clock/timestamp plane.
- `k26c-board-analog-control-plane`: board-owned AFE/DAC/control plane.
- `k26c-board-selftrigger-plane`: board-owned self-trigger, readout, and output
  capture plane.
- `k26c-board-spy-capture-plane`: board-owned input spy path.
- `k26c-board-shell`: board-facing top assembled only from the board-owned
  planes above.
- `daphne-modular`: transitional top-level source manifest assembled from the
  feature and boundary cores.

## Platform packaging

- `k26c-platform` still wraps the generated manifest and remains the legacy
  compatibility build path.
- `k26c-modular-platform` remains transitional and should not be the destination
  for new work.
- `k26c-composable-platform` is now the primary board-manifest default. Its
  `impl` target is Flow-API owned and builds `k26c_board_shell` directly from
  the extracted board-plane graph.

## Verification split

- Smoke tests are attached to the module cores that expose server-visible
  AXI-Lite behavior: `config-control`, `frontend-control`, and `selftrigger`.
- Imported legacy benches are kept attached to the AFE, DAC, spy-buffer, and
  frontend/self-trigger modules where they already existed.
- Formal now covers the AXI-Lite leaf blocks plus the isolated subsystem
  boundary wrappers where reset and readiness contracts are explicit enough to
  prove cheaply during the migration.
- `scripts/fusesoc/check_native_impl_graph.sh` stages the active
  `k26c-composable-platform` `impl` graph and fails if `legacy-*` core names
  reappear, if the required frontend timing constraint set drops out of the
  native path, or if `k26c_board_shell` stops being a strict board-plane
  composition layer.

## What this does not do yet

- It does not remove the legacy Tcl/IP packaging path from the repository.
- It does not yet replace the legacy packaged-IP/export lane used by older
  delivery and compatibility flows.
- It does not move MAC/IP defaults into a board-specific software/device-tree
  layer. The imported PL package defaults remain in place until the transport
  path is reworked with software ownership in mind.
- It does not provide a deployable Petalinux bundle, boot image recipe, or
  `daphne-server` installation pipeline.

## Active Native Impl Shape

The active `k26c-composable-platform` `impl` graph is now:

```text
k26c-composable-platform (impl)
└─ k26c-board-shell
   ├─ k26c-board-frontend-plane
   │  └─ frontend-island
   ├─ k26c-board-timing-plane
   ├─ k26c-board-analog-control-plane
   ├─ k26c-board-selftrigger-plane
   │  ├─ k26c-selftrigger-datapath-plane
   │  └─ k26c-board-transport-plane
   └─ k26c-board-spy-capture-plane
```

That staged graph is now audited to stay free of `legacy-*` core names and to
keep `k26c_board_shell` constrained to explicit board-plane ownership.
