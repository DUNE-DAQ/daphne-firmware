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

Current local inventory: 27 `.sby` jobs under `formal/sby/`.

Current suite layout:

- `default`: 4 fast expected-green proofs
- `leaf-fast`: 14 leaf and boundary proofs
- `cover-fast`: 2 bounded reachability cover jobs for the AXI-Lite wrappers
- `boundary-cover`: 3 bounded reachability cover jobs for the boundary gates
- `composable`: 3 composable-top contracts
- `composable-cover`: 2 bounded composable reachability cover jobs
- `all-local`: the full 27-job local inventory

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

The boundary-gate covers now also pass locally:

```bash
./scripts/formal/run_formal.sh --suite boundary-cover
```

This currently produces traces for:

- `frontend_boundary_gate_cover`: frontend alignment validity rising once all
  documented readiness and reset-release qualifiers are satisfied
- `trigger_pipeline_boundary_gate_cover`: trigger enable rising once the shared
  readiness contract is fully satisfied
- `spy_buffer_boundary_gate_cover`: spy capture enable rising once the shared
  readiness contract is fully satisfied

The composable cover entry points now also pass locally:

```bash
./scripts/formal/run_formal.sh --suite composable-cover
```

This currently produces traces for:

- `daphne_composable_frontend_shell_cover`: a live forwarded public trigger,
  preserved frontend lane bits, and matching adapted trigger-sample images at
  the frontend-shell seam
- `daphne_composable_top_cover`: a live public trigger plus a concrete
  frontend lane image propagated through the validate-stub public top path

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
- `daphne_composable_frontend_shell_cover`
- `daphne_composable_top_contract`
- `daphne_composable_top_cover`
- `fe_axi_axi_lite`
- `fixed_delay_line_contract`
- `frontend_boundary_gate_cover`
- `frontend_boundary_gate`
- `frontend_register_slice_contract`
- `frontend_to_selftrigger_adapter_contract`
- `hermes_boundary_contract`
- `spy_buffer_boundary_gate_cover`
- `spy_buffer_boundary_gate`
- `fe_axi_axi_lite_cover`
- `thresholds_axi_lite`
- `thresholds_axi_lite_cover`
- `timing_endpoint_contract`
- `timing_subsystem_boundary_contract`
- `trigger_pipeline_boundary_gate_cover`
- `trigger_pipeline_boundary_gate`

## Current local verification runs

- `./scripts/formal/run_formal.sh --suite default`
- `./scripts/formal/run_formal.sh --suite leaf-fast`
- `./scripts/formal/run_formal.sh --suite cover-fast`
- `./scripts/formal/run_formal.sh --suite boundary-cover`
- `./scripts/formal/run_formal.sh --suite composable`
- `./scripts/formal/run_formal.sh --suite composable-cover`
- `./scripts/formal/run_formal.sh --suite all-local`
- `./scripts/fusesoc/run_logic_test.sh dune-daq:daphne:frontend-control:0.1.0`
- `./scripts/fusesoc/run_logic_test.sh dune-daq:daphne:selftrigger:0.1.0`

## CI

A lightweight GitHub Actions lane now lives at
`.github/workflows/formal.yml`. It runs on `push` and `pull_request`, installs
a pinned OSS CAD Suite toolchain, and executes:

- `./scripts/formal/run_formal.sh --suite default`
- `./scripts/formal/run_formal.sh --suite cover-fast`
- `./scripts/formal/run_formal.sh --suite boundary-cover`
- `./scripts/formal/run_formal.sh --suite composable`
- `./scripts/formal/run_formal.sh --suite composable-cover`

The cover legs also upload the generated cover VCD traces from:

- `formal/sby/fe_axi_axi_lite_cover/engine_0/trace*.vcd`
- `formal/sby/thresholds_axi_lite_cover/engine_0/trace*.vcd`
- `formal/sby/frontend_boundary_gate_cover/engine_0/trace*.vcd`
- `formal/sby/trigger_pipeline_boundary_gate_cover/engine_0/trace*.vcd`
- `formal/sby/spy_buffer_boundary_gate_cover/engine_0/trace*.vcd`
- `formal/sby/daphne_composable_frontend_shell_cover/engine_0/trace*.vcd`
- `formal/sby/daphne_composable_top_cover/engine_0/trace*.vcd`

The same workflow now also defines an `all-local` job gated to `schedule` and
`workflow_dispatch`. That heavier lane runs:

- `./scripts/formal/run_formal.sh --suite all-local`

and uploads failure artifacts from `formal/sby/**`, including:

- `logfile.txt`
- `engine_0/trace*.vcd`
- `model/design*.log`

## Next recommended step

Extend the same progress-plus-cover approach to deeper subsystem seams, or add
cross-harness invariants so the composable shell and public-top proofs cannot
drift independently.
