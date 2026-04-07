#!/usr/bin/env python3
"""Generate FuseSoC source-manifest cores from the existing Vivado Tcl flow."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TCL_PATH = ROOT / "xilinx" / "daphne_ip_gen.tcl"
OUT_PATH = ROOT / "daphne-ip.core"
EXPORT_OUT_PATH = ROOT / "daphne-ip-export.core"
LEGACY_FLOW_SUPPORT_PATH = ROOT / "xilinx" / "legacy_flow_support_sources.txt"
DEFAULT_BOARD_MANIFEST = ROOT / "boards" / "k26c" / "board.yml"
CORE_PREFIX = ""


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


def extract_quoted_list_any(text: str, patterns: list[str]) -> list[str]:
    for pattern in patterns:
        match = re.search(pattern, text, flags=re.S)
        if match:
            return re.findall(r'"([^"]+)"', match.group(1))
    joined = " | ".join(patterns)
    raise RuntimeError(f"Could not find any expected pattern: {joined}")


def extract_default_string(text: str, pattern: str) -> str:
    match = re.search(pattern, text, flags=re.S)
    if not match:
        raise RuntimeError(f"Could not find pattern: {pattern}")
    return match.group(1)


def load_manifest_lines(path: Path) -> list[str]:
    entries: list[str] = []
    for raw_line in path.read_text().splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if line:
            entries.append(line)
    return entries


def expand_manifest_vhdl_entries(entries: list[str]) -> list[str]:
    expanded: list[str] = []
    for entry in entries:
        resolved = ROOT / entry
        if resolved.is_dir():
            expanded.extend(
                path
                for path in sorted_relative_files(resolved, "*.vhd")
                if "/validate/" not in path
                and not path.endswith("_validate_stub.vhd")
                and not path.endswith("legacy_public_top_bridge.vhd")
            )
        elif resolved.is_file():
            expanded.append(entry)
        else:
            raise RuntimeError(f"Missing legacy support entry: {resolved}")
    return sorted(set(expanded))


def load_manifest_scalar(path: Path, key: str) -> str | None:
    if not path.exists():
        return None
    pattern = re.compile(rf"^\s*{re.escape(key)}:\s*(.*?)\s*$")
    for raw_line in path.read_text().splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        match = pattern.match(line)
        if not match:
            continue
        value = match.group(1).strip().strip("\"'")
        return value or None
    return None


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


def emit_core(
    out_path: Path,
    name: str,
    description: str,
    filesets: list[tuple[str, list[str], str, list[str] | None]],
    target_lines: list[str],
) -> None:
    lines = [
        "CAPI=2:",
        "",
        f"name: {name}",
        f"description: {description}",
        "provider:",
        "  name: local",
        "",
        "filesets:",
    ]

    for fileset_name, files, file_type, depends in filesets:
        emit_fileset(lines, fileset_name, files, file_type, depends)

    lines.extend(["", "targets:"])
    lines.extend(target_lines)
    out_path.write_text("\n".join(lines) + "\n")
    print(f"Wrote {out_path.relative_to(ROOT)}")


def main() -> None:
    tcl_text = TCL_PATH.read_text()
    extra_rtl_vhdl = expand_manifest_vhdl_entries(load_manifest_lines(LEGACY_FLOW_SUPPORT_PATH))

    board_top_hdl = load_manifest_scalar(DEFAULT_BOARD_MANIFEST, "ip_top_hdl_file")
    if not board_top_hdl:
        board_top_hdl = load_manifest_scalar(DEFAULT_BOARD_MANIFEST, "public_top_hdl_file")
    if board_top_hdl:
        default_top_vhdl = board_top_hdl
        default_top_basename = Path(board_top_hdl).name
    else:
        default_top_basename = extract_default_string(
            tcl_text,
            r'set daphne_ip_top_hdl_file \[file normalize \[daphne_get_env_or_default DAPHNE_IP_TOP_HDL_FILE \[file join \$daphne_ip_root "rtl" "([^"]+)"\]\]\]',
        )
        default_top_vhdl = f"ip_repo/daphne_ip/rtl/{default_top_basename}"
    board_top_module = load_manifest_scalar(DEFAULT_BOARD_MANIFEST, "ip_top_module")
    if not board_top_module:
        board_top_module = load_manifest_scalar(DEFAULT_BOARD_MANIFEST, "public_top_module")
    default_top_module = (
        board_top_module
        if board_top_module
        else extract_default_string(
            tcl_text,
            r'set daphne_ip_top_module \[daphne_get_env_or_default DAPHNE_IP_TOP_MODULE "([^"]+)"\]',
        )
    )
    rtl_ignored = set(
        extract_quoted_list_any(
            tcl_text,
            [
                r"set vhdlFiles \[ignore_files \$vhdlFiles_aux \{(.*?)\}\]",
                r"set vhdlFiles \[ignore_files \$vhdlFiles_aux \[list (.*?)\]\]",
            ],
        )
    )
    rtl_ignored.add(default_top_basename)
    wib_type_exceptions = set(
        extract_quoted_list(tcl_text, r"set wibTypeExceptionList \{(.*?)\}")
    )
    daq_xci_ignored = set(
        extract_quoted_list_any(
            tcl_text,
            [
                r'set xciDAQFiles \[ignore_files \$xciDAQFiles_aux "(.*?)"\]',
                r"set xciDAQFiles \[ignore_files \$xciDAQFiles_aux \{(.*?)\}\]",
            ],
        )
    )

    rtl_root = ROOT / "ip_repo" / "daphne_ip" / "rtl"
    sim_root = ROOT / "ip_repo" / "daphne_ip" / "sim"
    daq_root = (
        ROOT
        / "ip_repo"
        / "daphne_ip"
        / "src"
        / "dune.daq_user_hermes_daphne_1.0"
        / "src"
    )
    ips_root = ROOT / "ip_repo" / "daphne_ip" / "ips"

    rtl_vhdl = core_relative(
        extra_rtl_vhdl
        + basename_filtered(sorted_relative_files(rtl_root, "*.vhd"), rtl_ignored)
    )
    rtl_verilog = core_relative(sorted_relative_files(rtl_root, "*.v"))
    rtl_top = [f"{CORE_PREFIX}{default_top_vhdl}"]

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

    emit_core(
        OUT_PATH,
        "dune-daq:daphne:daphne-ip:0.1.0",
        "Generated source manifest matching xilinx/daphne_ip_gen.tcl",
        [
            ("rtl_vhdl", rtl_vhdl, "vhdlSource", None),
            ("rtl_verilog", rtl_verilog, "verilogSource", None),
            ("rtl_top", rtl_top, "vhdlSource", None),
            ("sim_vhdl", sim_vhdl, "vhdlSource", None),
            ("sim_verilog", sim_verilog, "verilogSource", None),
            ("daq_vhdl_93", daq_vhdl_93, "vhdlSource", None),
            ("daq_vhdl_2008", daq_vhdl_2008, "vhdlSource-2008", None),
            ("daq_verilog", daq_verilog, "verilogSource", None),
            ("daq_tcl", daq_tcl, "tclSource", None),
            ("daq_xci", all_xci, "xci", None),
        ],
        [
            "  default: &default_target",
            f"    description: Synthesizable {default_top_module} PL source manifest",
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
            *(
                ["    filesets_append:", "      - daq_tcl"]
                + (["      - daq_xci"] if all_xci else [])
                if daq_tcl
                else (["    filesets_append:", "      - daq_xci"] if all_xci else [])
            ),
        ],
    )

    emit_core(
        EXPORT_OUT_PATH,
        "dune-daq:daphne:daphne-ip-export:0.1.0",
        "Generated export-only staging manifest matching xilinx/daphne_ip_gen.tcl",
        [
            ("rtl_vhdl_export", rtl_vhdl, "user", None),
            ("rtl_verilog_export", rtl_verilog, "user", None),
            ("rtl_top_export", rtl_top, "user", None),
            ("daq_vhdl_93_export", daq_vhdl_93, "user", None),
            ("daq_vhdl_2008_export", daq_vhdl_2008, "user", None),
            ("daq_verilog_export", daq_verilog, "user", None),
            ("daq_tcl_export", daq_tcl, "user", None),
            ("daq_xci_export", all_xci, "user", None),
        ],
        [
            "  default:",
            "    description: Export-only manifest that stages legacy HDL/Tcl/XCI collateral without loading it as active design source",
            "    filesets:",
            "      - rtl_vhdl_export",
            "      - rtl_verilog_export",
            "      - daq_vhdl_93_export",
            "      - daq_vhdl_2008_export",
            "      - daq_verilog_export",
            "      - rtl_top_export",
            *(
                ["      - daq_tcl_export"] if daq_tcl else []
            ),
            *(
                ["      - daq_xci_export"] if all_xci else []
            ),
        ],
    )


if __name__ == "__main__":
    main()
