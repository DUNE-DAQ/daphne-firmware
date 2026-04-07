# Composable Build Roadmap

This repo now carries the first fine-grained frontend/AFE blocks needed for a
full composable gateware flow:

- per-AFE config slice
- per-AFE analog island
- parameterized AFE config bank
- reusable per-AFE subsystem island
- flat multi-AFE AFE subsystem fabric
- per-AFE capture slice
- per-AFE frontend register slice
- banked frontend register owner
- per-AFE capture-to-trigger adapter
- parameterized frontend capture bank
- parameterized frontend island
- per-slice boundary contracts and proofs
- channel-local trigger and peak-descriptor wrappers
- per-AFE trigger bank wrapper
- per-AFE self-trigger island
- flat multi-AFE self-trigger fabric
- frontend-to-selftrigger adapter fabric
- first composable top shell
- vendor-neutral composable core-top shell with timing and Hermes boundaries
- vendor-neutral frontend-facing shell between frontend capture and the core-top
- composable K26C platform manifest with a working offline `validate` target
- explicit optional-off smoke/validate targets for the vendor-neutral shell
- first public-top offline validate path through a stubbed `frontend_island`

The older `daphne-modular` / `k26c-modular-platform` path is now transitional.
Keep it only as a compatibility stepping stone; new decomposition work should
land in the composable graph.

The next implementation steps should stay additive and avoid disturbing the
currently qualified monolithic path until each replacement is proven.

## Current baseline

The repo has now crossed the main structural integration threshold:

- `boards/k26c/board.yml` defaults to
  `dune-daq:daphne:k26c-composable-platform:0.1.0`
- `./scripts/fusesoc/build_platform.sh` defaults to the native `impl` target
  for that platform
- the active `impl` target builds `k26c_board_shell` through the Vivado Flow
  API
- the active `impl` graph is board-plane owned
- `scripts/fusesoc/check_native_impl_graph.sh` now audits that staged graph for
  `legacy-*` regressions, required frontend timing constraints, and board-shell
  plane ownership regressions
- the board self-trigger plane is now internally split into explicit datapath
  and transport subplanes
- the analog-control and spy-capture board planes now have explicit contract
  audits too, so they stay thin wrappers around the imported control and
  spy-buffer endpoints
- the frontend and timing board planes now have explicit contract audits too,
  so they stay thin wrappers around `frontend_island` and `endpoint`
- the board timing-path defaults now explicitly cover both native board-shell
  and packaged-IP/BD hierarchy roots, so the active AFE timing XDC no longer
  depends on one stale hierarchy assumption
- the board transport plane is now split into explicit Hermes and outbuffer
  subplanes, so the self-trigger/readout path is no longer carrying that
  compatibility bundle as one block
- the board manifest now owns the optional AFE input-delay model, so the
  active AFE timing XDC can stay generic while measured board-family bounds
  remain data rather than Tcl/script constants
- the aggregate `daphne-composable` feature set no longer pulls the old
  `legacy-selftrigger-datapath` core directly; the board/selftrigger aggregate
  now goes through the explicit board-plane split instead

That means the remaining work is no longer “make a real composable impl
possible”; it is “prove, harden, and simplify the native path until the legacy
lane is only a compatibility fallback”.

The vendor-neutral primitive seam is now in place for the isolated
self-trigger path. The main portability blocker has moved up to the frontend
side: the trigger/descriptor/record-builder stack and the new AFE subsystem
wrappers analyze locally without Vivado `unisim` / `xpm`, while
`frontend_island` still depends on the imported frontend/common graph.

## Immediate next steps

1. Keep the native `impl` graph auditable and stable.
   - `scripts/fusesoc/check_native_impl_graph.sh` should stay green after every
     board-plane or build-wrapper refactor.
   - Treat reintroduction of `legacy-*` core names into the active
     `k26c-composable-platform:impl` graph as a regression.
   - Treat direct leaf ownership creeping back into `k26c_board_shell` as a
     regression; it should stay a board-plane composition shell.
   - Keep the required constraint set present:
     `daphne_selftrigger_pin_map.xdc`, `afe_capture_timing.xdc`,
     `frontend_control_cdc.xdc`.

2. Prove the native board-shell path on hardware.
   - Use the current default `build_platform.sh` / `run_vivado_batch.sh`
     entrypoint and compare it directly against the known-good build lane.
   - Keep timing/AFE readout qualification ahead of further wide refactors.
   - Preserve full build trees and reports from known-good native runs.

3. Reduce the dual-lane delivery burden.
   - Keep the legacy Tcl/IP/export path available, but treat it as a
     compatibility lane rather than the architectural source of truth.
   - Keep packaged-IP preflight decisions tied to the resolved platform core
     and target, not to historical composable-only special cases.
   - Keep deployment artifact naming stable while the native path is being
     qualified.

4. Keep the public/composable documentation aligned with reality.
   - `modular-architecture.md`, `native-impl-architecture.md`, and the remote
     runbooks should describe the actual default build path, not the historical
     one.
   - Record board-shell and board-plane ownership explicitly so future work is
     easier to review.

5. Decide when the legacy lane can be demoted further.
   - The key question is no longer whether a native `impl` exists.
   - The key question is when hardware confidence is high enough that routine
     development stops depending on the legacy delivery path.

## Historical implementation milestones

The sections below summarize the major steps that made the current baseline
possible. They remain useful context when debugging why certain wrappers or
compatibility layers still exist.

### Earlier milestone: native impl target

The repo already has a real `impl` target on
`k26c-composable-platform`, which builds `k26c_board_shell`
directly through the Vivado Flow API and exports the same
`daphne_selftrigger_<gitsha>` artifact contract. This is the current
default composable build entrypoint.

### Earlier milestone: explicit board-shell ownership

The native board-shell synth/impl path now resolves through an
explicit `k26c-board-shell` feature core and the extracted bridge graph
rather than the generated `daphne-ip` source manifest. The generated
packaged-IP manifest still exists for the legacy export/build lane, but
the default native `impl` target is now meaningfully closer to a full
FuseSoC-owned source graph. `k26c_board_shell` now owns the live
implementation directly, with `legacy_public_top_bridge` retained only as
a compatibility alias for older manifest consumers.

### Earlier milestone: public-top and board-shell synth checkpoints
   - The shared Vivado flow now accepts `DAPHNE_BD_NAME` /
     `DAPHNE_BD_WRAPPER_NAME`, plus build/overlay naming overrides
     `DAPHNE_BUILD_NAME_PREFIX` / `DAPHNE_OVERLAY_NAME_PREFIX`, plus
     `DAPHNE_USER_IP_VLNV` for the packaged user-IP identity, and the BD
     generator now removes only the active design directory. That is enough to
     let future composable design identities coexist alongside the legacy
     `daphne_selftrigger_bd` while the migration is still hybrid.
   - The transitional bridge now stages the generated `daphne-ip` manifest as a
     real FuseSoC dependency and the Vivado hook auto-discovers the isolated
     HDL roots needed by the packaged-IP synth. This fixes the current
     `daphne_subsystem_pkg`/isolated-source visibility problem without claiming
     that the real board implementation already comes from the composable top.
   - The IP packager now also accepts top-identity overrides
     (`DAPHNE_IP_TOP_HDL_FILE`, `DAPHNE_IP_TOP_MODULE`,
     `DAPHNE_IP_COMPONENT_IDENTIFIER`, `DAPHNE_IP_DISPLAY_NAME`,
     `DAPHNE_IP_XGUI_FILE`) plus semicolon-separated
     `DAPHNE_IP_EXTRA_SOURCE_ROOTS` so the next migration step can swap package
     identity without rewriting the script and can pull auxiliary HDL from
     composable trees outside `ip_repo/daphne_ip/rtl`. The active board `impl`
     path is now the native board-shell flow; these overrides remain
     compatibility scaffolding for packaged-IP/export lanes, not the primary
     implementation path.
   - The repo now also has `synth_public_top_ooc` on
     `k26c-composable-platform`, which stages the real `daphne_composable_top`
     source graph through FuseSoC and runs Vivado out-of-context synthesis.
     This is the first honest Vivado checkpoint for the public composable top,
     but it is still not the board-level implementation target.
   - The repo now also has `synth_public_top_flow` on
     `k26c-composable-platform`, which resolves the same public composable top
     through the Edalize Vivado Flow API instead of the deprecated tool API.
     This is still OOC synthesis, but it is the first real flow-owned synth
     target in the migration.

## Trigger and descriptor split

The current imported `stc3` path already runs one channel per instance and
places both `trig_xc` and the legacy peak-descriptor calculator in the same sample
clock domain. The composable path should preserve that locality:

1. Keep one self-trigger / xcorr slice per channel.
2. Keep one peak-descriptor slice per channel.
3. Group eight channels under one AFE trigger bank wrapper.
4. Build one AFE self-trigger island from the bank plus one record builder per
   channel.
5. Aggregate AFE islands in a flat self-trigger fabric or AFE subsystem fabric
   before any larger project-level shell.

This keeps the trigger-to-descriptor path free of extra muxing or CDC and
matches the current timing-friendly ownership in `stc3`.

## Structural cleanup still required

- Move core roots or use a symlinked layout so FuseSoC stops warning about
  out-of-tree files.
- Add machine-readable register-map and overlay validation so generated DT/AXI
  contracts are checked before hardware deployment.

## Verification priorities

1. Keep proving boundary contracts with SymbiYosys as slices are added.
2. Keep small GHDL smoke benches on slice-level control blocks.
3. Keep the native `k26c-composable-platform` `impl` target resolving cleanly
   through the Vivado Flow API, and focus the next validation effort on
   hardware-qualified implementation/timing closure rather than more legacy
   entrypoint scaffolding.
4. Keep the matching `validate_optional_off` target passing so the null/disabled
   boundary contracts stay explicit while the shell grows.
5. Keep the new `validate_frontend_shell` target passing so the public-shell
   seam stays locally testable while the real frontend island remains vendor-
   specific.
6. Keep the new `validate_public_top` target passing so the public composable
   top stays locally testable even while the real frontend island remains
   vendor-specific.
7. Keep `scripts/fusesoc/check_native_impl_graph.sh` passing so the staged
   native `impl` graph remains free of `legacy-*` core names and keeps the
   required AFE timing constraints wired in.
