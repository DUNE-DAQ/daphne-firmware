# DAPHNE KR260 PetaLinux Build Guide

This guide turns the older screenshot-based bring-up notes into a repo-owned
written procedure for building and staging a DAPHNE PetaLinux image from
`daphne-firmware`.

It is based on the older `DAPHNE SYSTEM DEV (1).docx` flow, but updated to
match the current repo state and the May 9, 2026 bring-up findings on
`NP04-DAPHNE-015`.

## Scope and current status

Current baseline:

- board family: KR260 / ZynqMP
- PetaLinux release: `2024.1`
- Yocto codename: `langdale`
- current repo-owned board inventory:
  - `petalinux/meta-daphne/recipes-core/daphne-board-config/files/ff0b_board_inventory.csv`

Important current status:

- the repo now owns real overlay, service, board-config, and runtime packaging
  paths; `meta-daphne` is no longer only empty scaffolding
- `015` is proven with:
  - repo-built `Image`
  - repo-built `system.dtb`
  - repo-built `rootfs.ext4`
  - repo-built tiny switch-root ramdisk
  - full repo-owned runtime service chain
- board-stamped images now also carry first-step U-Boot ownership artifacts:
  - `/etc/daphne-uboot.env`
  - `/etc/fw_env.config`
- the original repo-built DTB failure on `015` has been traced and fixed by
  removing the generated base `pl-bus` from the non-overlay DT
- that fixed repo-owned DTB is now also proven in the persistent default boot
  path on `015`, together with the repo-built `Image`
- the shared DAPHNE DT now makes `gem0` explicitly boot as the management
  `sgmii` fixed-link, following the proven `daphne-14` contract
- the remaining boot gap is narrower:
  - move from the current single-slot boot/update flow to the intended A/B
    eMMC plus QSPI rescue model
  - qualify BOOT.BIN/U-Boot ownership and rollback policy on top of this now
    working repo-built kernel/DT/rootfs path

So this is now a real bring-up and deployment guide, but not yet the final
fleet-grade remote-update guide. The longer-term boot contract is documented
separately in:

- `docs/remote-boot-deployment-plan.md`

## Host requirements

Use a Linux-capable build host for the real PetaLinux build.

Required tools:

```bash
petalinux-create
petalinux-config
petalinux-build
petalinux-package
xsct
dtc
zip
sha256sum
```

On this workspace, the active PetaLinux settings file is:

```bash
source /opt/Xilinx/PetaLinux/2024.1/tools/settings.sh
```

Keep the checkout path short. Recommended:

```text
/mnt/c/w/d
~/w/d
```

## 1. Build the firmware handoff

Start from `daphne-firmware`.

```bash
cd /path/to/daphne-firmware

export DAPHNE_BOARD=k26c
export DAPHNE_ETH_MODE=create_ip
export DAPHNE_GIT_SHA="$(git rev-parse --short=7 HEAD)"
export DAPHNE_OUTPUT_DIR="./output-$DAPHNE_GIT_SHA"

./scripts/fusesoc/run_vivado_batch.sh
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output-$DAPHNE_GIT_SHA
```

Expected products:

```text
xilinx/output-<gitsha>/
  daphne_selftrigger_<gitsha>.bit
  daphne_selftrigger_<gitsha>.bin
  daphne_selftrigger_<gitsha>.xsa
  daphne_selftrigger_<gitsha>.dtbo
  daphne_selftrigger_ol_<gitsha>/
  daphne_selftrigger_ol_<gitsha>.zip
  SHA256SUMS
```

If implementation finished but DT overlay packaging did not:

```bash
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output-$DAPHNE_GIT_SHA
```

## 2. Vivado PS sanity checks

If you regenerate or edit the block design, confirm the PS-side settings
before exporting hardware. Legacy notes still broadly match the intended KR260
shape:

- GEM0 enabled for management
  - explicitly `sgmii` on the PS GT path with a `fixed-link`
- SD0 / eMMC enabled
- UART1 on MIO 36..37
- I2C1 on MIO 24..25

The current source of truth is the generated `.xsa` plus the repo-owned build
scripts, not the old screenshots.

## 3. Create or reuse the PetaLinux project

Preferred wrapper:

```bash
cd /path/to/daphne-firmware

export DAPHNE_GIT_SHA="$(git rev-parse --short=7 HEAD)"
PROJECT_DIR=/path/to/daphne-petalinux
HW_HANDOFF_DIR="$PWD/xilinx/output-$DAPHNE_GIT_SHA"

./scripts/petalinux/init_kr260_project.sh \
  "$PROJECT_DIR" \
  "$HW_HANDOFF_DIR" \
  --output-dir "$HW_HANDOFF_DIR"
```

This wrapper:

- creates the project if needed
- runs `petalinux-config --get-hw-description`
- attaches `petalinux/meta-daphne`
- stages overlay payload
- applies the repo-owned image profile and board-config hooks

If you already have a project and only need to attach the repo-owned layer:

```bash
./scripts/petalinux/bootstrap_kr260_project.sh "$PROJECT_DIR"
./scripts/petalinux/stage_overlay_into_project.sh "$PROJECT_DIR" "$HW_HANDOFF_DIR"
```

If you also have a harvested runtime bundle:

```bash
./scripts/petalinux/stage_runtime_into_project.sh \
  "$PROJECT_DIR" \
  /path/to/daphne-server-runtime-minimal.tgz
```

## 4. Manual equivalent of the older screenshot flow

Use the wrappers above unless you are debugging PetaLinux directly.

Create the project:

```bash
petalinux-create project -t zynqMP -n daphne-petalinux
cd daphne-petalinux
petalinux-config --get-hw-description /path/to/handoff-dir
```

Then configure U-Boot if needed:

```bash
petalinux-config -c u-boot
```

Build:

```bash
petalinux-build -c u-boot
petalinux-build
petalinux-package --boot --u-boot --force
```

## 5. Preferred full build wrapper

Use the repo-owned wrapper for the full image path:

```bash
cd /path/to/daphne-firmware

export DAPHNE_GIT_SHA="$(git rev-parse --short=7 HEAD)"
PROJECT_DIR=/path/to/daphne-petalinux
HW_HANDOFF_DIR="$PWD/xilinx/output-$DAPHNE_GIT_SHA"

./scripts/petalinux/build_kr260_image.sh \
  "$PROJECT_DIR" \
  "$HW_HANDOFF_DIR" \
  --output-dir "$HW_HANDOFF_DIR"
```

Collected output lands in:

```text
petalinux/output/<project-name>/
  boot/
  rootfs/
  overlay/
  meta/
  MANIFEST.txt
  SHA256SUMS
```

At minimum, check for:

```text
boot/BOOT.BIN
boot/Image
boot/system.dtb
boot/boot.scr
boot/ramdisk.cpio.gz.u-boot
rootfs/rootfs.ext4
overlay/daphne-overlay.dtbo
overlay/daphne-overlay.bin
overlay/shell.json
```

## 6. Overlay generation notes

The manual `xsct` / `createdts` flow from the older notes is still useful for
debugging, but the normal path should stay:

```bash
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output-$DAPHNE_GIT_SHA
```

The current overlay runtime also needs the firmware-name alias expected by the
DT overlay path. On `015`, the critical alias was:

```text
/lib/firmware/daphne_selftrigger_7353a17.bit.bin
```

That is now owned by the repo overlay packaging.

## 7. Device-tree policy

Do not hand-edit generated `pl.dtsi` files in the project workspace as the
long-term solution.

Current repo-owned DT policy lives in:

- `petalinux/meta-daphne/recipes-bsp/device-tree/files/system-user.dtsi`
- `petalinux/meta-daphne/recipes-bsp/device-tree/files/daphne-k26c-network.dtsi`

Important current finding:

- the generated base `pl.dtsi` on `015` originally injected `pl-bus`,
  `axi_iic_0`, `axi_intc_0`, and `axi_quad_spi_0` into the non-overlay DT
- that caused the early `rcu_sched` boot failure
- the repo fix is to delete the generated base `amba_pl` node in
  `system-user.dtsi`, so those PL timing nodes arrive only through the overlay

That fix is now part of the repo-owned DAPHNE DT policy.

## 8. Network configuration notes

The older static `ifconfig` / `rc.local` approach should not be treated as the
fleet contract.

Current DAPHNE policy is:

- one shared image
- repo-owned board inventory
- board-specific identity generated from:
  - MAC addresses
  - hostname
  - management IP
  - endpoint address
  - firmware app
  - timing profile

So board identity is no longer “MAC only”.

## 9. Boot and board validation

After booting the image:

```bash
ssh petalinux@<board-ip>
uname -a
cat /etc/os-release
ip addr show eth0
```

Then validate runtime state:

```bash
systemctl is-active firmware
systemctl is-active clockchip
systemctl is-active endpoint
systemctl is-active hermes
systemctl is-active daphne
```

Validate the overlay/runtime expectations:

```bash
xmutil listapps
ls -l /lib/firmware/xilinx
ls -l /dev/i2c-*
ss -ltnp | grep 40001
```

For `015`, a successful runtime bring-up now means:

- `/dev/mmcblk0p2` mounted as `/`
- FPGA state `operating`
- PL timing path present
- service chain active

## 10. Proven DAPHNE-15 flash workflow

The currently proven offline rootfs flash path on `015` is:

1. stage `rootfs.ext4` on `mmcblk0p1`
2. boot a maintenance shell from a known-good kernel/DT/ramdisk
3. `dd` the staged `rootfs.ext4` onto `mmcblk0p2`
4. `e2fsck`
5. reboot normally

Maintenance-shell example:

```bash
setenv bootargs 'console=ttyPS1,115200 earlycon rdinit=/bin/sh'
fatload mmc 0:1 0x18000000 Image
fatload mmc 0:1 0x40000000 system.dtb
fatload mmc 0:1 0x02100000 ramdisk.cpio.gz.u-boot
booti 0x18000000 0x02100000 0x40000000
```

In the shell:

```bash
mkdir -p /proc /sys /dev /mnt
mount -t devtmpfs devtmpfs /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount /dev/mmcblk0p1 /mnt
dd if=/mnt/deploy-20260509-repo/rootfs.ext4 of=/dev/mmcblk0p2 bs=16M
sync
e2fsck -fy /dev/mmcblk0p2
reboot -f
```

## 11. What was actually proven on 2026-05-09

On `NP04-DAPHNE-015`:

- the rebuilt repo-owned `rootfs.ext4` was flashed successfully
- the board came back with `/dev/mmcblk0p2` as the real `/`
- the repo-owned service chain came up without live rootfs patching
- the fixed repo-owned DTB was first proven in one-shot serial/U-Boot boot
  testing, and is now the persistent default `/boot/system.dtb` on `015`
- the repo-built `Image` is now also the top-level boot image on
  `mmcblk0p1`, and `015` comes back through the normal U-Boot `bootcmd`
  path with the repo-built `Image + system.dtb + ramdisk`
- after a plain reboot, `015` comes back on `10.73.137.16` with the full
  `firmware`, `clockchip`, `endpoint`, `hermes`, and `daphne` chain active
- the early DT-related `rcu_sched` stall is gone

What is still not fully proven:

- the final remote-only A/B boot and recovery model from
  `docs/remote-boot-deployment-plan.md`

## Where this guide differs from the older notes

The older notes and screenshots are still useful, but these parts are now
outdated:

- `meta-daphne` is no longer only a placeholder layer
- board identity is no longer just MAC provisioning
- the `015` DTB failure is now understood and fixed
- the current repo has a real runtime staging path:
  `scripts/petalinux/stage_runtime_into_project.sh`
- the current missing piece is not “can we build any image at all”, but
  “can we complete the repo-owned persistent boot contract”
