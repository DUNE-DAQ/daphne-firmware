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

The vendor-neutral primitive seam is now in place for the isolated
self-trigger path. The main portability blocker has moved up to the frontend
side: the trigger/descriptor/record-builder stack and the new AFE subsystem
wrappers analyze locally without Vivado `unisim` / `xpm`, while
`frontend_island` still depends on the imported frontend/common graph.

## Immediate next steps

1. Keep the frontend split thin and compatibility-safe.
   - `frontend_common.vhd` now owns the shared `IDELAYCTRL`, forwarded AFE
     clock, and CDC/pulse resync logic.
   - `frontend_register_slice.vhd` and `frontend_register_bank.vhd` now own
     the per-AFE tap/bitslip state under the existing `fe_axi.vhd` AXI ABI.
   - Keep `frontend_island.vhd` as the drop-in wrapper so software does not
     need to change while the internals are decomposed further.

2. Add an AFE config bank wrapper.
   - Done for the direct SPI ownership layer with `afe_config_bank.vhd`.
   - Next refinement is to preserve the existing physical grouping
     (`afe0`, `afe12`, and `afe34`) as a higher-level compatibility shell.
   - Allow inactive slices to be tied off cleanly when `AFE_COUNT_G < 5`.
   - The repo now also has `afe_subsystem_island.vhd` so one AFE can own both
     analog configuration and self-trigger composition behind a single reusable
     boundary.

3. Keep pushing the frontend-to-trigger seam down to the AFE boundary.
   - `afe_capture_to_trigger_bank.vhd` now owns one AFE's sample-lane mapping.
   - `frontend_to_selftrigger_adapter.vhd` is now only the flat wrapper that
     stitches those per-AFE adapters into the legacy flattened trigger bank.

4. Grow the first composable top-level shell.
   - The repo now has a source-only `daphne_composable_top` that wires
     `frontend_island -> frontend_to_selftrigger_adapter -> afe_subsystem_fabric`.
   - The repo also now has `daphne_composable_core_top`, a vendor-neutral shell
     that wraps the AFE subsystem fabric with the current timing and Hermes
     boundaries so the platform can be validated offline.
   - The repo now also has `daphne_composable_frontend_shell`, which sits one
     layer closer to the public top: it owns the frontend sample handoff into
     the vendor-neutral core-top and validates that seam without requiring the
     vendor-specific frontend island.
   - Self-trigger enable now lives inside the AFE subsystem island/fabric,
     which keeps analog configuration and trigger ownership aligned per AFE.
   - Next additions should pull spybuffer and the remaining public reset
     contract into that shell family without changing the generic contract.

5. Keep the composable platform validate target green, then add a real `impl`
   target only after the shell has stable top-level entity and pin/clock ownership.
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
     composable trees outside `ip_repo/daphne_ip/rtl`. The default source set
     is still legacy-first, so this remains scaffolding rather than the final
     composable implementation path.
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
   - The repo now also has `impl_legacy_flow` on
     `k26c-composable-platform`, which uses the same Edalize Flow API style at
     the board level: a `tclSource` preamble generates/packages the qualified
     legacy K26C block design and wrapper inside the exported build tree, then
     Vivado flow-owned synth/impl runs on `daphne_selftrigger_bd_wrapper`.
     This is still hybrid, but it moves the board build off the deprecated
     pre-build hook path and closer to a full FuseSoC-owned implementation.
   - The repo now also has the native board-shell `impl` target on
     `k26c-composable-platform`, which builds `legacy_public_top_bridge`
     directly through the Vivado Flow API and exports the same
     `daphne_selftrigger_<gitsha>` artifact contract. This is the current
     default composable build entrypoint.
   - The native board-shell synth/impl path now resolves through an
     explicit `k26c-board-shell` feature core and the extracted bridge graph
     rather than the generated `daphne-ip` source manifest. The generated
     packaged-IP manifest still exists for the legacy export/build lane, but
     the default native `impl` target is now meaningfully closer to a full
     FuseSoC-owned source graph. The old `legacy-public-top-bridge` core name
     remains as a compatibility alias until the underlying RTL entity is
     renamed.

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
3. Keep the new `k26c-composable-platform` `validate` target passing under
   GHDL, then move to a real Vivado implementation target once the top-level
   shell owns pins, clocks, and resets cleanly.
4. Keep the matching `validate_optional_off` target passing so the null/disabled
   boundary contracts stay explicit while the shell grows.
5. Keep the new `validate_frontend_shell` target passing so the public-shell
   seam stays locally testable while the real frontend island remains vendor-
   specific.
6. Keep the new `validate_public_top` target passing so the public composable
   top stays locally testable even while the real frontend island remains
   vendor-specific.
