# Build Baseline

This branch starts from a known-good K26C hardware build baseline.

## Qualified baseline

- Branch before isolation work: `codex/fusesoc-modular-migration`
- Baseline commit for the successful WSL/Windows Vivado flow:
  `16dfe53`
- Vivado/Vitis environment used for qualification:
  - Vivado 2024.1 on Windows
  - Vitis 2024.1 on Windows
  - WSL2 shell driving the batch flow

## Confirmed outputs

The successful hardware run produced the standard PL handoff objects:

- `.bit`
- `.bin`
- `.xsa`
- implementation reports

Those artifacts were generated on the WSL host, not in this local macOS
workspace.

## Isolation-phase rule

The work on `codex/rtl-isolation-formal-prep` is additive and preparatory:

- do not break the existing K26C Vivado build path;
- do not rewrite Hermes transport behavior;
- do not change MAC/IP handling semantics inside the Hermes block;
- do not change the existing PS-visible register ABI while introducing cleaner
  subsystem boundaries.
