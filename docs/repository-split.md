# Firmware and OS repository boundary

| Repository | Responsibility |
| --- | --- |
| [daphne-firmware](https://github.com/DUNE-DAQ/daphne-firmware) | HDL, constraints, Vivado/FuseSoC flow, logic/formal verification, XSA/bitstream/DTBO generation |
| [daphne-os](https://github.com/DUNE-DAQ/daphne-os) | PetaLinux, daphne-server and protobuf clients, runtime services, image packaging, board recovery, deployment campaigns |

The boundary is a qualified, checksummed hardware artifact bundle. Firmware
continues to generate XSA, bitstream, normalized DTBO, immutable application
names, and checksum manifests. OS tooling consumes explicit hardware output
paths and preserves the ABI, variant, and build-ID checks. It does not build
HDL or derive an FPGA ID from the OS repository commit.

## Where the OS files moved

`petalinux/`, `scripts/petalinux/`, `scripts/deploy/`, their tests, and the
serial/JTAG/recovery helpers moved to the same paths in `daphne-os`.
`scripts/remote/run_remote_vivado_chain.sh` remains here because it builds HDL.
Hardware packaging tests now live in `tests/package/`.

Use the [OS documentation index](https://github.com/DUNE-DAQ/daphne-os/blob/develop/docs/README.md)
for Linux builds, server compilation, services, QSPI environment setup,
enrollment, and deployment campaigns. The OS root override is `DAPHNE_OS_ROOT`;
`DAPHNE_FIRMWARE_ROOT` continues to mean this hardware repository.

## Historical releases

The split starts from firmware commit
`6d5c49db02286aff07bd6f2208f5e5f71f63af19`. No HDL or hardware build script is
changed by the move. The published `dual-gateware-2026.08.31-rc1` tag remains
at `d7829286480841179fb9569031847c2270a80f04`, with its original files and assets.
Removed OS files remain recoverable from those commits.

Older architecture and release records describe the pre-split combined
repository. Their runtime discussion is historical context, not an instruction
to look for OS scripts in this checkout. The frozen cross-repository release
contract is now maintained with the [OS release records](https://github.com/DUNE-DAQ/daphne-os/tree/develop/docs/releases).
