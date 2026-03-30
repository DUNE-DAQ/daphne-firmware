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

## Later formal targets

- threshold register semantics
- descriptor field invariants
- handshake stability at the descriptor boundary
