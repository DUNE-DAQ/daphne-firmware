# Formal Contracts

These files define proof scope before proof code exists.

Ownership note:

- the contract inventory and contract-integration workflow in this repo are
  maintained by Manuel Arroyave (FNAL)
- the broader subsystem attribution map lives in `docs/developer-manifest.md`

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
