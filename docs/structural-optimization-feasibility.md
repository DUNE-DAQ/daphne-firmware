# Structural Optimization Feasibility

Branch: `marroyav/structural-opt-feasibility`

Baseline for this study:

- `daphne-firmware` at `origin/main` commit `dac99b8`
- `daphne_mezz_xc_sim` existing optimization study on branch
  `marroyav/deadtime-coalesced-study`

## Scope

This note maps the proposed optimization themes onto the current codebase and
separates:

- high-yield structural work,
- low-risk cleanup that is worth doing anyway,
- and ideas that are sound in general but are not first-order constraints in
  this tree.

The result is intentionally concrete. Every recommendation below points at
current modules, not generic FPGA advice.

## Quick ranking

| Direction | Feasibility | Likely payoff | Primary files |
|---|---|---:|---|
| Dead-time arithmetic instead of state-heavy gating | High | High | `rtl/isolated/subsystems/trigger/stc3_record_builder.vhd` |
| FIFO contract split and consolidation | Medium | High | `rtl/isolated/subsystems/trigger/stc3_record_builder.vhd`, `rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd`, `rtl/isolated/common/primitives/sync_fifo_fwft.vhd` |
| Contract-based interfaces to remove duplicated safety logic | High | Medium | `rtl/isolated/subsystems/trigger/*.vhd`, `formal/contracts/*`, `formal/sby/*` |
| Comparator width reduction / hierarchical decode | High | Low to Medium | `rtl/isolated/subsystems/control/selftrigger_register_bank.vhd`, trigger acceptance comparators |
| Stronger clock-enable discipline | High | Medium for power, Low to Medium for area | `rtl/isolated/common/primitives/fixed_delay_line.vhd`, `ip_repo/daphne_ip/rtl/selftrig/trig_xc.vhd`, `rtl/isolated/subsystems/trigger/stc3_record_builder.vhd` |
| Build-time specialization / FuseSoC flattening | Medium | Medium | `rtl/isolated/tops/daphne_composable_core_top.vhd`, `scripts/fusesoc/build_platform.sh`, board/platform cores |
| Control/data pipeline rebalance | Medium | Medium | `rtl/isolated/subsystems/trigger/stc3_record_builder.vhd`, `rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd` |
| Formal as an optimization enabler | High | Medium | `formal/README.md`, `formal/contracts/*`, `formal/sby/*` |
| Simulation alignment by structural reuse | Medium | Medium to High for iteration speed | `daphne_mezz_xc_sim/src/ring_deadtime_sim.cpp`, future RTL-wrapping harnesses |

## What the current tree is actually doing

### 1. The mainline dead-time path is still state-heavy

Current mainline [`stc3_record_builder.vhd`](../rtl/isolated/subsystems/trigger/stc3_record_builder.vhd) is still the old fixed-frame machine:

- a large FSM encodes packet build progress
- busy is inferred from state
- frame admission is gated by local builder state and FIFO fullness
- sample alignment is implemented through a fixed `288`-cycle delay line

That is the clearest target for your point about replacing state-heavy control
with arithmetic.

This is the first-order opportunity in the tree.

### 2. Buffering is concentrated, not absent

The current self-trigger path is not “FIFO everywhere” in the abstract. It is
more specific:

- each channel has a large output FIFO in
  [`sync_fifo_fwft.vhd`](../rtl/isolated/common/primitives/sync_fifo_fwft.vhd)
- those FIFOs feed a scan/dump mux in
  [`two_lane_readout_mux.vhd`](../rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd)
- the mux is hard-wired to `2` output lanes

That means the real buffering question is not whether FIFOs exist. It is:

- whether per-channel deep FIFOs are the right place to absorb rate variation,
- or whether some of that buffering should move to a lane-local aggregator or
  completed-record queue.

### 3. The composable top already uses real generate-time feature gates

[`daphne_composable_core_top.vhd`](../rtl/isolated/tops/daphne_composable_core_top.vhd) already disables large blocks with:

- `ENABLE_SELFTRIGGER_G`
- `ENABLE_TIMING_G`
- `ENABLE_HERMES_G`

So FuseSoC specialization is not starting from zero. The current issue is more
about:

- narrowing the supported build matrix,
- reducing wrapper duplication,
- and making specialized targets explicit,

not about some giant always-on monolith surviving behind a runtime `if`.

### 4. The simulation model is still architectural, not structural

The current stochastic study in `daphne_mezz_xc_sim` is valuable, but it still
re-implements the architecture in C++:

- [`src/ring_deadtime_sim.cpp`](/Users/marroyav/repo/daphne_mezz_xc_sim/src/ring_deadtime_sim.cpp)

That is good for rapid design-space scans. It is not the same as wrapping RTL.

So your point about simulation alignment is correct. The current model helps us
choose directions, but it does not prevent long-term divergence.

## Feasibility by direction

### 1. Implicit duplication via safe independence

Feasibility: High

Relevant modules:

- [`trigger_control_adapter.vhd`](../rtl/isolated/subsystems/control/trigger_control_adapter.vhd)
- [`afe_subsystem_fabric.vhd`](../rtl/isolated/subsystems/afe/afe_subsystem_fabric.vhd)
- [`afe_selftrigger_island.vhd`](../rtl/isolated/subsystems/trigger/afe_selftrigger_island.vhd)
- [`stc3_record_builder.vhd`](../rtl/isolated/subsystems/trigger/stc3_record_builder.vhd)
- descriptor/trigger wrappers in `rtl/isolated/subsystems/trigger/`

What is real here:

- there are several pass-through wrappers whose job is mostly reshaping arrays
  and preserving local independence
- there are also independently re-established safety conditions between trigger,
  descriptor, builder, and readout stages

The value is not in deleting wrappers blindly. The value is in defining sharper
contracts at a few expensive seams:

- trigger result is already baseline-aligned
- frame admission has already been validated
- trailer capture is valid only under one documented condition

That would allow the builder/descriptor side to stop re-deriving or re-guarding
those assumptions locally.

This direction is realistic because the repo already has formal contract
infrastructure:

- [`formal/README.md`](../formal/README.md)
- [`formal/contracts/`](../formal/contracts)
- [`formal/sby/`](../formal/sby)

### 2. Dead-time logic: convert from stateful to arithmetic

Feasibility: High

Relevant module:

- [`stc3_record_builder.vhd`](../rtl/isolated/subsystems/trigger/stc3_record_builder.vhd)

This is the highest-yield item.

The mainline builder still encodes acceptance as:

- current FSM state
- current block count
- current FIFO fullness
- local busy history

The branch experiments in other worktrees already showed that arithmetic
formulations are viable:

- trigger-to-coverage comparisons
- ring safety as age/distance arithmetic
- packet maturity as timestamp arithmetic

The mainline tree has not absorbed that structure yet.

Recommendation:

- move the self-trigger builder toward an explicit “coverage / ready / backlog”
  arithmetic model
- keep packet formatting separate from admission timing
- use state only for serialization, not for admission policy

This is the direct path to reducing dead time and simplifying timing.

### 3. FIFO overuse: latency hiding turned into area waste

Feasibility: Medium

Relevant modules:

- [`stc3_record_builder.vhd`](../rtl/isolated/subsystems/trigger/stc3_record_builder.vhd)
- [`sync_fifo_fwft.vhd`](../rtl/isolated/common/primitives/sync_fifo_fwft.vhd)
- [`two_lane_readout_mux.vhd`](../rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd)

The self-trigger path currently couples:

- packet creation
- packet buffering
- lane arbitration

through one per-channel FIFO contract.

That is the reason the coalesced non-overlap model only becomes excellent when
the per-channel output-full gate is relaxed in the simulator.

This does not mean “remove FIFOs everywhere.” It means:

- stop using one deep per-channel FIFO as both acceptance gate and transport
  buffer
- consider a shallower per-channel completion queue plus lane-local buffering
- move record admission and record drain into different contracts

This is a larger RTL change than the arithmetic dead-time refactor, but it is
also the next major structural gain after that refactor.

### 4. Comparator width reduction

Feasibility: High

Current low-risk example:

- [`selftrigger_register_bank.vhd`](../rtl/isolated/subsystems/control/selftrigger_register_bank.vhd)

Before this branch, the register bank performed a linear 40-channel address
scan for both reads and writes. That is exactly the kind of quiet wide-compare
waste you highlighted.

This branch prototypes the reduction by changing the bank to:

- decode channel index arithmetically from the address,
- decode local offset once,
- and select data with a short case split.

That does not change functionality, but it reduces repeated equality compares
and long priority chains in the control plane.

The same idea applies more profitably later to:

- trigger acceptance compares in future builder refactors,
- timestamp/coverage comparisons where upper bits can qualify lower bits,
- and any future lane or interval ID matching.

### 5. Clock-enable discipline

Feasibility: High

Relevant modules:

- [`fixed_delay_line.vhd`](../rtl/isolated/common/primitives/fixed_delay_line.vhd)
- [`trig_xc.vhd`](../ip_repo/daphne_ip/rtl/selftrig/trig_xc.vhd)
- [`stc3_record_builder.vhd`](../rtl/isolated/subsystems/trigger/stc3_record_builder.vhd)

The current pattern is still “always shift, always update” in several places:

- fixed delay lines shift every cycle
- pack registers in the builder update every cycle
- latency staging in the trigger path is unconditional

This is not mainly a LUT-count issue. It is:

- avoidable switching,
- extra local enable logic later,
- and unnecessary activity when channels are disabled.

Recommendation:

- push channel enables down to the expensive local pipelines,
- especially around delay lines and staging registers,
- but do it hierarchically rather than recomputing local enables.

This is worth doing, but it is not the first area lever after dead-time and
buffer contracts.

### 6. FuseSoC parameter explosion vs synthesis clarity

Feasibility: Medium

Relevant files:

- [`daphne_composable_core_top.vhd`](../rtl/isolated/tops/daphne_composable_core_top.vhd)
- [`daphne-ip.core`](../daphne-ip.core)
- [`scripts/fusesoc/build_platform.sh`](../scripts/fusesoc/build_platform.sh)

This repo is already better than average here because the top-level feature
gates are genuine elaboration-time generics.

So the main opportunity is not “replace runtime conditionals with constants.”
That is already partly true.

The useful next step is:

- define fewer, more specialized supported targets
- keep self-trigger-only, timing-only, and validation/stub configurations
  explicit at the board/platform level
- reduce the amount of wrapper and report logic that exists only to keep a wide
  matrix alive

This helps clarity and synthesis repeatability, but it is not the top resource
reduction lever today.

### 7. Pipeline control vs data imbalance

Feasibility: Medium

Relevant modules:

- [`stc3_record_builder.vhd`](../rtl/isolated/subsystems/trigger/stc3_record_builder.vhd)
- [`two_lane_readout_mux.vhd`](../rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd)

The current mainline builder is control-heavy relative to the payload path:

- large serialized FSM
- explicit wait states
- separate counter-driven sequencing

That means control is doing more work than data.

If the builder is refactored toward interval arithmetic plus a smaller
serializer, this imbalance mostly improves as a side effect.

So this is a real issue, but it is not an isolated work item. It is best
treated as a design criterion while restructuring the builder and readout path.

### 8. Formal as an optimization enabler

Feasibility: High

Relevant infrastructure:

- [`formal/README.md`](../formal/README.md)
- [`formal/contracts/trigger-pipeline.md`](../formal/contracts/trigger-pipeline.md)
- existing SBY jobs in [`formal/sby/`](../formal/sby)

This repo already has more formal infrastructure than most firmware trees.

The missing step is to use it for optimization, not just interface safety.

The obvious next proofs are:

- builder admission contract
- lane mux one-hot drain contract
- self-trigger register-bank decode equivalence
- “covered trigger does not emit new record” style invariants once the builder
  moves further toward interval arithmetic

This is realistic and should be part of the optimization flow, not deferred to
the end.

### 9. Simulation alignment: structural reuse, not behavioral mirroring

Feasibility: Medium

Current state:

- the stochastic C++ model is useful for architecture ranking
- but it does not exercise the RTL implementation directly

Recommendation:

- keep the stochastic model for large sweeps
- add a small RTL-wrapping harness around:
  - `stc3_record_builder`
  - `two_lane_readout_mux`
  - and eventually a lane-local completion-queue variant
- compare the same acceptance counters and transport counters against the C++
  model

This is not optional if the builder contract changes materially.

## What the simulator already says about transport splitting

The existing study in `daphne_mezz_xc_sim` already answers one of the proposed
questions.

From the sibling simulation repo note
`daphne_mezz_xc_sim/docs/deadtime-optimization-study.md`:

- `4 lanes x 10 channels` is a real but second-order gain for the ring path
- it does not rescue the inherited coalesced output gate

So transport splitting is worth keeping on the roadmap, but it should not be
treated as the main optimization axis.

## Changes made on this branch

### 1. Register-bank comparator cleanup

Updated:

- [`selftrigger_register_bank.vhd`](../rtl/isolated/subsystems/control/selftrigger_register_bank.vhd)

Change:

- replaced linear full-range channel scans on read/write with arithmetic
  channel/offset decode

Reason:

- this is a low-risk example of the “quiet comparator reduction” direction
- it shortens the control-plane decode logic without changing the external
  register map

### 2. Richer implementation reports

Updated:

- [`daphne_vivado_flow.tcl`](../xilinx/daphne_vivado_flow.tcl)

Added nonfatal report generation for:

- `report_design_analysis`
- `report_qor_suggestions`

at post-synth, post-place, and post-route where meaningful.

Reason:

- future optimization passes need more than timing and utilization summaries
- this makes congestion and QoR guidance part of the normal build artifacts

## Recommended implementation order

1. Refactor self-trigger admission from state-heavy gating toward arithmetic
   interval/coverage rules.
2. Split capture admission from per-channel output FIFO fullness.
3. Preserve fixed packet formatting while reworking the admission and drain
   contracts.
4. Use formal contracts to lock the new admission semantics.
5. Re-evaluate lane-local buffering before attempting wider transport changes.
6. Treat `4 lanes` as a follow-on optimization, not the first fix.
7. Keep sweeping the stochastic model, but add an RTL-wrapping harness for the
   builder and lane mux.

## Bottom line

The highest-yield work in this tree is still structural:

- arithmetic dead-time logic,
- decoupled buffering contracts,
- and formalized boundaries that let local re-validation disappear.

The best immediate cleanup work is quieter:

- comparator reduction in decoded control blocks,
- stronger enable discipline,
- and richer QoR reporting.

The repo is already partially prepared for this:

- the composable top uses real generate-time feature gating
- the formal infrastructure exists
- the simulator has already quantified several transport and coalescing tradeoffs

So the next phase should not be another generic cleanup pass. It should be a
targeted builder/readout contract redesign with formal support.
