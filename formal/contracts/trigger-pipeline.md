# Contract: Trigger Pipeline

## Purpose

Define the boundary from configured thresholds and trigger logic to descriptor
generation and frame handoff.

## Assumptions

- Sample streams obey the documented timing and validity rules.
- Upstream control writes use the documented register contract.

## Guarantees

- Threshold state is stable and readable after accepted writes.
- Descriptor fields satisfy documented width and reset invariants.
- Descriptor handoff obeys the selected handshake contract.

## Evidence target

- formal for threshold/config blocks and descriptor formatting when isolated
- simulation for algorithmic trigger behavior and integration
