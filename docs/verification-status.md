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

The formal runner now lists all checked-in proof and cover jobs plus named
suites:

```bash
./scripts/formal/run_formal.sh --list
./scripts/formal/run_formal.sh --list-suites
```

Current local inventory: 22 `.sby` jobs under `formal/sby/`.

Current suite layout:

- `default`: 4 fast expected-green proofs
- `leaf-fast`: 14 leaf and boundary proofs
- `cover-fast`: 2 bounded reachability cover jobs for the AXI-Lite wrappers
- `composable`: 3 composable-top contracts
- `all-local`: the full 22-job local inventory

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

The proof still checks the documented reset image for:

- AXI handshake and response signals
- the three control outputs
- `trig`
- `idelay_load`
- every `idelay_tap` register
- every `iserdes_bitslip` register

So the harness stabilization did not reduce the reset contract; it only made
the scripted transaction phase deterministic.

`thresholds_axi_lite` now follows the same pattern: a stable sampled scenario,
an extra reset cycle before traffic starts, and clamped threshold indices so
the proof does not fail on out-of-range startup values unrelated to the AXI
behavior under test.

The runner now also uses Bash 3 compatible loops instead of `mapfile`, so the
suite interface works from the local macOS host as well as the Linux/WSL
environment.

The new cover entry points now pass locally and emit concrete traces for the
late-step AXI-Lite events they target:

```bash
./scripts/formal/run_formal.sh --suite cover-fast
```

This currently produces traces for:

- `fe_axi_axi_lite_cover`: control readback, IDELAY load pulse, and trigger
  pulse reachability
- `thresholds_axi_lite_cover`: threshold write propagation and both readback
  paths

Full local formal sweep now passes:

```bash
./scripts/formal/run_formal.sh --suite all-local
```

Current passing local inventory:

- `afe_capture_slice_boundary_contract`
- `afe_capture_to_trigger_bank_contract`
- `afe_config_slice_boundary_contract`
- `analog_control_boundary_contract`
- `configurable_delay_line_contract`
- `control_plane_boundary_contract`
- `daphne_composable_core_top_contract`
- `daphne_composable_frontend_shell_contract`
- `daphne_composable_top_contract`
- `fe_axi_axi_lite`
- `fixed_delay_line_contract`
- `frontend_boundary_gate`
- `frontend_register_slice_contract`
- `frontend_to_selftrigger_adapter_contract`
- `hermes_boundary_contract`
- `spy_buffer_boundary_gate`
- `fe_axi_axi_lite_cover`
- `thresholds_axi_lite`
- `thresholds_axi_lite_cover`
- `timing_endpoint_contract`
- `timing_subsystem_boundary_contract`
- `trigger_pipeline_boundary_gate`

## Current local verification runs

- `./scripts/formal/run_formal.sh --suite default`
- `./scripts/formal/run_formal.sh --suite leaf-fast`
- `./scripts/formal/run_formal.sh --suite cover-fast`
- `./scripts/formal/run_formal.sh --suite composable`
- `./scripts/formal/run_formal.sh --suite all-local`
- `./scripts/fusesoc/run_logic_test.sh dune-daq:daphne:frontend-control:0.1.0`
- `./scripts/fusesoc/run_logic_test.sh dune-daq:daphne:selftrigger:0.1.0`

## CI

A lightweight GitHub Actions lane now lives at
`.github/workflows/formal.yml`. It runs on `push` and `pull_request`, installs
a pinned OSS CAD Suite toolchain, and executes:

- `./scripts/formal/run_formal.sh --suite default`
- `./scripts/formal/run_formal.sh --suite cover-fast`
- `./scripts/formal/run_formal.sh --suite composable`

The `cover-fast` leg also uploads the generated cover VCD traces from:

- `formal/sby/fe_axi_axi_lite_cover/engine_0/trace*.vcd`
- `formal/sby/thresholds_axi_lite_cover/engine_0/trace*.vcd`

## Next recommended step

Add a heavier scheduled lane for `all-local` or at least for the non-fast leaf
contracts, so the current CI protects not only the default baseline and the
composable top contracts but the wider 22-job inventory as well.
