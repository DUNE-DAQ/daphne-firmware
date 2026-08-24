# Documentation guide

Start with the document that matches the job you are doing.

## Operating and deployment

- `build-manual.md`: build the FPGA artifacts.
- `kr260-petalinux-build-guide.md`: build the Linux image and collect a
  deployment bundle.
- `daphne-board-enrollment-runbook.md`: enroll and identify a board safely.
- `kria-board-identity-and-production-deployment.md`: identity and deployment
  policy.
- `200-board-firmware-deployment-handover.md`: current multi-board campaign
  plan. The filename is historical; this is a plan, not an agent-session
  handoff.
- `kontron-wiener-power-control.md`: operate supported power equipment.

## Firmware development

- `project-overview.md`: scope and architecture philosophy.
- `architecture-reference.md`: diagrams and module boundaries.
- `verification-status.md`: current smoke and formal coverage.
- `developer-manifest.md`: source provenance and ownership.

## Historical or deprecated notes

These filenames remain as short notices so old links fail safely:

- `agent-handoff.md`
- `wsl-agent-summary.md`
- `gap-analysis.md`

Do not use those files to determine current capabilities. Git history remains
the source for the old session details.

The following are labeled historical records and remain useful for regression
or recovery context:

- `build-baseline.md`: Vivado 2024.1 regression baseline.
- `synthesis-timing-review.md`: Vivado 2024.1 synthesis review.
- `pl-i2c-binding-blocker.md`: resolved 2026 PL-I2C incident record.

In build documentation, *hardware handoff* means the `.xsa` interface passed
from Vivado to PetaLinux. That is current AMD terminology and is unrelated to
the deprecated agent handoff notes.
