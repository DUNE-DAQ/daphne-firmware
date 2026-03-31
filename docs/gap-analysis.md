# Gap Analysis

## Implemented in this bootstrap

- Fresh `daphne-firmware` git repository created and connected to the empty
  GitHub remote.
- Current imported non-project Vivado tree used as the baseline.
- Board-dependent Tcl settings parameterized.
- Initial board metadata added.
- FuseSoC HDL smoke tests added for the frontend trigger path, threshold
  window, and PL-side board-control register bank.
- Reusable FuseSoC module cores added for common, feature, and platform
  layers.
- Formal verification harnesses added for AXI-Lite leaf modules and isolated
  subsystem contracts.
- Petalinux/dependency notes added for `daphne-server` compatibility.
- WSL2-driven Windows Vivado/Vitis flow qualified for the current K26C
  hardware build path, with generated `.bit`, `.bin`, and `.xsa` artifacts.
- Additive RTL isolation scaffolding started under `rtl/isolated/` to prepare
  subsystem contracts without disturbing the imported source tree.

## Still missing

- Full FuseSoC-native Vivado ownership for the complete design.
  Reason: the repo now has a top-level FuseSoC `impl` entry point for the
  qualified K26C batch flow, but the actual implementation still runs through
  the legacy `vivado_batch.tcl` path and the artifact/export packaging remains
  outside the FuseSoC target.

- Fully local tool execution in this macOS workspace.
  Local FuseSoC/GHDL smoke tests run here, but the qualified Vivado build path
  currently lives on the WSL2 host with Windows-installed Xilinx tools.

- Full subsystem proofs beyond the current contract layer.
  The repo now carries checked formal harnesses for the isolated wrappers and
  AXI-Lite leaf blocks, but the imported frontend, timing endpoint, spy-memory,
  and Hermes internals still sit outside formal scope.

- Carrier support beyond the imported K26C baseline.
  The repo has a board abstraction point now, but `kr260` is only a scaffold
  until the real pin map, board preset, and overlay validation exist.

- Petalinux packaging.
  There is no Yocto layer, no systemd/service setup, no boot-image recipe, and
  no automated installation path for bitstream + dtbo + `daphne-server`.

- End-to-end deployment test.
  A generated bitstream and `.xsa` now exist from the new repo flow, but there
  is still no qualified `.dtbo`, boot image, or server-on-target validation.

- Full bootable firmware packaging.
  The repo can be driven to a stable overlay-bundle step, but it still does not
  produce the full golden-style boot package with `BOOT.BIN`, kernel,
  `system.dtb`, rootfs image, and QSPI/eMMC staging artifacts.

- Reliable Linux binding of the PL AXI I2C control path after overlay load.
  This is now the highest-priority firmware integration blocker. The current
  March 31, 2026 board validation at firmware commit `7f032ac` showed that the
  PL app loads, but the expected Linux-visible PL I2C bus does not reappear on
  target, which prevents clock-chip control and blocks the service bring-up
  chain. See `docs/pl-i2c-binding-blocker.md`.

- Linux/C++ dependency bundling inside this repo.
  The lockfile is mirrored, but the actual dependency tarball and deployment
  scripts still live with `daphne-server`.

## Recommended next steps

1. Preserve the successful K26C hardware build as the pre-isolation baseline.
2. Add neutral subsystem contracts and wrappers under `rtl/isolated/`.
3. Extend the current contract-level proofs deeper into the imported frontend,
   timing, spy-buffer, and Hermes implementations where the environment can be
   bounded cleanly enough to justify the effort.
4. Decide how device-tree and board-owned MAC/IP provisioning are generated
   from the PetaLinux side without refactoring Hermes transport behavior.
5. Add a repo-local post-build overlay packaging step from `.xsa` to `.dtbo`
   and qualify it against the known-good golden DTB.
6. Fix the PL I2C Linux binding regression so the loaded overlay restores the
   clock-chip control path on target and the server/service stack can use it
   again.
7. Add a PetaLinux-native deploy bundle flow that consumes the generated
   firmware outputs and co-installs `daphne-server`.
