# Firmware Delivery

## Current deliverable boundary

The repository can now produce and validate a stable post-build firmware
artifact set for the qualified K26C path:

- `.bit`
- `.bin`
- `.xsa`
- `.dtbo`
- overlay bundle zip

This is a real deployable overlay-style firmware package.

It is **not yet** the full bootable firmware image set.

## Why this matters

The repo now owns the hardware handoff and overlay bundle contract end to end:

- implementation reports
- `.bit`
- `.bin`
- `.xsa`
- `.dtbo`
- overlay bundle zip

That boundary has already been exercised on target through:

- overlay load
- clock-client bring-up
- `daphne-server`
- oscilloscope-mode signal visibility

For the Flow API implementation paths on
`dune-daq:daphne:k26c-composable-platform:0.1.0`, there is now an explicit
handoff step before DTBO packaging:

```bash
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output-$DAPHNE_GIT_SHA
```

For the supported default `impl` lane on
`dune-daq:daphne:k26c-composable-platform:0.1.0`, the post-build
export hook already emits the legacy-style
`daphne_selftrigger_<gitsha>.bit/.bin/.xsa` contract into
`xilinx/output-$DAPHNE_GIT_SHA/`, so only the DTBO bundler is required. If you
need to re-export a Flow API implementation handoff from the work directory,
use:

```bash
./scripts/package/export_impl_bundle.sh
```

## Current repo-local packaging step

After a successful Vivado run, once `xilinx/output-$DAPHNE_GIT_SHA/` contains:

- `daphne_selftrigger_<gitsha>.xsa`
- `daphne_selftrigger_<gitsha>.bin`

run:

```bash
./scripts/package/complete_dtbo_bundle.sh
```

If `DAPHNE_GIT_SHA` is set, that now defaults to
`./xilinx/output-$DAPHNE_GIT_SHA/` so the supported Flow-API export path can be
packaged without an extra argument.

or explicitly:

```bash
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output-$DAPHNE_GIT_SHA
```

Expected tools on `PATH`:

- `xsct`
- `dtc`
- `zip`
- `sha256sum`

On Windows hosts where the implementation already completed under `C:\w\d`
but the separate WSL-only packaging step is still brittle, use the repo-owned
PowerShell wrapper:

```powershell
cd C:\w\d
.\scripts\windows\package_dtbo_from_existing_xsa.ps1 -GitSha 176ee43
```

That script bootstraps `pl.dtsi` with Windows `xsct.bat` and then hands the
rest of the bundle generation back to the normal WSL packaging script.

Expected outputs:

- `xilinx/output-$DAPHNE_GIT_SHA/daphne_selftrigger_<gitsha>.dtbo`
- `xilinx/output-$DAPHNE_GIT_SHA/daphne_selftrigger_ol_<gitsha>/`
- `xilinx/output-$DAPHNE_GIT_SHA/daphne_selftrigger_ol_<gitsha>.zip`
- `xilinx/output-$DAPHNE_GIT_SHA/SHA256SUMS`

## Current validated baseline

The current working reference line is:

- routed-clean hardware commit: `a389fcd`
- repo `main` tip carrying the DTBO packaging fixes: `eb5f971`

That line has been validated on hardware:

- overlay loads on target
- the clock-service/client path works
- `daphne-server` runs
- oscilloscope mode sees signals

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
- a fully qualified repo-owned boot flow on target from those outputs

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

Treat the stable overlay bundle as complete, then build outward toward the
golden-package shape:

1. stage the generated overlay bundle into the PetaLinux project through
   `scripts/petalinux/stage_overlay_into_project.sh`
2. build and collect the image into `petalinux/output/<project-name>/` through
   `scripts/petalinux/build_kr260_image.sh`
3. define the board-owned DT inputs for MAC/IP defaults and optional IP
4. replace placeholder userspace/service recipes with real packages
5. validate the resulting image bundle against the known-good golden image
