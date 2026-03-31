# Contract: Timing Subsystem

## Purpose

Bridge timing endpoint control and status into the DAPHNE design without
changing the established timing concepts.

## Assumptions

- External timing input quality is an environment assumption.
- Vendor clocking primitives are trusted black boxes for formal purposes.
- Downstream modules must not consume endpoint-derived behavior as valid unless
  the timing status contract says the subsystem is ready.

## Guarantees

- Control bits map to the documented timing behavior.
- Status reporting is coherent with the control state.
- Timestamp and sync outputs propagate through a documented interface boundary.
- Readiness is not reduced to a single raw signal; it is the conjunction of the
  selected clock source, lock state, endpoint-ready state, and timestamp-valid
  state.

## Operational constraints to preserve

- `CLOCK_SOURCE=endpoint` is a mode switch, not a proof of valid timing.
- `MMCM0_LOCKED` and `MMCM1_LOCKED` are required before trusting derived clocks.
- Endpoint FSM ready and `TIMESTAMP_OK` are required before trusting timing
  status as fully operational.
- Local-clock mode is permitted, but it carries different timestamp semantics
  and must not be confused with endpoint-synchronized operation.

### Timing endpoint contract focus

- `RST` must remain asserted during startup until clock validity is established.
- `RDY` gates the validity of timestamp and sync outputs.
- Command `0` is the only command assumed to request sync generation.
- `TX_DISABLE` stays asserted unless the endpoint is ready and the environment
  explicitly requests transmission.
- `LOS` is an observation/debug input and must not affect the visible contract
  outputs.

## Evidence target

- formal at the AXI/control boundary
- simulation for endpoint lock, reset, and integration behavior
