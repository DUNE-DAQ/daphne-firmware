# Formal Verification

Formal is realistic today only for small, leaf-level register/control blocks
that are mostly synchronous RTL and do not depend on Vivado IP generation,
block-design procedures, or Xilinx primitive-heavy datapaths.

Current proof entry points:

- `formal/sby/analog_control_boundary_contract.sby` for reset-qualified analog
  readiness.
- `formal/sby/control_plane_boundary_contract.sby` for the neutral control
  wrapper contract.
- `formal/sby/fe_axi_axi_lite.sby` for the frontend AXI-Lite control register
  block.
- `formal/sby/frontend_boundary_gate.sby` for the frontend alignment validity
  gate.
- `formal/sby/hermes_boundary_contract.sby` for the neutral Hermes handoff
  contract.
- `formal/sby/thresholds_axi_lite.sby` for the self-trigger threshold register
  bank.
- `formal/sby/timing_endpoint_contract.sby` for the guide-driven timing
  endpoint integration contract wrapper.
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
- The timing endpoint contract proof captures wrapper/integration semantics
  for reset, ready, timestamp validity, command-zero sync handling, and TX
  disable behavior. It does not prove the imported PDTS endpoint algorithm.
