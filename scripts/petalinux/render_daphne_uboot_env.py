#!/usr/bin/env python3
"""Render a deterministic U-Boot environment fragment from board inventory."""

import argparse
import csv
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


def render_env(row):
    board_id = row["board_id"]
    hostname_fqdn = row["hostname_fqdn"]
    ipv4_cidr = row["ipv4_cidr"]
    ipaddr, prefix = ipv4_cidr.split("/", 1)

    lines = [
        f"board_id={board_id}",
        f"board_hostname={hostname_fqdn}",
        f"ethaddr={row['mac_ff0b']}",
        f"eth1addr={row['mac_ff0c']}",
        f"ipaddr={ipaddr}",
        f"netmask_bits={prefix}",
        f"gatewayip={row.get('gw4', '')}",
        f"dnsip={row.get('dns1', '')}",
        f"daphne_endpoint_addr={row['endpoint_addr_hex']}",
        f"daphne_firmware_app={row['firmware_app']}",
        f"daphne_timing_profile={row.get('timing_profile', '')}",
        "bootlimit=3",
        "bootcount=0",
        "upgrade_available=0",
        "active_slot=a",
        "last_good_slot=a",
        "rescue_bootcmd=run boot_qspi_rescue",
        "slot_a_bootpart=1",
        "slot_a_root=/dev/mmcblk0p2",
        "slot_b_bootpart=3",
        "slot_b_root=/dev/mmcblk0p4",
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
