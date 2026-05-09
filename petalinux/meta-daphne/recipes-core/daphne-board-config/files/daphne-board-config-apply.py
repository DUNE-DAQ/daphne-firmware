#!/usr/bin/env python3

import argparse
import csv
from pathlib import Path

FF0B_PATH = "platform-ff0b0000.ethernet"
FF0C_PATH = "platform-ff0c0000.ethernet"


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


def write_text(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def format_link(path_match: str, mac: str):
    return (
        "[Match]\n"
        f"Path={path_match}\n\n"
        "[Link]\n"
        f"MACAddress={mac}\n"
        "MACAddressPolicy=none\n"
    )


def format_ff0b_network(row):
    lines = [
        "[Match]",
        "Name=eth0",
        "",
        "[Network]",
        f"Address={row['ipv4_cidr']}",
    ]
    if row.get("gw4"):
        lines.append(f"Gateway={row['gw4']}")
    if row.get("dns1"):
        lines.append(f"DNS={row['dns1']}")
    if row.get("dns2"):
        lines.append(f"DNS={row['dns2']}")
    return "\n".join(lines) + "\n"


def format_ff0c_network():
    return (
        "[Match]\n"
        "Name=eth1\n\n"
        "[Network]\n"
        "DHCP=no\n"
        "LinkLocalAddressing=no\n"
        "IPv6AcceptRA=no\n"
    )


def format_firmware_defaults(row):
    lines = [
        f"APP={row['firmware_app']}",
        f"ENDPOINT_ADDR_HEX={row['endpoint_addr_hex']}",
    ]
    if row.get("endpoint_wait_ms"):
        lines.append(f"ENDPOINT_WAIT_MS={row['endpoint_wait_ms']}")
    if row.get("endpoint_success_states"):
        lines.append(f"ENDPOINT_SUCCESS_STATES={row['endpoint_success_states']}")
    return "\n".join(lines) + "\n"


def format_board_env(row):
    keys = [
        "board_id",
        "hostname_fqdn",
        "sticker",
        "ipv4_cidr",
        "gw4",
        "dns1",
        "dns2",
        "mac_ff0b",
        "mac_ff0c",
        "ipv6_cidr",
        "gw6",
        "endpoint_addr_hex",
        "firmware_app",
        "endpoint_wait_ms",
        "endpoint_success_states",
        "timing_profile",
        "clockchip_bus",
        "clockchip_addr",
    ]
    lines = []
    for key in keys:
        value = row.get(key, "")
        lines.append(f"{key.upper()}={value}")
    return "\n".join(lines) + "\n"


def apply_board(root: Path, row):
    etc_dir = root / "etc"
    write_text(etc_dir / "default" / "firmware", format_firmware_defaults(row))
    write_text(etc_dir / "daphne-board.env", format_board_env(row))
    write_text(
        etc_dir / "systemd" / "network" / "10-ff0b.link",
        format_link(FF0B_PATH, row["mac_ff0b"]),
    )
    write_text(
        etc_dir / "systemd" / "network" / "11-ff0c.link",
        format_link(FF0C_PATH, row["mac_ff0c"]),
    )
    write_text(
        etc_dir / "systemd" / "network" / "20-ff0b.network",
        format_ff0b_network(row),
    )
    write_text(
        etc_dir / "systemd" / "network" / "21-ff0c.network",
        format_ff0c_network(),
    )


def main():
    parser = argparse.ArgumentParser(
        description="Apply a DAPHNE board profile from the canonical inventory."
    )
    parser.add_argument("--inventory", required=True, type=Path)
    parser.add_argument("--board-id", required=True)
    parser.add_argument("--root", required=True, type=Path)
    args = parser.parse_args()

    inventory = parse_inventory(args.inventory)
    if args.board_id not in inventory:
        known = ", ".join(sorted(inventory))
        raise SystemExit(
            f"unknown board_id '{args.board_id}', expected one of: {known}"
        )

    apply_board(args.root, inventory[args.board_id])


if __name__ == "__main__":
    main()
