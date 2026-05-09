#!/usr/bin/env python3

import argparse
import csv
import ipaddress
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


def dotted_netmask(prefix_bits: str):
    network = ipaddress.IPv4Network(f"0.0.0.0/{prefix_bits}")
    return str(network.netmask)


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


def format_uboot_env(row):
    ipaddr, prefix = row["ipv4_cidr"].split("/", 1)
    netmask = dotted_netmask(prefix)
    lines = [
        f"board_id={row['board_id']}",
        f"board_hostname={row['hostname_fqdn']}",
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


def format_fw_env_config():
    return (
        "# Current KR260/DAPHNE QSPI env partitions.\n"
        "# Primary partition label: U-Boot storage variables\n"
        "# Backup partition label: U-Boot storage variables backup\n"
        "/dev/mtd12 0x0 0x20000 0x20000\n"
        "/dev/mtd13 0x0 0x20000 0x20000\n"
    )


def apply_board(root: Path, row):
    etc_dir = root / "etc"
    write_text(etc_dir / "default" / "firmware", format_firmware_defaults(row))
    write_text(etc_dir / "daphne-board.env", format_board_env(row))
    write_text(etc_dir / "daphne-uboot.env", format_uboot_env(row))
    write_text(etc_dir / "fw_env.config", format_fw_env_config())
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
