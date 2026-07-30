#!/usr/bin/env python3
"""Render runtime files from a versioned DAPHNE board configuration."""

from __future__ import annotations

import argparse
import csv
import hashlib
import ipaddress
import json
import re
import shlex
from pathlib import Path


MAC_RE = re.compile(r"^(?:[0-9a-f]{2}:){5}[0-9a-f]{2}$")
SAFE_VALUE_RE = re.compile(r"^[A-Za-z0-9_.:/-]+$")


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def read_asset(path: Path, asset_id: str) -> dict[str, str]:
    with path.open(newline="", encoding="utf-8") as source:
        rows = [row for row in csv.DictReader(source) if row.get("asset_id") == asset_id]
    if len(rows) != 1:
        fail(f"expected one {asset_id} row in {path}, found {len(rows)}")
    return rows[0]


def read_record(path: Path, expected_sha256: str | None) -> dict[str, str]:
    raw = path.read_bytes()
    actual_sha256 = hashlib.sha256(raw).hexdigest()
    if expected_sha256 and actual_sha256 != expected_sha256.lower():
        fail(
            f"board configuration checksum mismatch: expected {expected_sha256}, "
            f"got {actual_sha256}"
        )
    try:
        record = json.loads(raw)
    except json.JSONDecodeError as exc:
        fail(f"invalid board configuration JSON: {exc}")
    if not isinstance(record, dict):
        fail("board configuration JSON must be an object")
    if record.get("contract") != "daphne.board-config" or record.get("version") != 1:
        fail("unsupported board configuration contract")
    try:
        return {
            "asset_id": record["asset"]["asset_id"],
            "som_uuid": record["som"]["uuid"],
            "factory_mac_id_0": record["som"]["factory_mac_id_0"],
            "mac_source": record["network"]["mac_source"],
            "production_mac": record["network"]["production_mac"],
            "ipv4_address": record["network"]["ipv4_address"],
            "hostname": record["network"]["hostname"],
            "timing_endpoint": record["runtime"]["timing_endpoint"],
            "firmware_release": record["runtime"]["firmware_release"],
            "network_admission_approved": "1" if record["network"]["authorized"] else "0",
            "board_config_sha256": actual_sha256,
        }
    except (KeyError, TypeError) as exc:
        fail(f"board configuration is missing required field: {exc}")


def env_line(key: str, value: str) -> str:
    if not value or not SAFE_VALUE_RE.fullmatch(value):
        fail(f"unsafe or empty {key}: {value!r}")
    return f"{key}={shlex.quote(value)}\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--record", type=Path, help="daphne.board-config v1 JSON")
    source.add_argument("--inventory", type=Path, help="legacy staging inventory CSV")
    parser.add_argument("--record-sha256", help="expected SHA-256 of --record")
    parser.add_argument("--asset", help="asset ID selected from --inventory")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--prefix", type=int, default=24)
    parser.add_argument("--gateway", required=True)
    parser.add_argument("--dns", action="append", required=True)
    parser.add_argument(
        "--allow-unapproved",
        action="store_true",
        help="render a lab trial config while network_admission_approved is false",
    )
    args = parser.parse_args()

    if args.record:
        row = read_record(args.record, args.record_sha256)
    else:
        if not args.asset:
            fail("--asset is required with --inventory")
        if args.record_sha256:
            fail("--record-sha256 is valid only with --record")
        row = read_asset(args.inventory, args.asset)
    if row.get("network_admission_approved") not in {"1", "true", "True"}:
        if not args.allow_unapproved:
            fail("network admission is not approved in the inventory")

    address = ipaddress.ip_address(row["ipv4_address"])
    gateway = ipaddress.ip_address(args.gateway)
    network = ipaddress.ip_network(f"{address}/{args.prefix}", strict=False)
    if gateway not in network:
        fail(f"gateway {gateway} is not in {network}")
    dns_servers = [str(ipaddress.ip_address(value)) for value in args.dns]

    factory_mac = row["factory_mac_id_0"].lower()
    expected_mac = row["production_mac"].lower()
    for name, value in (("factory MAC", factory_mac), ("expected MAC", expected_mac)):
        if not MAC_RE.fullmatch(value):
            fail(f"invalid {name}: {value}")

    output = args.output
    output.mkdir(parents=True, exist_ok=True)

    board_env = "".join(
        [
            env_line("BOARD_ID", row["asset_id"]),
            env_line("HOSTNAME_FQDN", row["hostname"]),
            env_line("SOM_UUID", row["som_uuid"]),
            env_line("FACTORY_MAC_ID_0", factory_mac),
            env_line("IPV4_CIDR", f"{address}/{args.prefix}"),
            env_line("GW4", str(gateway)),
            env_line("ENDPOINT_ADDR_HEX", row["timing_endpoint"]),
            env_line("APP", "daphne"),
        ]
        + [env_line(f"DNS{index}", value) for index, value in enumerate(dns_servers, 1)]
    )
    (output / "daphne-board.env").write_text(board_env, encoding="utf-8")
    (output / "hostname").write_text(f"{row['hostname']}\n", encoding="utf-8")

    dns_lines = "".join(f"DNS={value}\n" for value in dns_servers)
    (output / "20-daphne-mgmt.network").write_text(
        "[Match]\n"
        "Name=eth0\n\n"
        "[Network]\n"
        f"Address={address}/{args.prefix}\n"
        f"Gateway={gateway}\n"
        f"{dns_lines}",
        encoding="utf-8",
    )
    (output / "21-daphne-unused.network").write_text(
        "[Match]\n"
        "Name=eth1\n\n"
        "[Network]\n"
        "DHCP=no\n"
        "LinkLocalAddressing=no\n"
        "IPv6AcceptRA=no\n",
        encoding="utf-8",
    )
    manifest = "".join(
        [
            env_line("ASSET_ID", row["asset_id"]),
            env_line("HOSTNAME_FQDN", row["hostname"]),
            env_line("SOM_UUID", row["som_uuid"]),
            env_line("FACTORY_MAC_ID_0", factory_mac),
            env_line("EXPECTED_BOOT_MAC", expected_mac),
            env_line("MAC_SOURCE", row["mac_source"]),
            env_line("IPV4_CIDR", f"{address}/{args.prefix}"),
        ]
        + ([env_line("FIRMWARE_RELEASE", row["firmware_release"])] if row.get("firmware_release") else [])
        + ([env_line("BOARD_CONFIG_SHA256", row["board_config_sha256"])] if row.get("board_config_sha256") else [])
    )
    (output / "manifest.env").write_text(manifest, encoding="utf-8")

    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
