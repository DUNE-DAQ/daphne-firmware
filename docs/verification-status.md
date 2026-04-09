# Verification Status

This document records the local verification work for the formal/smoke
infrastructure update in this change set.

## Build impact

These changes do not modify the Vivado implementation path, top-level RTL
connectivity, or firmware-visible behavior. They only affect local verification
entry points, helper scripts, and one formal harness dependency list.

## Local smoke verification

Verified locally with GHDL through `./scripts/fusesoc/run_logic_test.sh`:

- default suite
  - `dune-daq:daphne:config-control:0.1.0`
  - `dune-daq:daphne:selftrigger:0.1.0`
  - `dune-daq:daphne:frontend-control:0.1.0`
- composable suite
  - `dune-daq:daphne:daphne-composable-core-top:0.1.0`
  - `dune-daq:daphne:daphne-composable-frontend-shell:0.1.0`
  - `dune-daq:daphne:daphne-composable-top:0.1.0`

The smoke runner now exposes:

- `--list-suites`
- `--suite default`
- `--suite composable`
- `--suite all-local`

and uses isolated per-core build roots under `build/fusesoc-logic/` by
default so one target does not reuse stale prepared sources from another.

## Formal verification

The formal runner now lists all checked-in proof jobs:

```bash
./scripts/formal/run_formal.sh --list
```

Current local inventory: 20 `.sby` jobs under `formal/sby/`.

The `fe_axi` proof entry can now be invoked directly by basename:

```bash
./scripts/formal/run_formal.sh fe_axi_axi_lite
```

The harness now includes the isolated frontend register slice and bank files,
which are required because `fe_axi.vhd` instantiates `frontend_register_bank`.

`fe_axi_axi_lite` now passes locally. The wrapper was tightened to:

- hold reset low for an extra harness cycle before starting transactions
- freeze the scripted AXI scenario inputs during reset so the proof uses one
  consistent write/read sequence
- snapshot the live `idelayctrl_ready` status bit on read acceptance before
  checking the returned `RDATA`

These changes keep the proof focused on `fe_axi` integration behavior instead
of unconstrained startup artifacts.

## Current local spot checks

- `./scripts/formal/run_formal.sh fe_axi_axi_lite`
- `./scripts/formal/run_formal.sh frontend_register_slice_contract`
- `./scripts/fusesoc/run_logic_test.sh dune-daq:daphne:frontend-control:0.1.0`

## Next recommended step

Extend the same "stable scenario plus sampled expected value" pattern to any
other AXI-Lite harness that still compares readback against unconstrained
cycle-to-cycle formal inputs.
