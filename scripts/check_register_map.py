#!/usr/bin/env python3
"""Check that the documented self-trigger register map matches the RTL."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOC_PATH = ROOT / "Memory_Map.md"
STUFF_PATH = ROOT / "ip_repo/daphne_ip/rtl/config/stuff.vhd"
TOP_PATH = ROOT / "ip_repo/daphne_ip/rtl/daphne_selftrigger_top.vhd"
BD_PATH = ROOT / "xilinx/daphne_bd_gen.tcl"
FLOW_PATH = ROOT / "xilinx/daphne_vivado_flow.tcl"
REGISTER_BANK_PATH = (
    ROOT / "rtl/isolated/subsystems/control/selftrigger_register_bank.vhd"
)
RECORD_BUILDER_PATH = (
    ROOT / "rtl/isolated/subsystems/trigger/stc3_record_builder.vhd"
)


def table_rows(text: str) -> dict[int, list[list[str]]]:
    """Return Markdown register rows grouped by their absolute address."""
    rows: dict[int, list[list[str]]] = {}
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 8 or re.fullmatch(r"0x[0-9A-Fa-f]{8}", cells[1]) is None:
            continue
        rows.setdefault(int(cells[1], 16), []).append(cells)
    return rows


def binary_constants(text: str) -> dict[str, int]:
    pattern = re.compile(
        r"constant\s+(\w+)\s*:\s*std_logic_vector\([^)]*\)\s*:=\s*\"([01]+)\"",
        re.IGNORECASE,
    )
    return {name: int(bits, 2) for name, bits in pattern.findall(text)}


def hex_constants(text: str) -> dict[str, int]:
    pattern = re.compile(
        r'constant\s+(\w+)\s*:\s*std_logic_vector\([^)]*\)\s*:=\s*X"([0-9A-Fa-f]+)"',
        re.IGNORECASE,
    )
    return {name: int(value, 16) for name, value in pattern.findall(text)}


def integer_constants(text: str) -> dict[str, int]:
    pattern = re.compile(
        r"constant\s+(\w+)\s*:\s*integer\s*:=\s*16#([0-9A-Fa-f]+)#",
        re.IGNORECASE,
    )
    return {name: int(value, 16) for name, value in pattern.findall(text)}


def main() -> int:
    doc = DOC_PATH.read_text(encoding="utf-8")
    stuff = STUFF_PATH.read_text(encoding="utf-8")
    top = TOP_PATH.read_text(encoding="utf-8")
    block_design = BD_PATH.read_text(encoding="utf-8")
    flow = FLOW_PATH.read_text(encoding="utf-8")
    register_bank = REGISTER_BANK_PATH.read_text(encoding="utf-8")
    record_builder = RECORD_BUILDER_PATH.read_text(encoding="utf-8")
    rows = table_rows(doc)
    errors: list[str] = []

    def require_row(
        address: int,
        register: str,
        access: str,
        *,
        size: str | None = None,
        default: str | None = None,
        info: tuple[str, ...] = (),
    ) -> None:
        matches = [row for row in rows.get(address, []) if row[2] == register]
        if len(matches) != 1:
            errors.append(
                f"0x{address:08X}: expected one '{register}' row, found {len(matches)}"
            )
            return
        row = matches[0]
        if row[4] != access:
            errors.append(
                f"0x{address:08X} {register}: access is {row[4]}, expected {access}"
            )
        if size is not None and row[3] != size:
            errors.append(
                f"0x{address:08X} {register}: size is {row[3]}, expected {size}"
            )
        if default is not None and row[5] != default:
            errors.append(
                f"0x{address:08X} {register}: default is {row[5]}, expected {default}"
            )
        for marker in info:
            if marker not in row[7]:
                errors.append(
                    f"0x{address:08X} {register}: missing note '{marker}'"
                )

    # The STUFF offsets are taken from the implementation, not duplicated here.
    stuff_constants = binary_constants(stuff) | hex_constants(stuff)
    board_registers = {
        "FANCTRL_OFFSET": ("fan_speed_reg", "R/W", "8b"),
        "FAN0SPD_OFFSET": ("fan0_rpm", "R/O", "12b"),
        "FAN1SPD_OFFSET": ("fan1_rpm", "R/O", "12b"),
        "HVBIAS_OFFSET": ("hvbias_en_reg", "R/W", "1b"),
        "MUXEN_OFFSET": ("mux_en_reg", "R/W", "2b"),
        "MUXA_OFFSET": ("mux_a_reg", "R/W", "2b"),
        "LED_OFFSET": ("stat_led_reg", "R/W", "6b"),
        "VER_OFFSET": ("version", "R/O", "28b"),
        "CORE_EN_LO_OFFSET": ("core_enable_reg", "R/W", "32b"),
        "CORE_EN_HI_OFFSET": ("core_enable_reg", "R/W", "8b"),
        "ST_ADHOC_OFFSET": ("adhoc_reg", "R/W", "8b"),
        "ST_CONFIG_OFFSET": ("st_config_reg", "R/W", "14b"),
        "ST_DELAY_OFFSET": ("signal_delay_reg", "R/W", "5b"),
        "ST_FILTER_OUTPUT_SEL_OFFSET": ("filt_out_selector_reg", "R/W", "2b"),
        "ST_RESET_COUNTERS_OFFSET": ("reset_st_counters_reg", "R/W", "1b"),
        "ST_AFE_COMP_ENABLE_LO_OFFSET": ("afe_comp_enable_reg", "R/W", "32b"),
        "ST_AFE_COMP_ENABLE_HI_OFFSET": ("afe_comp_enable_reg", "R/W", "8b"),
        "ST_INVERT_ENABLE_LO_OFFSET": ("invert_enable_reg", "R/W", "32b"),
        "ST_INVERT_ENABLE_HI_OFFSET": ("invert_enable_reg", "R/W", "8b"),
    }
    for constant, (register, access, size) in board_registers.items():
        if constant not in stuff_constants:
            errors.append(f"RTL is missing board-control constant {constant}")
            continue
        require_row(
            0x94000000 + stuff_constants[constant], register, access, size=size
        )

    identity_registers = {
        "FW_ID_MAGIC_OFFSET": (
            "fw_identity_magic",
            "FW_ID_MAGIC_C",
            0x44415048,
        ),
        "FW_ABI_VERSION_OFFSET": (
            "fw_abi_version",
            "FW_ABI_VERSION_C",
            0x00020000,
        ),
        "FW_VARIANT_ID_OFFSET": (
            "fw_variant_id",
            "FW_VARIANT_ID_C",
            0x00000001,
        ),
    }
    for offset_name, (register, value_name, expected_value) in identity_registers.items():
        if stuff_constants.get(offset_name) is None:
            errors.append(f"RTL is missing identity offset constant {offset_name}")
            continue
        if stuff_constants.get(value_name) != expected_value:
            actual = stuff_constants.get(value_name)
            errors.append(
                f"RTL identity constant {value_name} is {actual!r}, "
                f"expected 0x{expected_value:08X}"
            )
        require_row(
            0x94000000 + stuff_constants[offset_name],
            register,
            "R/O",
            size="32b",
            default=f"0x{expected_value:08X}",
        )
    if stuff_constants.get("FW_BUILD_ID_OFFSET") is None:
        errors.append("RTL is missing identity offset constant FW_BUILD_ID_OFFSET")
    else:
        require_row(
            0x94000000 + stuff_constants["FW_BUILD_ID_OFFSET"],
            "fw_build_id",
            "R/O",
            size="32b",
        )

    version_port = re.search(
        r"version\s*:\s*in\s+std_logic_vector\(27\s+downto\s+0\)",
        stuff,
        re.IGNORECASE,
    )
    if version_port is None:
        errors.append("self-trigger legacy version port is not 28 bits")
    build_id_port = re.search(
        r"build_id\s*:\s*in\s+std_logic_vector\(31\s+downto\s+0\)",
        stuff,
        re.IGNORECASE,
    )
    if build_id_port is None:
        errors.append("self-trigger board-control build_id port is not 32 bits")
    if re.search(
        r'X"0"\s*&\s*build_id\(27\s+downto\s+0\)', stuff, re.IGNORECASE
    ) is None:
        errors.append("self-trigger build ID readback is not zero-extended from 28 bits")
    build_id_generic = re.search(
        r"build_id\s*:\s*std_logic_vector\(31\s+downto\s+0\)",
        top,
        re.IGNORECASE,
    )
    if build_id_generic is None:
        errors.append("self-trigger top-level build_id generic is not 32 bits")
    if "set_property CONFIG.build_id $build_id_value $daphne_top_cell" not in block_design:
        errors.append("Vivado block design does not stamp the self-trigger build_id")
    if re.search(
        r'set\s+cfg\(v_build_id\)\s+"32\'h0\$version_git_sha"', flow
    ) is None:
        errors.append("Vivado flow does not zero-extend the seven-hex build ID")

    constants = integer_constants(register_bank)
    required_constants = {
        "CHANNEL_STRIDE_C",
        "THRESHOLD_OFFSET_C",
        "RECORD_COUNT_LO_C",
        "RECORD_COUNT_HI_C",
        "BUSY_COUNT_LO_C",
        "BUSY_COUNT_HI_C",
        "FULL_COUNT_LO_C",
        "FULL_COUNT_HI_C",
        "PRIMITIVE_BASE_C",
        "PRIMITIVE_STRIDE_C",
        "TCOUNT_LO_OFFSET_C",
        "TCOUNT_HI_OFFSET_C",
        "PCOUNT_LO_OFFSET_C",
        "PCOUNT_HI_OFFSET_C",
    }
    missing = sorted(required_constants - constants.keys())
    if missing:
        errors.append("RTL is missing register-bank constants: " + ", ".join(missing))
    else:
        base = 0xA0010000
        counter_layout = (
            ("RECORD_COUNT_LO_C", "record_count({})(31:0)"),
            ("RECORD_COUNT_HI_C", "record_count({})(63:32)"),
            ("BUSY_COUNT_LO_C", "busy_count({})(31:0)"),
            ("BUSY_COUNT_HI_C", "busy_count({})(63:32)"),
            ("FULL_COUNT_LO_C", "full_count({})(31:0)"),
            ("FULL_COUNT_HI_C", "full_count({})(63:32)"),
        )
        primitive_layout = (
            ("TCOUNT_LO_OFFSET_C", "TCount({})(31:0)"),
            ("TCOUNT_HI_OFFSET_C", "TCount({})(63:32)"),
            ("PCOUNT_LO_OFFSET_C", "PCount({})(31:0)"),
            ("PCOUNT_HI_OFFSET_C", "PCount({})(63:32)"),
        )
        for channel in range(40):
            channel_base = base + channel * constants["CHANNEL_STRIDE_C"]
            require_row(
                channel_base + constants["THRESHOLD_OFFSET_C"],
                f"threshold_xc({channel})",
                "R/W",
                default="0x0FFFFFFF",
            )
            for offset_name, register_template in counter_layout:
                require_row(
                    channel_base + constants[offset_name],
                    register_template.format(channel),
                    "R/O",
                    info=("0x94000038 bit 0", "0x0FFFFFFF"),
                )

            primitive_base = (
                base
                + constants["PRIMITIVE_BASE_C"]
                + channel * constants["PRIMITIVE_STRIDE_C"]
            )
            for offset_name, register_template in primitive_layout:
                require_row(
                    primitive_base + constants[offset_name],
                    register_template.format(channel),
                    "R/O",
                    info=("0x94000038",),
                )

    if "## Hermes/10G sender control" not in doc or "0x98000000" not in doc:
        errors.append("0x98000000 must be documented as Hermes/10G sender control")
    reserved_rows = [
        address for address in rows if 0xA0020000 <= address < 0xA0030000
    ]
    if reserved_rows:
        errors.append(
            "self-trigger map uses addresses in the reserved full-stream mux window: "
            + ", ".join(f"0x{address:08X}" for address in reserved_rows)
        )
    if "belongs to the full-stream input" not in doc or "unmapped in self-trigger" not in doc:
        errors.append("the reserved full-stream 0xA0020000 window is not documented")
    if re.search(
        r"assign_bd_address\s+-offset\s+0xA0020000\b", block_design, re.IGNORECASE
    ):
        errors.append("self-trigger Vivado block design maps the reserved 0xA0020000 window")
    if "threshold_xc(" in doc and "=0x3FF" in doc:
        errors.append("obsolete 10-bit threshold disable value 0x3FF remains")
    if re.search(r"\b(?:TCount|PCount)\([^\n]+\|\s*R/W\s*\|", doc):
        errors.append("read-only trigger/packet counter is marked R/W")
    if "Level-sensitive: write bit 0 to 1" not in doc:
        errors.append("counter-reset register is missing its level-sensitive procedure")

    width_match = re.search(
        r"LIVE_COUNTER_WIDTH_C\s*:\s*positive\s*:=\s*(\d+)", record_builder
    )
    if width_match is None:
        errors.append("record builder is missing LIVE_COUNTER_WIDTH_C")
    else:
        width = int(width_match.group(1))
        if f"{width}-bit values" not in doc:
            errors.append(f"map does not state the live counter width ({width} bits)")
        wrap_value = (1 << width) - 1
        if f"{wrap_value:,}" not in doc:
            errors.append(f"map does not state the live counter wrap value ({wrap_value:,})")

    # Five independent counter/state processes must honor the shared clear bit.
    if record_builder.count("reset_st_counters_i = '1'") < 5:
        errors.append("not every record-builder counter/state process honors counter reset")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Register-map consistency check: PASS (self-trigger mode)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
