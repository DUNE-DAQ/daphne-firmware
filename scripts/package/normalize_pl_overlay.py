#!/usr/bin/env python3
"""Normalize Vitis PL output into a loadable Kria FPGA overlay."""

from __future__ import annotations

import argparse
import re
import textwrap
from pathlib import Path


DIRECTIVES = {"/dts-v1/;", "/plugin/;"}
REGION_NODE_RE = re.compile(r"^(?:clocking\d+|afi\d+|zyxclmm_drm)$")


def _block_indent(block_lines: list[str], default: str) -> str:
    for candidate in block_lines[1:]:
        stripped = candidate.strip()
        if stripped and stripped != "};":
            return candidate[: len(candidate) - len(candidate.lstrip())]
    return default


def _rewrite_intc_block(block_lines: list[str]) -> list[str]:
    indent = _block_indent(block_lines, "\t")
    rewritten = []
    for line in block_lines[:-1]:
        stripped = line.strip()
        if stripped.startswith("#interrupt-cells"):
            continue
        if stripped.startswith("interrupt-controller"):
            continue
        rewritten.append(line.replace("<&imux>", "<&gic>"))
    rewritten.append(f"{indent}#interrupt-cells = <2>;")
    rewritten.append(f"{indent}interrupt-controller;")
    rewritten.append(block_lines[-1])
    return rewritten


def _rewrite_spi_block(block_lines: list[str]) -> list[str]:
    indent = _block_indent(block_lines, "\t")
    nested_indent = indent + "\t"
    rewritten = []
    skip_depth = 0
    for line in block_lines[:-1]:
        stripped = line.strip()
        if skip_depth > 0:
            skip_depth += line.count("{")
            skip_depth -= line.count("}")
            continue
        if stripped.startswith("#address-cells"):
            continue
        if stripped.startswith("#size-cells"):
            continue
        if stripped.startswith("spidev@0"):
            skip_depth = line.count("{") - line.count("}")
            continue
        rewritten.append(line)

    rewritten.extend(
        [
            f"{indent}#address-cells = <1>;",
            f"{indent}#size-cells = <0>;",
            f"{indent}spidev@0 {{",
            f'{nested_indent}status = "okay";',
            f'{nested_indent}compatible = "rohm,dh2228fv";',
            f"{nested_indent}spi-max-frequency = <50000000>;",
            f"{nested_indent}reg = <0>;",
            f"{indent}}};",
        ]
    )
    rewritten.append(block_lines[-1])
    return rewritten


def _rewrite_generated_blocks(lines: list[str]) -> list[str]:
    rewritten = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if "interrupt-controller@9c010000" not in line and "axi_quad_spi@9c020000" not in line:
            rewritten.append(line.replace("<&imux>", "<&gic>"))
            index += 1
            continue

        block = [line]
        depth = line.count("{") - line.count("}")
        index += 1
        while index < len(lines):
            block.append(lines[index])
            depth += lines[index].count("{") - lines[index].count("}")
            index += 1
            if depth <= 0:
                break
        if depth != 0:
            raise ValueError(f"unterminated device-tree block: {block[0].strip()}")
        if "interrupt-controller@9c010000" in block[0]:
            rewritten.extend(_rewrite_intc_block(block))
        else:
            rewritten.extend(_rewrite_spi_block(block))
    return rewritten


def _find_amba_pl_block(lines: list[str]) -> tuple[int, int]:
    pattern = re.compile(r"^\s*(?:[A-Za-z_][A-Za-z0-9_]*:\s*)?amba_pl\s*\{\s*$")
    for start, line in enumerate(lines):
        if not pattern.match(line):
            continue
        depth = 0
        for end in range(start, len(lines)):
            depth += lines[end].count("{") - lines[end].count("}")
            if depth == 0:
                return start, end
        raise ValueError("unterminated amba_pl block")
    raise ValueError("generated device tree has no amba_pl block")


def _block_end(lines: list[str], start: int) -> int:
    depth = 0
    for end in range(start, len(lines)):
        depth += lines[end].count("{") - lines[end].count("}")
        if depth == 0:
            return end
    raise ValueError(f"unterminated device-tree block: {lines[start].strip()}")


def _canonical_generated_root(lines: list[str]) -> list[str]:
    """Accept both SDT's amba_pl root and its one-fragment /axi variant."""
    try:
        _find_amba_pl_block(lines)
        return lines
    except ValueError:
        pass

    target_index = next(
        (
            index
            for index, line in enumerate(lines)
            if 'target-path = "/axi";' in line
        ),
        None,
    )
    if target_index is None:
        raise ValueError("generated device tree has neither amba_pl nor a /axi fragment")

    fragment_start = next(
        (
            index
            for index in range(target_index, -1, -1)
            if re.match(r"^\s*fragment@\d+\s*\{\s*$", lines[index])
        ),
        None,
    )
    if fragment_start is None:
        raise ValueError("/axi target-path is not inside a fragment")
    fragment_end = _block_end(lines, fragment_start)
    overlay_start = next(
        (
            index
            for index in range(target_index + 1, fragment_end)
            if re.match(r"^\s*__overlay__\s*\{\s*$", lines[index])
        ),
        None,
    )
    if overlay_start is None:
        raise ValueError("/axi fragment has no __overlay__ block")
    overlay_end = _block_end(lines, overlay_start)

    body = textwrap.dedent(
        "\n".join(lines[overlay_start + 1 : overlay_end])
    ).splitlines()
    return ["/ {", "\tamba_pl {"] + [f"\t\t{line}" for line in body] + ["\t};", "};"]


def _top_level_entries(lines: list[str]) -> list[list[str]]:
    entries: list[list[str]] = []
    index = 0
    while index < len(lines):
        if not lines[index].strip():
            index += 1
            continue
        entry = [lines[index]]
        depth = lines[index].count("{") - lines[index].count("}")
        index += 1
        while depth > 0 and index < len(lines):
            entry.append(lines[index])
            depth += lines[index].count("{") - lines[index].count("}")
            index += 1
        if depth != 0:
            raise ValueError(f"unterminated top-level entry: {entry[0].strip()}")
        entries.append(entry)
    return entries


def _node_name(header: str) -> str:
    declaration = header.strip().split("{", 1)[0].strip()
    declaration = declaration.rsplit(":", 1)[-1].strip()
    return declaration.split("@", 1)[0]


def _indent_entry(entry: list[str], depth: int) -> list[str]:
    normalized = textwrap.dedent("\n".join(entry)).splitlines()
    prefix = "\t" * depth
    return [f"{prefix}{line}" if line else "" for line in normalized]


def _split_for_kria(
    lines: list[str], firmware_name_override: str | None
) -> list[str]:
    if any("target = <&fpga_full>;" in line for line in lines) and any(
        "target = <&amba>;" in line for line in lines
    ):
        return lines

    lines = _canonical_generated_root(lines)
    start, end = _find_amba_pl_block(lines)
    significant_before = [line.strip() for line in lines[:start] if line.strip()]
    significant_after = [line.strip() for line in lines[end + 1 :] if line.strip()]
    if significant_before != ["/ {"] or significant_after != ["};"]:
        raise ValueError("expected amba_pl to be the only generated root node")

    address_cells = "#address-cells = <2>;"
    size_cells = "#size-cells = <2>;"
    firmware_name: str | None = None
    region_entries: list[list[str]] = []
    bus_entries: list[list[str]] = []

    for entry in _top_level_entries(lines[start + 1 : end]):
        first = entry[0].strip()
        if "{" not in first:
            if first.startswith("#address-cells"):
                address_cells = first
            elif first.startswith("#size-cells"):
                size_cells = first
            elif first.startswith("firmware-name"):
                firmware_name = first
            elif first in {"ranges;", 'compatible = "simple-bus";'}:
                continue
            else:
                raise ValueError(f"unsupported amba_pl property: {first}")
            continue

        if REGION_NODE_RE.fullmatch(_node_name(first)):
            region_entries.append(entry)
        else:
            bus_entries.append(entry)

    if firmware_name_override is not None:
        firmware_name = f'firmware-name = "{firmware_name_override}";'
    if firmware_name is None:
        raise ValueError("generated device tree has no firmware-name property")
    if not region_entries:
        raise ValueError("generated device tree has no FPGA-region nodes")
    if not bus_entries:
        raise ValueError("generated device tree has no AXI peripheral nodes")

    output = [
        "/ {",
        "\tfragment@0 {",
        "\t\ttarget = <&fpga_full>;",
        "\t\t__overlay__ {",
        f"\t\t\t{address_cells}",
        f"\t\t\t{size_cells}",
        f"\t\t\t{firmware_name}",
        "\t\t\tresets = <&zynqmp_reset 116>, <&zynqmp_reset 117>;",
    ]
    for entry in region_entries:
        output.extend(_indent_entry(entry, 3))
    output.extend(
        [
            "\t\t};",
            "\t};",
            "\tfragment@1 {",
            "\t\ttarget = <&amba>;",
            "\t\t__overlay__ {",
            f"\t\t\t{address_cells}",
            f"\t\t\t{size_cells}",
        ]
    )
    for entry in bus_entries:
        output.extend(_indent_entry(entry, 3))
    output.extend(["\t\t};", "\t};", "};"])
    return output


def _validate_kria_fragments(
    lines: list[str], firmware_name_override: str | None
) -> None:
    fragments: dict[str, list[str]] = {}
    index = 0
    while index < len(lines):
        if not re.match(r"^\s*fragment@\d+\s*\{\s*$", lines[index]):
            index += 1
            continue
        end = _block_end(lines, index)
        block = lines[index : end + 1]
        targets = re.findall(r"target\s*=\s*<&([^>]+)>\s*;", "\n".join(block))
        if len(targets) != 1:
            raise ValueError(
                f"{lines[index].strip()} must contain exactly one phandle target"
            )
        target = targets[0]
        if target in fragments:
            raise ValueError(f"overlay contains duplicate <&{target}> fragments")
        fragments[target] = block
        index = end + 1

    if set(fragments) != {"fpga_full", "amba"}:
        rendered = ", ".join(f"<&{target}>" for target in sorted(fragments))
        raise ValueError(
            "normalized overlay must contain exactly <&fpga_full> and <&amba> "
            f"fragments; found: {rendered or 'none'}"
        )

    fpga_text = "\n".join(fragments["fpga_full"])
    amba_text = "\n".join(fragments["amba"])
    firmware_names = re.findall(
        r'firmware-name\s*=\s*"([^"]+)"\s*;', fpga_text
    )
    if len(firmware_names) != 1:
        raise ValueError(
            "<&fpga_full> fragment must contain exactly one firmware-name"
        )
    if firmware_name_override is not None and firmware_names[0] != firmware_name_override:
        raise ValueError(
            f"<&fpga_full> firmware-name is {firmware_names[0]!r}; "
            f"expected {firmware_name_override!r}"
        )
    if "firmware-name" in amba_text:
        raise ValueError("firmware-name must not be attached to the <&amba> fragment")
    if "resets = <&zynqmp_reset 116>, <&zynqmp_reset 117>;" not in fpga_text:
        raise ValueError("<&fpga_full> fragment is missing the PL reset contract")
    for node in ("interrupt-controller@9c010000", "i2c@9c000000"):
        if node not in amba_text:
            raise ValueError(f"<&amba> fragment is missing {node}")


def normalize_overlay_text(
    source: str, firmware_name_override: str | None = None
) -> str:
    lines = [line for line in source.splitlines() if line.strip() not in DIRECTIVES]
    lines = _rewrite_generated_blocks(lines)
    lines = _split_for_kria(lines, firmware_name_override)
    _validate_kria_fragments(lines, firmware_name_override)
    output = "\n".join(["/dts-v1/;", "/plugin/;", *lines]) + "\n"

    required = (
        "target = <&fpga_full>;",
        "target = <&amba>;",
        "interrupt-controller@9c010000",
        "i2c@9c000000",
        "interrupt-parent = <&gic>;",
        "#interrupt-cells = <2>;",
        "firmware-name =",
    )
    missing = [value for value in required if value not in output]
    if missing:
        raise ValueError(f"normalized overlay is missing: {', '.join(missing)}")
    if "&imux" in output:
        raise ValueError("normalized overlay still references unavailable imux symbol")
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("dtsi", type=Path, help="Vitis-generated pl.dtsi to normalize in place")
    parser.add_argument(
        "--firmware-name",
        help="firmware filename installed beside the DTBO in the DFX app directory",
    )
    args = parser.parse_args()

    source = args.dtsi.read_text()
    args.dtsi.write_text(normalize_overlay_text(source, args.firmware_name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
