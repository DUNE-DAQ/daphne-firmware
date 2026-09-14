#!/usr/bin/env python3
"""Test the actual UDP top's configuration CDC with real Vivado XPM models.

The TX datapath is an observation boundary exposing its actual header inputs.
Disabled RX/FIFO branches have failing stubs, proving they are not exercised.
This test covers configuration delivery and reset; it does not emit wire packets.
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
HERMES = ROOT / "ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src"
CONTEXT = """library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
use work.udp_core_pkg.all; use work.axi4s_pkg.all; use work.axi4lite_pkg.all;
use work.common_stfc_pkg.all;
"""


def boundary(source, name):
    match = re.search(rf"\bentity\s+{name}\s+is\b.*?\bend\s+entity(?:\s+{name})?\s*;", source, re.I | re.S)
    if not match:
        raise RuntimeError("Missing boundary entity " + name)
    text = CONTEXT + match.group(0) + f"\narchitecture observation of {name} is begin\n"
    if name == "tx_path_top":
        text += """
  -- Observe actual configuration ports; no mailbox or CDC logic is modelled.
  tx_out_axi4s_s_mosi.tdata(185 downto 0) <= dst_mac_addr & dst_ip_addr & dst_port_addr &
    packet_type & ip_ver_hdr_len & ip_service & ip_ident_count & ip_flag_frag &
    ip_time_to_live & ip_protocol & ifg_val & tuser_dst_prt & tuser_src_prt;
  tx_out_axi4s_s_mosi.tdata(c_axi4s_max_tdata_nof_bytes*8-1 downto 186) <= (others=>'0');
  tx_out_axi4s_s_mosi.tvalid <= '0'; tx_out_axi4s_s_mosi.tlast <= '0';
  tx_out_axi4s_s_mosi.tkeep <= (others=>'0'); tx_out_axi4s_s_mosi.tid <= (others=>'0');
  tx_out_axi4s_s_mosi.tuser <= (others=>'0');
  udp_axi4s_s_miso <= c_axi4s_miso_default;
  tx_udp_count <= (others=>'0'); tx_arp_count <= (others=>'0'); tx_ping_count <= (others=>'0');
"""
    else:
        text += '  assert false report "Disabled datapath boundary unexpectedly elaborated" severity failure;\n'
    return text + "end architecture;\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="New evidence directory")
    parser.add_argument("--vivado-root", type=Path,
                        default=Path(os.environ.get("XILINX_VIVADO", "/opt/Xilinx/2026.1/Vivado")))
    parser.add_argument("--dut-ref", help="Use a committed UDP top for a negative/control experiment")
    args = parser.parse_args()
    build = args.output.resolve(); build.mkdir(parents=True, exist_ok=False)
    vivado = args.vivado_root.resolve(); xpm = vivado / "data/ip/xpm"
    tool_env, toolchain = host_link_environment("gcc")
    originals = [HERMES / name for name in (
        "udp_core_lib/udp_core_pkg.vhd", "axi4_lib/axi4s_pkg.vhd", "axi4_lib/axi4lite_pkg.vhd",
        "common_stfc_lib/common_stfc_pkg.vhd")]
    boundary_sources = [HERMES / name for name in (
        "axi4_lib/axi4s_xpm_fifo.vhd", "udp_core_lib/rx_path_top.vhd",
        "udp_core_lib/udp_axi4s_pipe.vhd", "udp_core_lib/tx_path_top.vhd")]
    boundary_text = "".join(boundary(source.read_text(), name) for source, name in zip(
        boundary_sources, ("axi4s_fifo", "rx_path_top", "udp_axi4s_pipe", "tx_path_top")))
    stubs = build / "datapath_observation_boundaries.vhd"; stubs.write_text(boundary_text)
    source = HERMES / "udp_core_lib/udp_core_xml_mm_scalable_top.vhd"
    source_bytes = subprocess.check_output(["git", "show", args.dut_ref + ":" + str(source.relative_to(ROOT))], cwd=ROOT) if args.dut_ref else source.read_bytes()
    dut = build / source.name; dut.write_bytes(source_bytes)
    bench = ROOT / "tests/logic/hermes_network_config_cdc_tb.vhd"
    staged = []
    for original in [*originals, bench]:
        target = build / original.name; target.write_bytes(original.read_bytes()); staged.append(target)
    vendor_sources = [xpm / "xpm_VCOMP.vhd", xpm / "xpm_cdc/hdl/xpm_cdc.sv", vivado / "data/verilog/src/glbl.v"]
    manifest = {"dut_ref": args.dut_ref, "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "toolchain": toolchain, "coverage": __doc__, "result": "running"}
    hashed = [*staged, dut, stubs, *boundary_sources, *vendor_sources, Path(__file__).resolve(),
              ROOT / "scripts/verification/run_grouped32_vendor_tests.py"]
    (build / "sources.sha256").write_text("".join(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p}\n" for p in hashed))
    marker = build / "library_marker.vhd"; marker.write_text("package library_marker is end package;\n")
    (build / "xpm").mkdir(); library = "xpm=" + str(build / "xpm")
    try:
        with (build / "test.log").open("w") as log:
            def run(tool, *args):
                result = subprocess.run([str(vivado / "bin" / tool), *map(str, args)], cwd=build, env=tool_env,
                                        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                log.write(result.stdout); log.flush(); print(result.stdout, end="", flush=True)
                result.check_returncode()
                return result.stdout
            run("xvhdl", "--2008", "--work", library, vendor_sources[0])
            run("xvlog", "--sv", "--work", library, vendor_sources[1])
            run("xvlog", vendor_sources[2])
            for name in ("udp_core_lib", "axi4_lib", "common_stfc_lib"):
                run("xvhdl", "--2008", "--work", name, marker)
            run("xvhdl", "--2008", *staged[:-1], stubs, dut, staged[-1])
            run("xelab", "--debug", "typical", "--relax", "--mt", "4", "-L", library, "-L", "unisims_ver",
                "work.hermes_network_config_cdc_tb", "work.glbl", "--snapshot", "network_config_cdc")
            output = run("xsim", "network_config_cdc", "--runall")
            if "hermes_network_config_cdc_tb PASS" not in output:
                raise RuntimeError("Simulation ended without PASS")
            manifest["result"] = "PASS"
    except Exception as error:
        manifest["result"] = "FAIL"; manifest["error"] = str(error)
        raise
    finally:
        (build / "summary.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
