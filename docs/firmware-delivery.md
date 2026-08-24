# Firmware delivery

The repository supports two delivery forms for K26C boards.

## FPGA overlay bundle

After a successful Vivado build, the firmware output directory contains the
FPGA image and hardware description:

```text
daphne_selftrigger_<sha>.bit
daphne_selftrigger_<sha>.bin
daphne_selftrigger_<sha>.xsa
```

Complete the Linux overlay bundle with:

```bash
./scripts/package/complete_dtbo_bundle.sh \
  ./xilinx/output-$DAPHNE_GIT_SHA
```

This adds the `.dtbo`, overlay directory, overlay ZIP, and checksums. Use this
form when the board already has a compatible Linux image.

## PetaLinux image bundle

The repo-owned PetaLinux wrapper consumes the Vivado hardware handoff, stages
the overlay and optional runtime bundle, builds the image, and collects the
deployment artifacts:

```bash
./scripts/petalinux/build_kr260_image.sh \
  /path/to/petalinux-project \
  ./xilinx/output-$DAPHNE_GIT_SHA \
  --output-dir ./xilinx/output-$DAPHNE_GIT_SHA \
  --runtime-bundle /path/to/qualified-runtime.tgz \
  --package-boot
```

The collected bundle includes the available boot, kernel, device-tree, and
rootfs artifacts plus hashes and a manifest. `BOOT.BIN` is included only when
`--package-boot` is requested.

See `kr260-petalinux-build-guide.md` for the complete build, recovery, and
validation procedure.

## Deploy one board

Render and review the per-board configuration first. Then use a dry run before
any write:

```bash
./scripts/deploy/daphne_deploy.sh \
  --board <board-id> \
  --host <board-host-or-ip> \
  --bundle /path/to/collected-bundle \
  --board-config /path/to/rendered-board-config \
  --host-key-sha256 <ed25519-fingerprint> \
  --dry-run
```

Remove `--dry-run` only after the printed board, host, inactive slot, bundle,
configuration, and hashes are correct. This command writes the inactive eMMC
slot. It does not update QSPI, change the MAC, or change board identity.

The same qualified image may be deployed to many boards by repeating the
one-board command with each board's rendered configuration. Campaign-wide
scheduling and evidence collection belong to the production-station layer.

## Qualification boundary

Generated artifacts are build products, not automatically qualified releases.
Before production use, require the release's timing, DRC, CDC, power,
configuration readback, recovery, and on-board data-path evidence. QSPI boot
firmware is a separate update and qualification path.

In this documentation, *hardware handoff* means the `.xsa` passed from Vivado
to PetaLinux. It does not refer to the deprecated agent-session handoff notes.
