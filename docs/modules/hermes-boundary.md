# Hermes Boundary

## Scope

Neutral name for the handoff into the existing Hermes/IPBus/UDP/10G subsystem.

## Important constraint

The transport subsystem remains behaviorally unchanged in this phase.

- no redesign of the 10G path
- no redesign of internal MAC/IP handling
- no protocol changes

## Isolation objective

Document and wrap the acquisition-to-transport boundary so the rest of the
firmware can be cleaned up without perturbing the transport core.

## Current isolated model

The local verification model is intentionally conservative and does not import
the Hermes/IPBus/UDP/10G subsystem.

- `link_up` rises once the local reset is released
- `payload(0)` acts as a local backpressure knob for verification
- `descriptor_taken` only asserts for a valid descriptor when the modeled
  backpressure knob is clear
- `ready` stays high after reset except during the modeled stall case
- `transport_busy` reflects live descriptor presence while the link is up

This gives the composable proofs and smoke benches a deterministic accept path
and a deterministic stall path without claiming that the imported transport
implementation itself has been proven.

## Software ownership note

Board-specific MAC/IP defaults should be treated as platform/software-owned
configuration in later work, not as a reason to refactor the Hermes datapath.
