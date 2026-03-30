# Formal Verification Scaffold

Formal is realistic today only for small, leaf-level register/control blocks
that are mostly synchronous RTL and do not depend on Vivado IP generation,
block-design procedures, or Xilinx primitive-heavy datapaths.

Current scaffolds:

- `formal/sby/fe_axi_axi_lite.sby` for the frontend AXI-Lite control register
  block.
- `formal/sby/thresholds_axi_lite.sby` for the self-trigger threshold register
  bank.
- `formal/sby/trigger_pipeline_boundary_gate.sby` for the neutral trigger
  readiness gate.
- `formal/sby/spy_buffer_boundary_gate.sby` for the neutral spy-buffer
  readiness gate.

What these scaffolds are and are not:

- They are checked-in proof entry points intended to survive refactors.
- They are not yet complete behavioral proofs. The next step is to add a small
  harness/binding layer that constrains the AXI-Lite environment and encodes
  reset/write/read invariants.
- They assume a toolchain with `yosys`, `ghdl-yosys-plugin`, and
  `symbiyosys`.

Suggested first properties:

- Reset drives all architecturally visible registers to documented defaults.
- Partial AXI writes do not modify state for modules that require `WSTRB=1111`.
- Accepted writes eventually produce a matching readable register image where
  the block exposes readback.
- Trigger pulses self-clear within the documented number of cycles.
- Boundary enable outputs are exactly the conjunction of
  `config_ready && timing_ready && alignment_ready` where the new typed
  readiness wrappers define those signals.

Modules intentionally left out for now:

- `front_end`, `febit3`, spy-buffer memory path, PDTS timing endpoint, and the
  Hermes transport chain.
- These blocks either rely on Xilinx primitives, large imported subtrees, or
  open environment assumptions that make a useful proof much more expensive than
  the current migration phase can justify.
- The new boundary proofs deliberately stop at the wrapper edge; they do not
  yet prove the imported trigger or spy-memory implementations themselves.
