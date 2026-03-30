# Contract: Timing Subsystem

## Purpose

Bridge timing endpoint control and status into the DAPHNE design without
changing the established timing concepts.

## Assumptions

- External timing input quality is an environment assumption.
- Vendor clocking primitives are trusted black boxes for formal purposes.

## Guarantees

- Control bits map to the documented timing behavior.
- Status reporting is coherent with the control state.
- Timestamp and sync outputs propagate through a documented interface boundary.

## Evidence target

- formal at the AXI/control boundary
- simulation for endpoint lock, reset, and integration behavior
