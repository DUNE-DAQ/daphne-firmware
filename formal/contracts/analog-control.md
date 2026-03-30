# Analog Control Contract

## Purpose

Document the AFE/DAC configuration boundary so downstream modules can assume a
single readiness signal instead of re-deriving board state.

## Assumptions

- Configuration transactions are serialized by the control plane.
- AFE and DAC configuration are not considered complete until the boundary
  reports readiness.
- This wrapper does not change the imported SPI behavior.

## Guarantees

- `config_ready = 1` means the analog configuration path is stable enough for
  frontend alignment to begin.
- `config_ready = 0` means alignment and trigger enable must remain inhibited.
