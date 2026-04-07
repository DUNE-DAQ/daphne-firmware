# Firmware Delivery

## Current deliverable boundary

The repository can now be driven toward a stable post-build firmware artifact
set for the qualified K26C path:

- `.bit`
- `.bin`
- `.xsa`
- `.dtbo`
- overlay bundle zip

This is **not yet** the full bootable firmware image set.

## Why this matters

The build flow already reaches:

- implementation reports,
- `.bit`,
- `.bin`,
- `.xsa`,

but a stable repo-local step is still needed to finish the device-tree overlay
packaging outside the main Vivado build.

For the new `impl_legacy_flow` path on
`dune-daq:daphne:k26c-composable-platform:0.1.0`, there is now an explicit
handoff step before DTBO packaging:

```bash
./scripts/package/export_impl_legacy_flow_bundle.sh
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output-$DAPHNE_GIT_SHA
```

The exporter opens the Flow API Vivado project, reuses the completed `impl_1`
run, and emits the same legacy-style `daphne_selftrigger_<gitsha>.bit/.bin/.xsa`
contract expected by the DTBO bundler.

## Current repo-local packaging step

After a successful Vivado run, once `xilinx/output/` contains:

- `daphne_selftrigger_<gitsha>.xsa`
- `daphne_selftrigger_<gitsha>.bin`

run:

```bash
./scripts/package/complete_dtbo_bundle.sh
```

or explicitly:

```bash
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output
```

Expected tools on `PATH`:

- `xsct`
- `dtc`
- `zip`
- `sha256sum`

Expected outputs:

- `xilinx/output/daphne_selftrigger_<gitsha>.dtbo`
- `xilinx/output/daphne_selftrigger_ol_<gitsha>/`
- `xilinx/output/daphne_selftrigger_ol_<gitsha>.zip`
- `xilinx/output/SHA256SUMS`

## Current highest-priority blocker

A successful overlay package is not yet sufficient for target deployment.

The March 31, 2026 board validation of firmware commit `7f032ac` showed that
the overlay loads through `xmutil`, but the expected Linux-visible PL I2C path
for the clock generator does not reappear on target. That blocks the clock-chip
bring-up path used by `daphne-server` and therefore blocks endpoint/service
validation.

Treat PL I2C recovery after overlay load as the first firmware-delivery
acceptance criterion. Details and target-side evidence live in
`docs/pl-i2c-binding-blocker.md`.

## What the known-good golden bundle tells us

The validated package under `~/golden/daphne14-2026-03-12/` is a **full boot
image bundle**, not just an overlay zip. It includes:

- `boot/BOOT.BIN`
- `boot/Image`
- `boot/boot.scr`
- `boot/system.dtb`
- `boot/system-zynqmp-sck-kr-g-revB.dtb`
- `boot/running-fdt.dtb`
- rootfs image payloads
- QSPI image dumps

That means the long-term stable-firmware goal is larger than the current
overlay deliverable.

## Device-tree ownership and network configuration

The golden `system.dtb` shows that PS-side Ethernet identity and mode already
live in the device tree:

- `ethernet@ff0b0000`
  - `phy-mode = "sgmii"`
  - `mac-address`
  - `local-mac-address`
  - `fixed-link`
- `ethernet@ff0c0000`
  - `phy-mode = "rgmii-id"`

This reinforces the intended ownership boundary:

- do **not** move board MAC/IP ownership into PL refactors;
- keep Hermes transport behavior unchanged;
- standardize board identity at the device-tree / platform-software layer.

## What is still missing for a full stable firmware package

The repo still does **not** yet generate:

- `BOOT.BIN`
- `Image`
- full `system.dtb`
- boot scripts
- rootfs image payloads
- QSPI or eMMC staging images

That work belongs to the next packaging phase around PetaLinux and boot-image
assembly, which now has a terminal-driven wrapper in
`scripts/petalinux/build_kr260_image.sh`.

The first repo-owned scaffold for that phase now lives under
`petalinux/meta-daphne/`, and the current project wrappers live at:

- `scripts/petalinux/bootstrap_kr260_project.sh`
- `scripts/petalinux/init_kr260_project.sh`
- `scripts/petalinux/build_kr260_image.sh`
- `scripts/petalinux/collect_project_artifacts.sh`

## Recommended next milestone

Treat the stable overlay bundle as the immediate firmware artifact milestone,
then build outward toward the golden-package shape:

1. qualify `.dtbo` generation from the repo build,
2. compare the resulting DT outputs against the known-good golden DTB,
3. stage the generated overlay bundle into the PetaLinux project through
   `scripts/petalinux/stage_overlay_into_project.sh`,
4. build and collect the image into `petalinux/output/<project-name>/` through
   `scripts/petalinux/build_kr260_image.sh`,
5. define the board-owned DT inputs for MAC/IP defaults and optional IP,
6. replace placeholder userspace/service recipes with real packages,
7. validate the resulting bundle against the known-good golden image.
