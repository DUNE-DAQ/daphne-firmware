#!/usr/bin/env python3
"""Exercise production PDTS CDC helpers, AXI bank, register file and packet parser.

Uses unrelated/stopped clocks and real Vivado XPM models. The actual endpoint
core receives the actual transmitter's encoded idle stream. Physical MMCM/CDR
behavior is represented by clock stop/start and LOCKED, not an optical model.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

from run_grouped32_vendor_tests import host_link_environment

ROOT = Path(__file__).resolve().parents[2]


def ordered_sources():
    paths = sorted((ROOT / "ip_repo/daphne_ip/rtl/timing").glob("*.vhd"))
    by_unit = {}
    for path in paths:
        for name in re.findall(r"\b(?:entity|package)\s+(\w+)\s+is", path.read_text(), re.I):
            by_unit[name.lower()] = path
    ordered, pending = [], set(paths)
    while pending:
        ready = []
        for path in sorted(pending):
            source = re.sub(r"--[^\n]*", "", path.read_text())
            names = re.findall(r"\b(?:use|entity)\s+work\.(\w+)", source, re.I)
            if not any(by_unit.get(name.lower()) in pending - {path} for name in names):
                ready.append(path)
        if not ready:
            raise RuntimeError("Endpoint source dependency cycle")
        ordered.extend(ready)
        pending.difference_update(ready)
    return ordered


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--packet-ref", help="Use a committed packet parser for a negative/control experiment")
    parser.add_argument("--vivado-root", type=Path,
                        default=Path(os.environ.get("XILINX_VIVADO", "/opt/Xilinx/2026.1/Vivado")))
    args = parser.parse_args()
    build = args.output.resolve(); build.mkdir(parents=True, exist_ok=False)
    vivado = args.vivado_root.resolve(); xpm = vivado / "data/ip/xpm"
    tool_env, toolchain = host_link_environment("gcc")
    benches = ("pdts_control_cdc_tb", "pdts_core_cdc_tb")
    originals = ordered_sources() + [ROOT / "tests/logic" / (name + ".vhd") for name in benches]
    staged = []
    for original in originals:
        data = original.read_bytes()
        if args.packet_ref and original.name == "pdts_rx_pkt.vhd":
            data = subprocess.check_output(["git", "show", args.packet_ref + ":" + str(original.relative_to(ROOT))], cwd=ROOT)
        target = build / original.name; target.write_bytes(data); staged.append(target)
    vendor_sources = [xpm / "xpm_VCOMP.vhd", xpm / "xpm_cdc/hdl/xpm_cdc.sv", vivado / "data/verilog/src/glbl.v"]
    manifest = {"source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "packet_ref": args.packet_ref,
                "toolchain": toolchain, "coverage": __doc__, "result": "running"}
    hashed = [*staged, *vendor_sources, Path(__file__).resolve(),
              ROOT / "scripts/verification/run_grouped32_vendor_tests.py"]
    (build / "sources.sha256").write_text("".join(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p}\n" for p in hashed))
    (build / "xpm").mkdir(); library = "xpm=" + str(build / "xpm")
    try:
        with (build / "test.log").open("w") as log:
            def run(tool, *arguments):
                result = subprocess.run([str(vivado / "bin" / tool), *map(str, arguments)],
                                        cwd=build, env=tool_env, text=True,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                log.write(result.stdout); log.flush(); print(result.stdout, end="", flush=True)
                result.check_returncode()
                return result.stdout
            run("xvhdl", "--2008", "--work", library, vendor_sources[0])
            run("xvlog", "--sv", "--work", library, vendor_sources[1])
            run("xvlog", vendor_sources[2])
            run("xvhdl", "--2008", *staged)
            for bench in benches:
                run("xelab", "--debug", "typical", "--relax", "--mt", "4", "-L", library,
                    "-L", "unisims_ver", "work." + bench, "work.glbl", "--snapshot", bench)
                output = run("xsim", bench, "--runall")
                if bench + " PASS" not in output:
                    raise RuntimeError("Simulation ended without PASS: " + bench)
            manifest["result"] = "PASS"
    except Exception as error:
        manifest["result"] = "FAIL"; manifest["error"] = str(error)
        raise
    finally:
        (build / "summary.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
