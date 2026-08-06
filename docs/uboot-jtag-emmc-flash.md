# U-Boot JTAG eMMC Flashing

Status: pilot automation draft

## Goal

Flash a blank or unconfigured K26 eMMC quickly without requiring Linux to be
installed on the board first.

```text
operator installs SOM on DAPHNE carrier
  -> xsdb JTAG RAM boot
  -> U-Boot prompt on serial
  -> read SOM EEPROM at 0x50
  -> database discover/allocate/render
  -> TFTP block-aligned WIC chunks
  -> U-Boot mmc write to eMMC
  -> reboot into the installed image
```

This path does not program QSPI. If a SOM cannot be RAM-booted over JTAG, move
it to a separate boot-firmware recovery lane.

## Required Station Services

- JTAG adapter visible to `xsdb`.
- Serial console connected to the U-Boot console.
- TFTP server reachable from the DAPHNE management Ethernet port.
- Power control or an operator-enforced power-cycle step.
- Immutable WIC chunk manifest and chunk files in the TFTP root.
- Built boot components for the same release: `pmufw.elf`,
  `zynqmp_fsbl.elf`, `bl31.elf`, and `u-boot-dtb.elf`.
- User Python environment with `pyserial`.

Set the station-specific paths once per lane. `DAPHNE_SERIAL` must be the port
confirmed to carry the DAPHNE UART1 console; do not assume USB enumeration is
stable between cable reconnects.

```bash
STATION_PYTHON="${STATION_PYTHON:-python3}"
HARDWARE_DATABASE="${HARDWARE_DATABASE:-../hardware-database}"
DAPHNE_SERIAL="${DAPHNE_SERIAL:-/dev/ttyUSB2}"
DAPHNE_RELEASE="${DAPHNE_RELEASE:-$(git rev-parse --short HEAD)}"
```

## One-Station Operator Loop

Run one board at a time on a station lane:

1. Scan or enter the DAPHNE asset ID.
2. Install the K26 SOM on the DAPHNE carrier and connect JTAG, serial, Ethernet,
   and power.
3. RAM-boot U-Boot over JTAG with `xsdb`.
4. Catch the U-Boot prompt on serial.
5. Dump the K26 SOM EEPROM over U-Boot I2C and decode it with the production
   database tool.
6. Allocate or recover the board assignment in the database.
7. Flash the WIC chunks to eMMC from U-Boot.
8. Reset into the installed image and record provisioning evidence.
9. Remove the board and repeat with the next unit.

The station must quarantine, not improvise, if the EEPROM decode fails, the
MAC is missing or duplicated, U-Boot selected a random MAC, or the database
assignment conflicts with an existing board.

## Prepare WIC Chunks

U-Boot normally loads a whole TFTP file into RAM. Split the WIC into
block-aligned chunks so each chunk can be loaded, checked, and written without
requiring enough RAM for the full image.

```bash
"${STATION_PYTHON}" scripts/remote/prepare_uboot_wic_chunks.py \
  --input petalinux/output/daphne-petalinux/rootfs/rootfs.wic.gz \
  --output-dir "/srv/tftp/daphne/releases/${DAPHNE_RELEASE}/wic" \
  --name "daphne-image-${DAPHNE_RELEASE}" \
  --chunk-size 64MiB
```

The output manifest records each chunk filename, eMMC start block, block count,
padded size, CRC32, and SHA-256.

## RAM-Boot U-Boot Over JTAG

Vivado/Vitis 2026 installs `xsdb`, not `xsct`, on the tested `cooper`
toolchain. Use the repo-owned TCL script:

```bash
/tools/2026.1/Vivado/bin/xsdb scripts/remote/xsdb_boot_uboot.tcl \
  -fsbl petalinux/output/daphne-petalinux/boot/zynqmp_fsbl.elf \
  -pmufw petalinux/output/daphne-petalinux/boot/pmufw.elf \
  -bl31 petalinux/output/daphne-petalinux/boot/bl31.elf \
  -uboot petalinux/output/daphne-petalinux/boot/u-boot-dtb.elf
```

Then catch the U-Boot prompt on serial:

```bash
"${STATION_PYTHON}" scripts/remote/serial_catch_uboot.py \
  --device "${DAPHNE_SERIAL}" \
  --log /evidence/RUN/serial.log
```

## Read SOM EEPROM Without Linux

Dump the raw K26 SOM EEPROM through U-Boot before flashing:

```bash
"${STATION_PYTHON}" scripts/remote/uboot_dump_i2c_eeprom.py \
  --device "${DAPHNE_SERIAL}" \
  --i2c-bus 1 \
  --chip 0x50 \
  --offset-width 2 \
  --size 8192 \
  --output /evidence/RUN/som-eeprom.bin \
  --log /evidence/RUN/eeprom.log
```

Decode that raw dump in the `hardware-database` checkout:

```bash
PYTHONPATH="${HARDWARE_DATABASE}/tools" \
"${STATION_PYTHON}" -m daphne_production.cli eeprom-decode \
  --input /evidence/RUN/som-eeprom.bin \
  --dump-output /evidence/RUN/som-eeprom.bin \
  --asset-id DAPHNE-007 \
  --operation-id DAPHNE-007-discover \
  --station-id cooper-lane-1 \
  --operator "$USER" \
  --evidence-uri /evidence/RUN \
  --discover-command
```

The decoder validates the IPMI FRU structure and extracts the SOM UUID, serial,
product, revision, EEPROM SHA-256, and MAC ID 0. For the carrier-board
production lane, this U-Boot dump replaces the Linux
`/sys/bus/i2c/devices/1-0050/eeprom` capture.

## Flash eMMC From U-Boot

Dry-run the exact command sequence first:

```bash
"${STATION_PYTHON}" scripts/remote/uboot_flash_wic.py \
  --manifest "/srv/tftp/daphne/releases/${DAPHNE_RELEASE}/wic/manifest.json" \
  --tftp-prefix "daphne/releases/${DAPHNE_RELEASE}/wic" \
  --serverip 192.0.2.1 \
  --dhcp \
  --mmc-dev 0 \
  --verify-readback \
  --dry-run
```

Run the flash:

```bash
"${STATION_PYTHON}" scripts/remote/uboot_flash_wic.py \
  --manifest "/srv/tftp/daphne/releases/${DAPHNE_RELEASE}/wic/manifest.json" \
  --tftp-prefix "daphne/releases/${DAPHNE_RELEASE}/wic" \
  --serverip 192.0.2.1 \
  --dhcp \
  --mmc-dev 0 \
  --verify-readback \
  --reset-after \
  --device "${DAPHNE_SERIAL}" \
  --log /evidence/RUN/flash.log
```

For a static pilot network, replace `--dhcp` with explicit U-Boot variables:

```bash
--ipaddr 192.0.2.101 --serverip 192.0.2.1 --netmask 255.255.255.0
```

If a privileged TFTP service on UDP port 69 is unavailable, validate that the
built U-Boot honors `tftpdstp` and pass a high-port server setting:

```bash
--tftp-dst-port 1069
```

For throughput tuning after the first board, the flasher can also set
`tftpblocksize` and `tftpwindowsize`.

Use `--ethaddr` only when U-Boot did not already load the expected K26 EEPROM
MAC. A random U-Boot MAC is a quarantine condition.

After a successful flash, record provisioning in the database using the rendered
board snapshot hash and the release artifact manifest hash. Do not mark QA
passed until the post-boot QA recipe is complete.

## Pilot Constraints

- Flash one powered board per station lane.
- Keep the TFTP release directory immutable during a run.
- Use `--verify-readback` for the 10-board pilot. Disable it later only after
  measuring the time tradeoff and adding a separate post-boot image-integrity
  check.
- Record the manifest, serial transcript, operator, station ID, asset ID, and
  database operation IDs as evidence.
- Confirm the station-specific values once with hardware before the 10-board
  pilot: serial port, JTAG target filters, U-Boot I2C bus, U-Boot MMC device,
  and management Ethernet link speed.
