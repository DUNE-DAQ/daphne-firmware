# Build Baseline

This branch starts from a known-good K26C hardware build baseline.

## Qualified baseline

- Build-recovery branch for the successful WSL/Windows Vivado flow:
  `marroyav/build`
- Recovery commit used to regain end-to-end build control:
  `88cd864`
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

The work on `marroyav/fusesoc-backports` stays additive relative to that
recovery lane:

- do not break the existing K26C Vivado build path;
- do not rewrite Hermes transport behavior;
- do not change MAC/IP handling semantics inside the Hermes block;
- do not change the existing PS-visible register ABI while introducing cleaner
  subsystem boundaries.
