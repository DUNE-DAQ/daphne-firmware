# PetaLinux Integration Notes

This repository now tracks the minimum firmware-side deployment contract for the
Petalinux system that hosts `daphne-server`.

Current contents:

- `toolchains/aarch64-petalinux.cmake` for cross-compiling user-space support
  against a Petalinux SDK/sysroot.
- `daphne-server-deps.lock.cmake` copied from the current `daphne-server`
  checkout so the firmware repo records the expected pinned runtime bundle.

Still missing before this repo can be considered a full Petalinux deliverable:

- a Yocto/Petalinux recipe or meta-layer to install the FPGA image, `.dtbo`,
  and `daphne-server` binaries together;
- a reproducible boot asset layout (`BOOT.BIN`, image bundle, overlay install
  path, service unit);
- an automated handoff from `xilinx/output/*.xsa` to the board image build;
- a validated target rootfs test on a Linux/Petalinux host.
