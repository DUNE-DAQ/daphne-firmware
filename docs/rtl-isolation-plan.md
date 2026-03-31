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

The imported RTL remains the source of truth under `ip_repo/daphne_ip/`.
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
    |  +-------------+   +------------------+   +-------------+  |
    |  | Control     |-->| Analog control   |-->| Timing      |  |
    |  | plane       |   | AFE + DAC cfg    |   | subsystem   |  |
    |  | regs / safe |   | cfg_ready        |   | ext clk in  |  |
    |  +------+------+   +---------+--------+   +------+------+  |
    |         |                     |                     |       |
    |         v                     v                     v       |
    |  +-------------+     +------------------+     +----------+  |
    |  | Frontend    |---->| Trigger pipeline |---->| Hermes   |  |
    |  | boundary    |     | filters + desc   |     | boundary |  |
    |  | 16b / LSB   |     | 14b semantics    |     | 10G hand |  |
    |  +------+------+     +---------+--------+     +----------+  |
    |         |                      |                              |
    |         +--------------------->|                              |
    |                                v                              |
    |                          +-----------+                        |
    |                          | Spy       |                        |
    |                          | boundary  |                        |
    |                          | + memory  |                        |
    |                          +-----------+                        |
    |                                                             |
    +-------------------------------------------------------------+
```

## Proposed tree

```text
cores/common/
  daphne-subsystem-types.core
cores/features/
  analog-control.core
  control-plane.core
  frontend-boundary.core
  hermes-boundary.core
  spy-buffer-boundary.core
  timing-subsystem.core
  trigger-pipeline.core
  daphne-modular.core
rtl/isolated/
  common/
    daphne_subsystem_pkg.vhd
  subsystems/
    control/
      control_plane_boundary.vhd
    frontend/
      frontend_boundary.vhd
    hermes/
      hermes_boundary.vhd
    spy/
      spy_buffer_boundary.vhd
    timing/
      timing_subsystem_boundary.vhd
    trigger/
      trigger_pipeline_boundary.vhd
```

## Why this split

- `control-plane` contains PS-visible register semantics, decode rules, and
  safe access behavior.
- `analog-control` contains the explicit AFE/DAC configuration readiness
  boundary that must settle before alignment starts.
- `frontend-boundary` captures the alignment/configuration preconditions that
  must be satisfied before AFE data are considered valid for downstream logic.
  It depends on both analog configuration and timing readiness.
- `timing-subsystem` isolates clock, reset, endpoint control, and status
  propagation, and must be ready before alignment starts.
- `trigger-pipeline` becomes the proof-oriented home for thresholding,
  trigger decisions, and descriptor handoff after alignment is valid.
- `spy-buffer-boundary` keeps capture gating explicit and separate from the
  imported debug-memory implementation.
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
6. Reflect the subsystem boundaries directly in the FuseSoC graph before
   rewiring any imported implementation logic.
