# Trigger Pipeline

## Scope

Neutral boundary for:

- threshold register banks
- filter and trigger primitives
- trigger descriptor generation
- descriptor handoff toward frame assembly and transport

## Imported sources currently involved

- `rtl/selftrig/`
- frontend-trigger coordination in `rtl/frontend/`

## Isolation objective

Separate control, algorithm, and descriptor handoff concerns so each can be
documented and verified independently.

## Readiness dependency

The trigger pipeline must not be treated as self-starting.

- It depends on the analog-control path having applied the required frontend
  configuration.
- It depends on the timing subsystem having made the selected clocking path
  trustworthy.
- It depends on the frontend boundary having promoted alignment to valid.

The neutral enable rule for this module should be:

- `trigger_enable = config_ready and timing_ready and alignment_ready`

That readiness rule now has a neutral typed home in
`acquisition_readiness_t`, so later proof work can target one boundary-facing
contract instead of re-deriving the gating semantics per module.

The downstream `14-bit` trigger semantics belong here, not in the frontend
alignment contract.

## Later formal targets

- threshold register semantics
- descriptor field invariants
- handshake stability at the descriptor boundary
- gating: no trigger activity while readiness preconditions are false
