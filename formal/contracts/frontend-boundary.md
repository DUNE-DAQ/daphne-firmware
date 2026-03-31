# Contract: Frontend Boundary

## Purpose

Capture the alignment and format assumptions that must hold before frontend
samples are considered valid for downstream use.

## Assumptions

- The AFE is configured for `16-bit`, `LSb-first` transmission.
- The frontend clock trio is frequency-locked and edge-aligned.
- IDELAY programming occurs only while `idelay_en_vtc = 0`.
- Software/frontend defaults must be checked against this requirement at the
  register-writing level, not inferred only from boolean field names.

## Guarantees

- The control-plane-visible alignment state reflects whether the frontend is
  ready to be trusted.
- Downstream logic can distinguish "configured" from merely "wired".
- Training-pattern validation is tied to the documented 16-bit FCLK contract.
- `alignment_valid` must not assert unless:
  - configuration is ready
  - timing is ready
  - `idelayctrl_ready = 1`
  - format and training checks are both good
  - delay-control and SERDES resets are deasserted

## Evidence target

- boundary-level formal on the `alignment_valid` gate now
- simulation and deeper assertions on the imported alignment path later
