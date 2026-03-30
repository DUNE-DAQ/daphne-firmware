# Dependency Transition Plan

## Intent

Finish the modularization around the real operational dependency chain without
changing the qualified K26C Vivado path or the imported RTL behavior.

This plan does not redesign Hermes, the timing endpoint, or the PS-visible
register ABI. It makes the dependency ordering explicit so the FuseSoC graph,
module documents, and future formal harnesses match how the design actually has
to come up.

## Dependency order

The correct subsystem order is:

1. `control-plane`
2. `analog-control`
3. `timing-subsystem`
4. `frontend-boundary`
5. `trigger-pipeline`
6. `spy-buffer-boundary`
7. `spy-buffer`
8. `hermes-boundary`

## Why this order

- `control-plane` owns configuration intent and safe decode behavior.
- `analog-control` applies AFE and DAC configuration needed before frontend
  words can be interpreted or aligned reliably.
- `timing-subsystem` provides the clocks and readiness conditions required for
  alignment to make sense.
- `frontend-boundary` can only promote data to "alignment-valid" after both
  analog configuration and timing readiness are true.
- `trigger-pipeline` must not consume frontend data until alignment is valid.
- `spy-buffer-boundary` makes the capture gating explicit without changing the
  imported spy-memory implementation.
- `spy-buffer` may stay separate, but capture must be gated by the same
  readiness contract.
- `hermes-boundary` remains the unchanged transport handoff and should only see
  valid upstream traffic.

## Readiness model

The modular graph should converge on these neutral predicates:

- `config_ready`
  - AFE configuration applied
  - DAC configuration applied where required for operation
- `timing_ready`
  - selected clock source valid
  - MMCM lock path valid
  - endpoint/timestamp status valid when endpoint timing is selected
- `alignment_ready`
  - frontend training pattern found
  - deserialize format and bit order consistent with the contract
  - IDELAY/ISERDES state promoted to valid for downstream consumers

Derived enables:

- `alignment_enable = config_ready and timing_ready`
- `trigger_enable = config_ready and timing_ready and alignment_ready`
- `spy_enable = config_ready and timing_ready and alignment_ready`

## Transition steps

1. Document the dependency chain in module contracts.
2. Add `analog-control`, `spy-buffer-boundary`, and `spy-buffer` to the modular
   architecture as first-class named subsystems.
3. Reflect the dependency ordering in the FuseSoC graph with additive
   boundary/package cores.
4. Introduce typed readiness/status records before changing any imported
   implementation logic.
5. Add assertions and formal harnesses at the control/trigger/boundary layers.
6. Keep the generated legacy K26C build path as the safety rail until the
   modular top is qualified.

## Non-goals in this phase

- No Hermes transport rewrite.
- No timing endpoint redesign.
- No MAC/IP ownership moved into PL.
- No Petalinux or deployment changes as part of this transition.
