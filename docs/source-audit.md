# Source Audit

## Inputs reviewed

- `Daphne_MEZZ` at local HEAD `32e9136`
- `firmware_vivado/DAPHNE_MEZ_SELF_TRIG_SRC_V15.zip`
- `daphne-server` for PS-side register and deployment expectations

## Decision

Use `Daphne_MEZZ` as the imported baseline.

Reason:

- It already carries the maintained non-project Vivado flow.
- It contains a larger, newer RTL set than the legacy project-mode archive.
- It includes the integrated Hermes/DAQ source tree under
  `ip_repo/daphne3_ip/src/dune.daq_user_hermes_daphne_1.0/`.
- Its block design and documented AXI map match the current `daphne-server`
  expectations.

## What the legacy zip contributed

The legacy archive was still useful as a cross-check. It contains:

- a project-mode `.xpr` and generated `.bd` snapshot;
- older project-local `.xci` stubs for AXI IIC / AXI Quad SPI;
- an older `daphne3-main` source layout;
- a `selftrig/daphne_top.vhd` that is superseded by the Hermes `src/deimos`
  implementation already present in `Daphne_MEZZ`.

## Practical merge outcome

The current repo import keeps the newer `Daphne_MEZZ` sources intact and does
not vendor the legacy zip contents into the new repository tree. The legacy
archive remains a reference artifact for future diffs and regression checks,
without reintroducing project-mode generated files into version control.

## Major deltas observed in the newer source tree

- timing endpoint sources under `rtl/timing/`
- extra self-trigger implementations under `bicocca_selftrig`,
  `ciemat_selftrig`, and `eia_selftrig`
- additional misc/output buffer support modules
- C++ self-trigger simulation helper sources under `sim/selftrig_xc_cpp`
- Hermes/Deimos Ethernet source integration
