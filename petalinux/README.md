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
- `config/kr260/` and `scripts/petalinux/bootstrap_kr260_project.sh` for
  attaching that layer to an initialized KR260 PetaLinux project.
- `scripts/petalinux/init_kr260_project.sh` for terminal-driven project
  creation/import plus hardware-handoff application.

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

## Current bootstrap point

For a full terminal-driven setup from a hardware handoff directory:

```bash
./scripts/petalinux/init_kr260_project.sh \
  /path/to/petalinux-project \
  /path/to/hw-handoff-dir \
  --output-dir ./xilinx/output
```

That wrapper:

- creates the project if needed,
- runs `petalinux-config --get-hw-description`,
- attaches `meta-daphne`,
- optionally stages the generated overlay artifacts.

If you already have an initialized project and only want to attach the layer,
use the lower-level bootstrap script:

To attach the repo-owned layer to an existing PetaLinux project:

```bash
./scripts/petalinux/bootstrap_kr260_project.sh /path/to/petalinux-project
```

That step does not create the project for you and does not yet produce a full
bootable image. It only makes the DAPHNE layer, DT append points, and package
set visible to the project in a reproducible way.

## Current firmware staging point

After the hardware build has produced the overlay bundle in `xilinx/output/`:

```bash
./scripts/petalinux/stage_overlay_into_project.sh /path/to/petalinux-project
```

That copies the latest generated overlay payload into:

```text
project-spec/meta-daphne/recipes-firmware/daphne-overlay/files/staged/
```

so the `daphne-overlay` recipe has a repo-owned place to install the qualified
firmware artifacts from.
