#!/usr/bin/env python3
"""Generate FuseSoC source-manifest cores from the existing Vivado Tcl flow."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TCL_PATH = ROOT / "xilinx" / "daphne3_ip_gen.tcl"
OUT_DIR = ROOT / "cores" / "generated"
OUT_PATH = OUT_DIR / "daphne3-ip.core"
CORE_PREFIX = "../../"


def sorted_relative_files(base: Path, pattern: str) -> list[str]:
    return sorted(
        p.relative_to(ROOT).as_posix() for p in base.rglob(pattern) if p.is_file()
    )


def basename_filtered(paths: list[str], ignored: set[str]) -> list[str]:
    return [p for p in paths if Path(p).name not in ignored]


def core_relative(paths: list[str]) -> list[str]:
    return [f"{CORE_PREFIX}{p}" for p in paths]


def extract_quoted_list(text: str, pattern: str) -> list[str]:
    match = re.search(pattern, text, flags=re.S)
    if not match:
        raise RuntimeError(f"Could not find pattern: {pattern}")
    return re.findall(r'"([^"]+)"', match.group(1))


def emit_fileset(
    lines: list[str],
    name: str,
    files: list[str],
    file_type: str,
    depends: list[str] | None = None,
) -> None:
    if not files and not depends:
        return
    lines.append(f"  {name}:")
    if depends:
        lines.append("    depend:")
        for dep in depends:
            lines.append(f"      - {dep}")
    if files:
        lines.append("    files:")
        for item in files:
            lines.append(f"      - {item}")
    lines.append(f"    file_type: {file_type}")


def main() -> None:
    tcl_text = TCL_PATH.read_text()

    rtl_ignored = set(
        extract_quoted_list(
            tcl_text,
            r"set vhdlFiles \[ignore_files \$vhdlFiles_aux \{(.*?)\}\]",
        )
    )
    wib_type_exceptions = set(
        extract_quoted_list(tcl_text, r"set wibTypeExceptionList \{(.*?)\}")
    )
    daq_xci_ignored = set(
        extract_quoted_list(
            tcl_text,
            r'set xciDAQFiles \[ignore_files \$xciDAQFiles_aux "(.*?)"\]',
        )
    )

    rtl_root = ROOT / "ip_repo" / "daphne3_ip" / "rtl"
    sim_root = ROOT / "ip_repo" / "daphne3_ip" / "sim"
    daq_root = (
        ROOT
        / "ip_repo"
        / "daphne3_ip"
        / "src"
        / "dune.daq_user_hermes_daphne_1.0"
        / "src"
    )
    ips_root = ROOT / "ip_repo" / "daphne3_ip" / "ips"

    rtl_vhdl = core_relative(
        basename_filtered(sorted_relative_files(rtl_root, "*.vhd"), rtl_ignored)
    )
    rtl_verilog = core_relative(sorted_relative_files(rtl_root, "*.v"))
    rtl_top = [f"{CORE_PREFIX}ip_repo/daphne3_ip/rtl/daphne3.vhd"]

    sim_vhdl = core_relative(sorted_relative_files(sim_root, "*.vhd"))
    sim_verilog = core_relative(sorted_relative_files(sim_root, "*.v"))

    daq_vhdl_all = sorted_relative_files(daq_root, "*.vhd")
    daq_vhdl_93 = [p for p in daq_vhdl_all if Path(p).name in wib_type_exceptions]
    daq_vhdl_2008 = [p for p in daq_vhdl_all if Path(p).name not in wib_type_exceptions]
    daq_vhdl_93 = core_relative(daq_vhdl_93)
    daq_vhdl_2008 = core_relative(daq_vhdl_2008)
    daq_verilog = core_relative(sorted_relative_files(daq_root, "*.v"))
    daq_tcl = core_relative(sorted_relative_files(daq_root, "*.tcl"))

    local_xci = (
        core_relative(sorted_relative_files(ips_root, "*.xci")) if ips_root.exists() else []
    )
    daq_xci = core_relative(
        basename_filtered(sorted_relative_files(daq_root, "*.xci"), daq_xci_ignored)
    )
    all_xci = sorted(set(local_xci + daq_xci))

    lines = [
        "CAPI=2:",
        "",
        "name: dune-daq:daphne:daphne3-ip:0.1.0",
        "description: Generated source manifest matching xilinx/daphne3_ip_gen.tcl",
        "provider:",
        "  name: local",
        "",
        "filesets:",
    ]

    emit_fileset(lines, "rtl_vhdl", rtl_vhdl, "vhdlSource")
    emit_fileset(lines, "rtl_verilog", rtl_verilog, "verilogSource")
    emit_fileset(lines, "rtl_top", rtl_top, "vhdlSource")
    emit_fileset(lines, "sim_vhdl", sim_vhdl, "vhdlSource")
    emit_fileset(lines, "sim_verilog", sim_verilog, "verilogSource")
    emit_fileset(lines, "daq_vhdl_93", daq_vhdl_93, "vhdlSource")
    emit_fileset(lines, "daq_vhdl_2008", daq_vhdl_2008, "vhdlSource-2008")
    emit_fileset(lines, "daq_verilog", daq_verilog, "verilogSource")
    emit_fileset(lines, "daq_tcl", daq_tcl, "tclSource")
    emit_fileset(lines, "daq_xci", all_xci, "xci")

    lines.extend(
        [
            "",
            "targets:",
            "  default: &default_target",
            "    description: Synthesizable DAPHNE3 PL source manifest",
            "    filesets:",
            "      - rtl_vhdl",
            "      - rtl_verilog",
            "      - daq_vhdl_93",
            "      - daq_vhdl_2008",
            "      - daq_verilog",
            "      - rtl_top",
            "  sim-src:",
            "    <<: *default_target",
            "    description: Source manifest including HDL test benches",
            "    filesets_append:",
            "      - sim_vhdl",
            "      - sim_verilog",
            "  vivado-src:",
            "    <<: *default_target",
            "    description: Source manifest plus Tcl/XCI collateral expected by Vivado",
        ]
    )

    if daq_tcl:
        lines.extend(["    filesets_append:", "      - daq_tcl"])
        if all_xci:
            lines.append("      - daq_xci")
    elif all_xci:
        lines.extend(["    filesets_append:", "      - daq_xci"])

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text("\n".join(lines) + "\n")
    print(f"Wrote {OUT_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
