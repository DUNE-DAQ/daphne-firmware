# Formal Verification

Formal is realistic today only for small, leaf-level register/control blocks
that are mostly synchronous RTL and do not depend on Vivado IP generation,
block-design procedures, or Xilinx primitive-heavy datapaths.

Current proof entry points:

- `formal/sby/afe_config_slice_boundary_contract.sby` for reset-qualified
  per-AFE configuration readiness.
- `formal/sby/afe_capture_slice_boundary_contract.sby` for reset-qualified
  per-AFE capture validity.
- `formal/sby/analog_control_boundary_contract.sby` for reset-qualified analog
  readiness.
- `formal/sby/control_plane_boundary_contract.sby` for the neutral control
  wrapper contract.
- `formal/sby/daphne_composable_core_top_contract.sby` for the vendor-neutral
  composable shell contract when timing, Hermes, and self-triggering are
  disabled.
- `formal/sby/daphne_composable_frontend_shell_contract.sby` for the public
  composable frontend shell pass-through contract and disabled optional-boundary
  behavior.
- `formal/sby/daphne_composable_top_contract.sby` for the public composable top
  validate path through the stubbed frontend island and disabled optional
  subsystems.
- `formal/sby/configurable_delay_line_contract.sby` for the vendor-neutral
  configurable delay primitive that replaces imported `SRLC32E` delay chains.
- `formal/sby/fe_axi_axi_lite.sby` for the frontend AXI-Lite control register
  block.
- `formal/sby/fixed_delay_line_contract.sby` for the vendor-neutral fixed
  sample-delay primitive used in the isolated self-trigger path.
- `formal/sby/frontend_boundary_gate.sby` for the frontend alignment validity
  gate.
- `formal/sby/frontend_to_selftrigger_adapter_contract.sby` for the frontend
  capture to self-trigger channel-map and truncation contract.
- `formal/sby/hermes_boundary_contract.sby` for the neutral Hermes handoff
  contract.
- `formal/sby/thresholds_axi_lite.sby` for the self-trigger threshold register
  bank.
- `formal/sby/timing_subsystem_boundary_contract.sby` for the neutral timing
  wrapper contract.
- `formal/sby/trigger_pipeline_boundary_gate.sby` for the trigger readiness
  gate.
- `formal/sby/spy_buffer_boundary_gate.sby` for the spy-buffer readiness gate.

What these proofs are and are not:

- They are checked-in proof entry points intended to survive refactors.
- They prove contract-level reset, gating, readback, and illegal-write
  invariants for the current isolated wrappers and AXI-Lite leaf blocks.
- They are not complete subsystem proofs for the imported frontend, self-
  trigger algorithms, timing endpoint internals, or Hermes transport chain.
- They assume a toolchain with `yosys`, `ghdl-yosys-plugin`, and
  `symbiyosys`.
- `./scripts/formal/run_formal.sh` auto-discovers every checked-in `.sby` job
  under `formal/sby/`, supports `--list`, `--list-suites`, and named suites
  via `--suite`, and auto-sources
  `$HOME/tools/oss-cad-suite/environment` when present so the local OSS CAD
  Suite can provide `sby`, `yosys`, and the GHDL standard libraries. Pass a
  full path, a local `.sby` filename, or a basename like `fe_axi_axi_lite` to
  run one proof entry point directly. With no arguments it still runs the full
  checked-in inventory, and when multiple jobs are requested it continues
  across failures and prints a summary at the end instead of stopping at the
  first failing proof.

Current suite layout:

- `default` for the fast expected-green baseline: `fe_axi_axi_lite`,
  `thresholds_axi_lite`, `frontend_register_slice_contract`, and
  `control_plane_boundary_contract`.
- `leaf-fast` for the current leaf/boundary proof set, including the AXI-Lite
  wrappers, delay primitives, readiness gates, and isolated adapter
  contracts.
- `composable` for the three composable top-level contracts.
- `all-local` for every checked-in `.sby` job under `formal/sby/`.

Properties currently checked:

- Reset drives the architecturally visible AXI-Lite state to documented
  defaults.
- Partial AXI writes do not modify state for modules that require
  `WSTRB = "1111"`.
- Accepted writes produce a matching readable register image where the block
  exposes readback.
- The frontend trigger pulse and IDELAY load pulse self-clear after their
  documented stretch intervals.
- Boundary enable outputs are exactly the conjunction of the documented
  readiness and reset qualifiers.
- Per-AFE slice boundaries stay invalid/unsafe while taps are loading or while
  local configuration transactions are busy.
- The frontend-to-selftrigger adapter preserves per-AFE channel ordering,
  drops the frame lane, and truncates 16-bit capture samples to the 14-bit
  trigger path exactly as the legacy self-trigger path expects.
- The vendor-neutral delay primitives preserve the same bounded sample-history
  selection contract as the isolated self-trigger wrappers that consume them.
- Neutral wrappers that are still stubs are proven to remain input-independent
  and to expose only null/zero-valued outputs.

Modules intentionally left out for now:

- `front_end`, `febit3`, spy-buffer memory path, PDTS timing endpoint, and the
  Hermes transport chain.
- These blocks either rely on Xilinx primitives, large imported subtrees, or
  open environment assumptions that make a useful proof much more expensive than
  the current migration phase can justify.
- The boundary proofs deliberately stop at the wrapper edge; they do not yet
  prove the imported trigger, spy-memory, timing-endpoint, or transport
  implementations themselves.
