# Contract: Control Plane

## Purpose

Provide a stable, safe PS-visible control surface for the firmware.

## Assumptions

- AXI-Lite transactions are synchronous to the control clock.
- Reset is asserted long enough to initialize all visible state.

## Guarantees

- Registers reset to documented defaults.
- Unsupported addresses return a defined safe response.
- Partial writes are either rejected or handled exactly as documented.
- Readback is consistent with accepted writes.

## Evidence target

- formal for leaf register blocks
- simulation for integrated decode/aggregation paths
