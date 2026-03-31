# Formal Contracts

These files define proof scope before proof code exists.

Each module contract should capture:

- clock and reset domains
- interface assumptions
- architecturally visible state
- guarantees after reset
- legal and illegal transactions
- behavior when optional blocks are absent or disabled
- whether the module is a formal target, simulation target, or documentation
  target only

This directory is intentionally documentation-first. Harnesses and assertions
should follow only after the contract is stable.

Current contract set:

- `analog-control`
- `control-plane`
- `frontend-boundary`
- `timing-endpoint`
- `timing-subsystem`
- `trigger-pipeline`
- `spy-buffer`
- `hermes-boundary`
