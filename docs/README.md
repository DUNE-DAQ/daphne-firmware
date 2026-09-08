# Documentation guide

Start with the document that matches the job you are doing.

## Operating and deployment

- `build-manual.md`: build the FPGA artifacts.
- `releases/selftrigger-2026.08.24-rc2.md`: current source-candidate status and
  release gates.
- [daphne-os documentation](https://github.com/DUNE-DAQ/daphne-os/blob/develop/docs/README.md):
  Linux images, server development, services, board enrollment, campaigns,
  recovery, and station power control.
- [Repository boundary](repository-split.md): artifact handoff and migration.

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
- [PL-I2C incident record](https://github.com/DUNE-DAQ/daphne-os/blob/develop/docs/pl-i2c-binding-blocker.md):
  resolved 2026 device-tree incident.

In build documentation, *hardware handoff* means the `.xsa` interface passed
from Vivado to PetaLinux. That is current AMD terminology and is unrelated to
the deprecated agent handoff notes.
