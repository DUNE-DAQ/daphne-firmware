# Formal Verification

Formal is realistic today only for small, leaf-level register/control blocks
that are mostly synchronous RTL and do not depend on Vivado IP generation,
block-design procedures, or Xilinx primitive-heavy datapaths.

Ownership note:

- the formal verification harnesses, proof entry points, and integration in
  this repo are maintained by Manuel Arroyave (FNAL)
- the matching subsystem attribution map lives in `docs/developer-manifest.md`

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
  composable shell contract with explicit timing-boundary passthrough, live
  Hermes-boundary passthrough, and disabled self-triggering behavior.
- `formal/sby/daphne_composable_frontend_shell_contract.sby` for the public
  composable frontend shell pass-through contract, explicit timing-boundary
  passthrough, live Hermes-boundary passthrough, and disabled self-trigger
  behavior.
- `formal/sby/daphne_composable_top_analog_contract.sby` for the public
  composable top analog-control seam after a reset-release sequence, including
  equality to the standalone frontend shell on the AFE/DAC control pins and the
  idle analog-busy status image.
- `formal/sby/daphne_composable_top_contract.sby` for the public composable top
  validate path through the stubbed frontend island, explicit timing-boundary
  passthrough, equivalence to the standalone frontend shell seam, and adapter-
  view mapping of the exposed frontend lane image into the trigger sample
  path.
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
- `formal/sby/selftrigger_register_bank_contract.sby` for the arithmetic
  threshold/counter AXI-Lite decode in the isolated self-trigger register
  plane.
- `formal/sby/hermes_boundary_contract.sby` for the deterministic local Hermes
  handoff contract used by the composable verification model.
- `formal/sby/thresholds_axi_lite.sby` for the self-trigger threshold register
  bank.
- `formal/sby/timing_subsystem_boundary_contract.sby` for the local-neutral,
  endpoint-selected timing wrapper contract.
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
- `cover-fast` for the bounded reachability checks on the AXI-Lite wrappers.
- `boundary-cover` for the bounded reachability checks on the frontend,
  trigger-pipeline, and spy-buffer gates.
- `composable` for the four composable top-level contracts.
- `composable-cover` for the bounded public composable reachability checks at
  the frontend shell seam, the top-level validate path, the live public Hermes
  seam, and the live public timing seam.
- `all-local` for every checked-in `.sby` job under `formal/sby/`.

Two dedicated cover entry points now complement the AXI-Lite proofs:

- `formal/sby/fe_axi_axi_lite_cover.sby` binds
  `formal/vhdl/fe_axi_axi_cover.psl` to the harness and emits bounded cover
  traces for control readback, IDELAY load pulse assertion, and trigger pulse
  reachability.
- `formal/sby/thresholds_axi_lite_cover.sby` binds
  `formal/vhdl/thresholds_axi_cover.psl` to the harness and emits bounded cover
  traces for threshold write propagation plus both readback paths.
- `formal/sby/daphne_composable_top_cover.sby` binds
  `formal/vhdl/daphne_composable_top_cover.psl` to the top-level composable
  harness and emits a bounded cover trace showing a live public trigger, a
  concrete propagated frontend lane image, and matching adapted trigger-sample
  bits through the validate stub path.
- `formal/sby/daphne_composable_top_timing_cover.sby` binds
  `formal/vhdl/daphne_composable_top_timing_cover.psl` to the same top-level
  harness and emits a bounded cover trace showing a ready endpoint timing
  image, a repeated public timestamp pattern, and a matching public sync byte.
- `formal/sby/daphne_composable_top_hermes_cover.sby` binds
  `formal/vhdl/daphne_composable_top_hermes_cover.psl` to the same top-level
  harness and emits a bounded cover trace showing a live taken descriptor plus
  the matching public Hermes link/ready/busy status image.
- `formal/sby/daphne_composable_frontend_shell_cover.sby` binds
  `formal/vhdl/daphne_composable_frontend_shell_cover.psl` to the frontend
  shell harness and emits a bounded cover trace showing a live forwarded
  trigger, preserved public lane bits, and matching adapted trigger-sample
  images at the shell seam.
- `formal/sby/frontend_boundary_gate_cover.sby`,
  `formal/sby/trigger_pipeline_boundary_gate_cover.sby`, and
  `formal/sby/spy_buffer_boundary_gate_cover.sby` bind matching PSL cover
  files to the three gate harnesses and emit bounded traces showing each gate
  can actually assert when its documented qualifiers are satisfied.

Properties currently checked:

- Reset drives the architecturally visible AXI-Lite state to documented
  defaults.
- Partial AXI writes do not modify state for modules that require
  `WSTRB = "1111"`.
- Accepted writes produce a matching readable register image where the block
  exposes readback.
- The arithmetic self-trigger register-bank decode preserves the documented
  threshold/counter register map without falling back to a 40-channel linear
  scan.
- The frontend trigger pulse and IDELAY load pulse self-clear after their
  documented stretch intervals.
- Boundary enable outputs are exactly the conjunction of the documented
  readiness and reset qualifiers.
- Boundary enable outputs also have explicit progress checks: once every
  documented qualifier is satisfied, the gate must rise.
- Per-AFE slice boundaries stay invalid/unsafe while taps are loading or while
  local configuration transactions are busy.
- The frontend-to-selftrigger adapter preserves per-AFE channel ordering,
  drops the frame lane, and truncates 16-bit capture samples to the 14-bit
  trigger path exactly as the legacy self-trigger path expects.
- The vendor-neutral delay primitives preserve the same bounded sample-history
  selection contract as the isolated self-trigger wrappers that consume them.
- The timing subsystem boundary stays neutral in local mode, and when endpoint
  timing is selected it exposes a deterministic lock/ready/state/timestamp/sync
  contract that the composable core, frontend shell, and public top now all
  prove they forward directly.
- The Hermes boundary now exposes a deterministic local link/ready/
  backpressure/descriptor-taken contract, and the composable core, frontend
  shell, and public top all prove they forward that live Hermes model when
  Hermes is enabled.
- The public composable top is tied back to the standalone frontend shell
  contract: under the validate-stub frontend image, the public top must expose
  the same frontend, timing, Hermes, and disabled self-trigger outputs as the
  shell proof.
- A dedicated reset-release proof also ties the public composable top back to
  the standalone frontend shell on the analog-control seam: after the scripted
  reset sequence, the AFE/DAC control pins and busy/ready status image must
  match the shell and return to their documented idle state.
- The public composable top also proves that the exposed frontend lane image
  still maps into the flattened 40-channel trigger-sample view exactly as the
  frontend-to-selftrigger adapter contract expects.
- Remaining neutral wrappers that are still stubs are proven to remain input-
  independent and to expose only null/zero-valued outputs.

Modules intentionally left out for now:

- `front_end`, `febit3`, spy-buffer memory path, PDTS timing endpoint, and the
  Hermes transport chain.
- These blocks either rely on Xilinx primitives, large imported subtrees, or
  open environment assumptions that make a useful proof much more expensive than
  the current migration phase can justify.
- The boundary proofs deliberately stop at the wrapper edge; they do not yet
  prove the imported trigger, spy-memory, timing-endpoint, or transport
  implementations themselves.
