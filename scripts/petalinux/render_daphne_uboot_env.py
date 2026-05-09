#!/usr/bin/env python3
"""Render a deterministic U-Boot environment fragment from board inventory."""

import argparse
import csv
import ipaddress
from pathlib import Path


def parse_inventory(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        rows = [
            line for line in handle
            if line.strip() and not line.lstrip().startswith("#")
        ]
    reader = csv.DictReader(rows)
    inventory = {}
    for row in reader:
        normalized = {key: (value or "").strip() for key, value in row.items()}
        board_id = normalized.get("board_id", "")
        if board_id:
            inventory[board_id] = normalized
    return inventory


def dotted_netmask(prefix_bits: str):
    network = ipaddress.IPv4Network(f"0.0.0.0/{prefix_bits}")
    return str(network.netmask)


def render_env(row):
    board_id = row["board_id"]
    hostname_fqdn = row["hostname_fqdn"]
    ipv4_cidr = row["ipv4_cidr"]
    ipaddr, prefix = ipv4_cidr.split("/", 1)
    netmask = dotted_netmask(prefix)

    lines = [
        f"board_id={board_id}",
        f"board_hostname={hostname_fqdn}",
        f"ethaddr={row['mac_ff0b']}",
        f"eth1addr={row['mac_ff0c']}",
        f"ipaddr={ipaddr}",
        f"netmask={netmask}",
        f"netmask_bits={prefix}",
        f"gatewayip={row.get('gw4', '')}",
        f"dnsip={row.get('dns1', '')}",
        f"daphne_endpoint_addr={row['endpoint_addr_hex']}",
        f"daphne_firmware_app={row['firmware_app']}",
        f"daphne_timing_profile={row.get('timing_profile', '')}",
        "kernel_image=Image",
        "fdtfile=system.dtb",
        "ramdisk_image=ramdisk.cpio.gz.u-boot",
        "bootargs_base=console=ttyPS0,115200 earlycon",
        "bootlimit=3",
        "bootcount=0",
        "upgrade_available=0",
        "active_slot=a",
        "last_good_slot=a",
        "slot_a_bootpart=1",
        "slot_a_root=/dev/mmcblk0p2",
        "slot_b_bootpart=3",
        "slot_b_root=/dev/mmcblk0p4",
        "select_slot=if test \"${active_slot}\" = \"a\"; then setenv slot_bootpart ${slot_a_bootpart}; setenv slot_root ${slot_a_root}; else setenv slot_bootpart ${slot_b_bootpart}; setenv slot_root ${slot_b_root}; fi",
        "set_bootargs_daphne=run select_slot; setenv bootargs \"${bootargs_base} ext4=${slot_root}:/rootfs\"",
        "load_slot_assets=mmc dev 0; load mmc 0:${slot_bootpart} ${kernel_addr_r} ${kernel_image}; load mmc 0:${slot_bootpart} ${fdt_addr_r} ${fdtfile}; load mmc 0:${slot_bootpart} ${ramdisk_addr_r} ${ramdisk_image}",
        "boot_slot=run set_bootargs_daphne; run load_slot_assets; booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}",
        "boot_qspi_rescue=echo QSPI rescue image is not provisioned yet; false",
        "flip_active_slot=if test \"${active_slot}\" = \"a\"; then setenv active_slot b; else setenv active_slot a; fi",
        "evaluate_upgrade=if test \"${upgrade_available}\" = \"1\"; then if test ${bootcount} -ge ${bootlimit}; then run flip_active_slot; setenv upgrade_available 0; saveenv; fi; fi",
        "mark_boot_ok=setenv upgrade_available 0; setenv bootcount 0; setenv last_good_slot ${active_slot}; saveenv",
        "bootcmd_daphne=run evaluate_upgrade; run boot_slot",
        "bootcmd=run bootcmd_daphne",
        "rescue_bootcmd=run boot_qspi_rescue",
    ]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(
        description="Render a repo-owned U-Boot environment fragment for a DAPHNE board."
    )
    parser.add_argument("--inventory", required=True, type=Path)
    parser.add_argument("--board-id", required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    inventory = parse_inventory(args.inventory)
    if args.board_id not in inventory:
        known = ", ".join(sorted(inventory))
        raise SystemExit(
            f"unknown board_id '{args.board_id}', expected one of: {known}"
        )

    rendered = render_env(inventory[args.board_id])
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
