# Composable Build Roadmap

This repo now carries the first fine-grained frontend/AFE blocks needed for a
full composable gateware flow:

- per-AFE config slice
- per-AFE analog island
- parameterized AFE config bank
- reusable per-AFE subsystem island
- flat multi-AFE AFE subsystem fabric
- per-AFE capture slice
- parameterized frontend capture bank
- parameterized frontend island
- per-slice boundary contracts and proofs
- channel-local trigger and peak-descriptor wrappers
- per-AFE trigger bank wrapper
- per-AFE self-trigger island
- flat multi-AFE self-trigger fabric
- frontend-to-selftrigger adapter
- first composable top shell
- source-only composable K26C platform manifest

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

1. Introduce a shared frontend-common block.
   - Extract the remaining global pieces from `front_end.vhd`:
     `IDELAYCTRL`, AFE forwarded clock, and CDC/pulse resync logic.
   - Keep `frontend_island.vhd` as the drop-in wrapper so the old ABI remains
     stable.

2. Split frontend control per AFE.
   - Isolate one AFE's tap/bitslip storage and stretched-load pulse from
     `fe_axi.vhd`.
   - Retain a thin compatibility AXI wrapper so software does not need to
     change.

3. Add an AFE config bank wrapper.
   - Done for the direct SPI ownership layer with `afe_config_bank.vhd`.
   - Next refinement is to preserve the existing physical grouping
     (`afe0`, `afe12`, and `afe34`) as a higher-level compatibility shell.
   - Allow inactive slices to be tied off cleanly when `AFE_COUNT_G < 5`.
   - The repo now also has `afe_subsystem_island.vhd` so one AFE can own both
     analog configuration and self-trigger composition behind a single reusable
     boundary.

4. Grow the first composable top-level shell.
   - The repo now has a source-only `daphne_composable_top` that wires
     `frontend_island -> frontend_to_selftrigger_adapter -> selftrigger_fabric`.
   - The repo now also has `afe_subsystem_fabric.vhd` so future tops can move
     from separate analog/self-trigger composition to one flat multi-AFE
     subsystem fabric without changing the per-AFE ownership boundary.
   - Next additions should pull timing, spybuffer, and Hermes into that shell
     without changing its public generic contract.

5. Add a real composable platform `impl` target only after the shell has a
   stable top-level entity and pin/clock ownership.

## Trigger and descriptor split

The current imported `stc3` path already runs one channel per instance and
places both `trig_xc` and the legacy peak-descriptor calculator in the same sample
clock domain. The composable path should preserve that locality:

1. Keep one self-trigger / xcorr slice per channel.
2. Keep one peak-descriptor slice per channel.
3. Group eight channels under one AFE trigger bank wrapper.
4. Build one AFE self-trigger island from the bank plus one record builder per
   channel.
5. Aggregate AFE islands in a flat self-trigger fabric before any larger
   project-level shell.

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
3. When the composable top exists, add source-only `--setup` validation in
   FuseSoC first, then move to Vivado implementation.
