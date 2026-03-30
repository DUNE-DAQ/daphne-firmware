# Contract: Frontend Boundary

## Purpose

Capture the alignment and format assumptions that must hold before frontend
samples are considered valid for downstream use.

## Assumptions

- The AFE is configured for `16-bit`, `LSb-first` transmission.
- The frontend clock trio is frequency-locked and edge-aligned.
- IDELAY programming occurs only while `idelay_en_vtc = 0`.

## Guarantees

- The control-plane-visible alignment state reflects whether the frontend is
  ready to be trusted.
- Downstream logic can distinguish "configured" from merely "wired".
- Training-pattern validation is tied to the documented 16-bit FCLK contract.

## Evidence target

- documentation now
- simulation and assertions on alignment gating later
