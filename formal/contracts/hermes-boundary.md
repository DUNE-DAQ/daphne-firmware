# Contract: Hermes Boundary

## Purpose

Stabilize the interface into the unchanged transport subsystem.

## Assumptions

- Hermes internals are trusted as imported during this phase.
- The board/software layer owns network identity provisioning in later work.

## Guarantees

- The boundary preserves frame handoff ordering and handshake semantics.
- No local cleanup in adjacent logic changes transport behavior implicitly.

## Evidence target

- interface assertions
- subsystem simulation
- documentation of what remains outside formal scope
