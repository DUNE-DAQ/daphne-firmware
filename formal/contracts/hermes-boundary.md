# Contract: Hermes Boundary

## Purpose

Stabilize the interface into the unchanged transport subsystem.

## Assumptions

- Hermes internals are trusted as imported during this phase.
- The board/software layer owns network identity provisioning in later work.
- The isolated proof model may use a small local stall knob instead of pulling
  in the full transport RTL.

## Guarantees

- `link_up` is reset-qualified and descriptor-independent.
- `descriptor_taken` only asserts for a valid, unstalled descriptor.
- `ready` and `backpressure` follow one explicit local handshake contract.
- `transport_busy` reflects live descriptor presence while the link is up.
- No local cleanup in adjacent logic changes transport behavior implicitly.

## Evidence target

- interface assertions
- bounded public-top cover traces for live Hermes handoff reachability
- subsystem simulation
- documentation of what remains outside formal scope
