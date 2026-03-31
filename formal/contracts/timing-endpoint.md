# Contract: Timing Endpoint

## Purpose

Model the guide-level integration contract around the imported PDTS timing
endpoint without claiming a full proof of the endpoint internals.

## Assumptions

- Clock recovery, SERDES, and endpoint internals remain trusted implementation
  blocks outside this proof boundary.
- `CLOCK_VALID` and `TIMESTAMP_VALID` are environment-visible facts presented
  to the wrapper, not properties proved here about the imported endpoint.
- Command `0` is the only command modeled here as a sync request.

## Guarantees

- `RDY` is asserted only when reset is released, the clock is valid, and the
  timestamp is valid.
- `RST` remains asserted until that readiness condition holds.
- Timestamp output is zeroed until the contract is ready.
- Sync strobe and sync payload are emitted only for command `0` while ready.
- `TX_DISABLE` remains asserted unless the contract is ready and the
  environment explicitly requests transmission.
- `LOS` does not affect any visible contract output.

## Evidence target

- formal for wrapper-level reset, ready, timestamp, sync, and TX-disable rules
- simulation/integration testing for the imported endpoint implementation
