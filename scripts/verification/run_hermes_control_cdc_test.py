#!/usr/bin/env python3
"""Exercise the actual Hermes mux with unrelated clocks and CDC updates.

Local GHDL uses behavioral XPM handshake models; --vendor uses the installed
Vivado XPM models and simulator. Neither simulation models metastability.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from run_grouped32_vendor_tests import host_link_environment

ROOT = Path(__file__).resolve().parents[2]
HERMES = ROOT / "ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src"


def test(build, vendor):
    sources = [HERMES / name for name in (
        "ipbus/ipbus_package.vhd", "ipbus/ipbus_reg_types.vhd", "ipbus/ipbus_ctrlreg_v.vhd",
        "deimos/tx_mux_decl.vhd", "deimos/tx_src_sel.vhd", "deimos/tx_mux_out.vhd")]
    sources.append(ROOT / "tests/logic/hermes_control_cdc_tb.vhd")
    tool_env = os.environ.copy()
    if vendor:
        tool_env, toolchain = host_link_environment("gcc")
        (build / "toolchain.json").write_text(json.dumps(toolchain, indent=2) + "\n")
    with (build / "test.log").open("w") as log:
        def run(*args):
            result = subprocess.run([str(arg) for arg in args], cwd=build, text=True, env=tool_env,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            log.write(result.stdout); log.flush(); print(result.stdout, end="")
            result.check_returncode()
            return result.stdout
        if vendor:
            vivado = Path(vendor).resolve()
            xpm = vivado / "data/ip/xpm"
            xpm_sources = [xpm / "xpm_VCOMP.vhd", xpm / "xpm_cdc/hdl/xpm_cdc.sv"]
            (build / "xpm").mkdir()
            library = f"xpm={build / 'xpm'}"
            run(vivado / "bin/xvhdl", "--2008", "--work", library, xpm_sources[0])
            run(vivado / "bin/xvlog", "--sv", "--work", library, xpm_sources[1])
            run(vivado / "bin/xvlog", vivado / "data/verilog/src/glbl.v")
            # The source's historical 'library ipbus' is only a library marker;
            # packages and entities are consistently compiled into work.
            marker = build / "library_marker.vhd"
            marker.write_text("package library_marker is end package;\n")
            run(vivado / "bin/xvhdl", "--2008", "--work", "ipbus", marker)
            run(vivado / "bin/xvhdl", "--2008", *sources)
            run(vivado / "bin/xelab", "--debug", "typical", "--relax", "--mt", "4", "-L", library,
                "-L", "unisims_ver", "work.hermes_control_cdc_tb", "work.glbl", "--snapshot", "control_cdc")
            output = run(vivado / "bin/xsim", "control_cdc", "--runall")
        else:
            ghdl = os.environ.get("GHDL") or shutil.which("ghdl")
            if not ghdl:
                raise RuntimeError("GHDL is not available")
            xpm_sources = [ROOT / "tests/logic/models" / name for name in (
                "xpm_vcomponents.vhd", "xpm_cdc_handshake.vhd")]
            marker = build / "library_marker.vhd"
            marker.write_text("package library_marker is end package;\n")
            run(ghdl, "--version")
            flags = ("--std=08", "-frelaxed-rules")
            run(ghdl, "-a", *flags, "--work=ipbus", marker)
            run(ghdl, "-a", *flags, "--work=xpm", *xpm_sources)
            run(ghdl, "-a", *flags, *sources)
            run(ghdl, "-e", *flags, "hermes_control_cdc_tb")
            output = run(ghdl, "-r", *flags, "hermes_control_cdc_tb", "--assert-level=error", "--ieee-asserts=disable-at-0")
        hashed = [*sources, *xpm_sources, Path(__file__).resolve(),
                  ROOT / "scripts/verification/run_grouped32_vendor_tests.py"]
        (build / "sources.sha256").write_text("".join(
            f"{hashlib.sha256(source.read_bytes()).hexdigest()}  {source}\n" for source in hashed))
        if "hermes_control_cdc_tb PASS" not in output:
            raise RuntimeError("Simulation ended without PASS")
        (build / "result.txt").write_text("PASS\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New directory for test evidence")
    parser.add_argument("--vendor", type=Path, help="Vivado install directory to use real XPM models")
    args = parser.parse_args()
    if args.output:
        build = args.output.resolve(); build.mkdir(parents=True, exist_ok=False)
        test(build, args.vendor)
    else:
        with tempfile.TemporaryDirectory(prefix="daphne-hermes-control-cdc-") as directory:
            test(Path(directory), args.vendor)


if __name__ == "__main__":
    main()
