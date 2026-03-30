# RTL Isolation Plan

## Intent

Prepare the imported RTL for serious module contracts and formal verification
without destabilizing the currently working K26C Vivado path.

The goal of this phase is not to rewrite the design. The goal is to isolate
subsystem boundaries, make signal ownership explicit, and create a neutral
documentation and wrapper layer on top of the imported source tree.

## Hard constraints

- Keep the current Vivado build path working.
- Keep Hermes transport behavior unchanged.
- Do not redesign the timing endpoint.
- Do not change the existing PS-visible register ABI.
- Remove collaboration- or institute-specific naming from new wrappers,
  documents, and future module names.

## Isolation model

The imported RTL remains the source of truth under `ip_repo/daphne3_ip/`.
The new isolation layer lives under `rtl/isolated/` and expresses the intended
subsystem boundaries with neutral names.

```text
                      +-------------------------+
                      | Board / Software Layer  |
                      | DT / overlay / boot     |
                      | board-owned MAC/IP cfg  |
                      +-----------+-------------+
                                  |
                                  v
    +-------------------------------------------------------------+
    |                         DAPHNE Top                          |
    |                                                             |
    |  +-------------+    +------------------+   +-------------+  |
    |  | Timing      |<-->| Control plane    |<->| Hermes      |  |
    |  | subsystem   |    | regs / decode /  |   | boundary    |  |
    |  | ext clk in  |    | safe responses   |   | 10G stable  |  |
    |  +------+------+    +---------+--------+   +------+------+  |
    |         |                      |                     ^       |
    |         v                      v                     |       |
    |  +-------------+     +------------------+     +-----+----+  |
    |  | Frontend    |---->| Trigger pipeline |---->| Frame /  |  |
    |  | alignment   |     | filters + desc   |     | mux path |  |
    |  +-------------+     +------------------+     +----------+  |
    |                                                             |
    +-------------------------------------------------------------+
```

## Proposed tree

```text
rtl/isolated/
  common/
    daphne_subsystem_pkg.vhd
  subsystems/
    control/
      control_plane_boundary.vhd
    hermes/
      hermes_boundary.vhd
    timing/
      timing_subsystem_boundary.vhd
    trigger/
      trigger_pipeline_boundary.vhd
```

## Why this split

- `control-plane` contains PS-visible register semantics, decode rules, and
  safe access behavior.
- `timing-subsystem` isolates clock, reset, endpoint control, and status
  propagation.
- `trigger-pipeline` becomes the proof-oriented home for thresholding,
  trigger decisions, and descriptor handoff.
- `hermes-boundary` isolates the contract between acquisition/formatting logic
  and the unchanged transport subsystem.

## Verification posture after isolation

- Formal-first:
  - control-plane leaf blocks
  - trigger register banks
  - descriptor formatting and handshake boundaries
- Simulation-first:
  - timing subsystem integration
  - Hermes integration
  - end-to-end frame path behavior

## Immediate tasks on this branch

1. Record the successful build baseline.
2. Add neutral subsystem wrapper shells.
3. Add per-module contract documents.
4. Preserve the legacy/generated Vivado build path untouched.
5. Prepare for future formal harnesses by defining typed internal interfaces.
