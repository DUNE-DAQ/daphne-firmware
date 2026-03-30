# Hermes Boundary

## Scope

Neutral name for the handoff into the existing Hermes/IPBus/UDP/10G subsystem.

## Important constraint

The transport subsystem remains behaviorally unchanged in this phase.

- no redesign of the 10G path
- no redesign of internal MAC/IP handling
- no protocol changes

## Isolation objective

Document and eventually wrap the acquisition-to-transport boundary so the rest
of the firmware can be cleaned up without perturbing the transport core.

## Software ownership note

Board-specific MAC/IP defaults should be treated as platform/software-owned
configuration in later work, not as a reason to refactor the Hermes datapath.
