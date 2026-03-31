# PetaLinux Integration Notes

This repository now tracks the minimum firmware-side deployment contract for the
Petalinux system that hosts `daphne-server`.

Current contents:

- `toolchains/aarch64-petalinux.cmake` for cross-compiling user-space support
  against a Petalinux SDK/sysroot.
- `daphne-server-deps.lock.cmake` copied from the current `daphne-server`
  checkout so the firmware repo records the expected pinned runtime bundle.
- `meta-daphne/` as the first repo-owned scaffold for future DT, firmware,
  userspace, and service packaging ownership.

Still missing before this repo can be considered a full Petalinux deliverable:

- a build-tested integration of `meta-daphne/` into a real KR260 PetaLinux
  project;
- a reproducible boot asset layout (`BOOT.BIN`, image bundle, overlay install
  path, service unit);
- an automated handoff from the firmware build outputs
  (`xilinx/output/*.xsa`, `.bit`, `.dtbo`) to the board image build;
- a validated target rootfs test on a Linux/Petalinux host.

The modular FuseSoC split does not change these deploy-time gaps yet. The
current deployable contract is still anchored on the working K26C Vivado batch
flow plus the documented `daphne-server` runtime dependencies, but the missing
Yocto ownership points now exist as repo-owned scaffolding under
`petalinux/meta-daphne/`.
