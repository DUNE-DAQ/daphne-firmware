# Verification Status

This document records the local verification work landed on branch
`marroyav/formal-infra`.

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

## Current known failure

`fe_axi_axi_lite` now runs to a real counterexample instead of failing in
setup. The current failing assertions are in
`formal/vhdl/fe_axi_axi_formal.vhd`:

- line 258: `trigger output must reset low`
- line 265: `all IDELAY tap registers must reset low`

The counterexample is generated at:

- `formal/sby/fe_axi_axi_lite/engine_0/trace.vcd`

## Next recommended step

Inspect the reset/observation timing in `fe_axi_axi_formal.vhd` versus the
registered reset behavior in:

- `rtl/isolated/subsystems/frontend/frontend_register_slice.vhd`
- `rtl/isolated/subsystems/frontend/frontend_register_bank.vhd`

The current evidence suggests the proof is now reaching a real reset-timing
question at the `fe_axi` to register-bank boundary, rather than failing due to
an incomplete file list.
