#!/usr/bin/env python3
"""Test the real four-lane PCS wrapper with controllable PHY boundaries.

Runs locally using GHDL; no Vivado/IP simulation libraries are required. The
XXV and clock/common wrappers are behavioral boundaries, not models of GT lock,
CDR, shared-QPLL recovery, or vendor reset sequencing. The reset-wrapper boundary
deliberately passes asynchronous reset requests through, so the actual PCS RTL
must supply its promised asynchronous assertion and synchronous release.

Use --output NEW_DIRECTORY to retain generated stubs, source hashes, tool version
and the complete log. Default runs use a temporary directory. All real sources
are compiled unchanged, including the PCS IPbus control/frequency logic.
"""

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERMES = ROOT / "ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src"
CONTEXT = "library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;\n"
CONTROLS = """
library ieee; use ieee.std_logic_1164.all;
package hermes_phy_controls_pkg is
  signal tx_clocks_s, rx_clocks_s : std_logic_vector(3 downto 0) := (others=>'0');
  signal tx_done_s, rx_done_s, link_up_s : std_logic_vector(3 downto 0) := (others=>'0');
end package;
"""


def component_entity(text, name):
    match = re.search(rf"\bcomponent\s+{name}\b(.*?)\bend\s+component\s*;", text, re.I | re.S)
    if not match:
        raise RuntimeError(f"Missing PCS boundary declaration: {name}")
    return f"entity {name} is\n{match.group(1)}\nend entity;\n"


def boundaries(pcs):
    result = CONTROLS
    name = "xxv_ethernet_0"
    result += CONTEXT + "use work.hermes_phy_controls_pkg.all;\n" + component_entity(pcs, name)
    result += f"""
architecture controlled of {name} is
  signal lane_bits : std_logic_vector(1 downto 0);
  signal lane : natural range 0 to 3 := 0;
begin
  -- Physical input bits encode lane ID; this independently checks every
  -- generated instance's SFP/XGMII/clock association in the real PCS wrapper.
  lane_bits <= gt_rxp_in & gt_rxn_in;
  lane <= to_integer(unsigned(lane_bits));
  tx_mii_clk_0 <= tx_clocks_s(lane);
  rx_clk_out_0 <= rx_clocks_s(lane);
  rxrecclkout_0 <= rx_clocks_s(lane);
  gt_reset_tx_done_out_0 <= tx_done_s(lane);
  gt_reset_rx_done_out_0 <= rx_done_s(lane);
  stat_rx_status_0 <= link_up_s(lane);
  gtwiz_reset_qpll0reset_out <= '0';
  gtwiz_reset_qpll1reset_out <= '0';
  gtpowergood_out_0 <= '1';
  rx_mii_d_0 <= std_logic_vector(to_unsigned(16#CAFE00# + lane, 64));
  rx_mii_c_0 <= std_logic_vector(to_unsigned(16#A0# + lane, 8));
  gt_txp_out <= tx_mii_d_0(0);
  gt_txn_out <= tx_mii_c_0(0);
  -- Sample after delta-cycle propagation at every RX-clock transition.
  process
  begin
    wait on rx_clocks_s;
    wait for 1 ps;
    assert rx_core_clk_0 = rx_clocks_s(lane)
      report "XXV RX core clock connected to another lane/domain" severity failure;
  end process;
end architecture;
"""
    name = "xxv_ethernet_0_reset_wrapper"
    result += CONTEXT + component_entity(pcs, name) + f"""
architecture asynchronous_boundary of {name} is
begin
  tx_core_reset_out <= sys_reset or tx_core_reset_in or not gt_tx_reset_in;
  rx_core_reset_out <= sys_reset or rx_core_reset_in or not gt_rx_reset_in;
  rx_serdes_reset_out <= sys_reset or rx_core_reset_in or not gt_rx_reset_in;
  usr_tx_reset <= sys_reset or tx_core_reset_in or not gt_tx_reset_in;
  usr_rx_reset <= sys_reset or rx_core_reset_in or not gt_rx_reset_in;
  gtwiz_reset_all <= sys_reset;
  gtwiz_reset_tx_datapath_out <= '0';
  gtwiz_reset_rx_datapath_out <= '0';
  process
  begin
    wait on gt_rxusrclk2, rx_core_clk;
    wait for 1 ps;
    assert rx_core_clk = gt_rxusrclk2
      report "Reset wrapper RX core and recovered clocks differ" severity failure;
  end process;
end architecture;
"""
    for name in ("xxv_ethernet_0_common_wrapper", "ultrascale_125_gthe4_common_wrapper"):
        result += CONTEXT + component_entity(pcs, name) + f"""
architecture clock_boundary of {name} is
begin
  qpll0lock <= not qpll0reset;
  qpll1lock <= not qpll1reset;
  qpll0outclk <= (qpll0outclk'range => refclk);
  qpll1outclk <= (qpll1outclk'range => refclk);
  qpll0outrefclk <= (qpll0outrefclk'range => refclk);
  qpll1outrefclk <= (qpll1outrefclk'range => refclk);
end architecture;
"""
    name = "xxv_ethernet_0_clocking_wrapper"
    clock_source = (HERMES / "deimos" / f"{name}.vhd").read_text()
    match = re.search(rf"\bentity\s+{name}\s+is\b.*?\bend\s+entity\s+{name}\s*;", clock_source, re.I | re.S)
    if not match:
        raise RuntimeError("Missing reference-clock wrapper entity declaration")
    result += CONTEXT + match.group(0) + f"""
architecture clock_boundary of {name} is
begin
  gt_ref_clk <= ge_ref_clk_p;
  gt_ref_clk_out <= ge_ref_clk_p;
end architecture;
"""
    return result


def test(build, ghdl):
    sources = [HERMES / path for path in (
        "udp_core_lib/udp_core_pkg.vhd", "axi4_lib/axi4s_pkg.vhd",
        "axi4_lib/axi4lite_pkg.vhd", "ipbus/ipbus_package.vhd",
        "ipbus/ipbus_reg_types.vhd", "deimos/ipbus_decode_ultrascale_pcs_pma.vhd",
        "deimos/xgmii_pkg.vhd", "deimos/freq_pkg.vhd", "ipbus/ipbus_fabric_sel.vhd",
        "ipbus/ipbus_ctrlreg_v.vhd", "ipbus/freq_ctr_div.vhd", "ipbus/ipbus_freq_ctr.vhd",
    )]
    pcs = HERMES / "deimos/ultrascale_pcs_pma.vhd"
    bench = ROOT / "tests/logic/hermes_phy_clock_reset_tb.vhd"
    stub = build / "phy_boundaries.vhd"
    stub.write_text(boundaries(pcs.read_text()))
    marker = build / "library_marker.vhd"
    marker.write_text("package library_marker is end package;\n")
    unisim = build / "vcomponents.vhd"
    unisim.write_text("package vcomponents is end package;\n")
    xpm_models = [ROOT / "tests/logic/models" / name for name in (
        "xpm_vcomponents.vhd", "xpm_cdc_array_single.vhd")]
    hashed = [*sources, *xpm_models, pcs, bench, stub, Path(__file__).resolve(),
              HERMES / "deimos/xxv_ethernet_0_clocking_wrapper.vhd"]
    (build / "sources.sha256").write_text("".join(
        f"{hashlib.sha256(source.read_bytes()).hexdigest()}  {source}\n" for source in hashed))
    flags = ["--std=08", "-fsynopsys", "-frelaxed-rules"]
    with (build / "test.log").open("w") as log:
        def run(*args):
            result = subprocess.run([ghdl, *args], cwd=build, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            log.write(result.stdout)
            log.flush()
            print(result.stdout, end="")
            result.check_returncode()
            return result.stdout
        version = run("--version")
        (build / "ghdl-version.txt").write_text(version)
        run("-a", *flags, "--work=unisim", str(unisim))
        run("-a", *flags, "--work=xpm", *(str(source) for source in xpm_models))
        for library in ("deimos", "ipbus", "udp_core_lib", "axi4_lib"):
            run("-a", *flags, f"--work={library}", str(marker))
        run("-a", *flags, *(str(source) for source in sources), str(stub), str(pcs), str(bench))
        run("-e", *flags, "hermes_phy_clock_reset_tb")
        output = run("-r", *flags, "hermes_phy_clock_reset_tb", "--assert-level=error",
                     "--ieee-asserts=disable-at-0", "--stop-time=5us")
        if "hermes_phy_clock_reset_tb PASS" not in output:
            raise RuntimeError("Simulation ended without reaching the PASS marker")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New directory for retained test evidence")
    args = parser.parse_args()
    ghdl = os.environ.get("GHDL") or shutil.which("ghdl") or str(Path.home() / "tools/oss-cad-suite/bin/ghdl")
    if args.output:
        build = args.output.resolve()
        build.mkdir(parents=True, exist_ok=False)
        test(build, ghdl)
        print(f"Evidence: {build}")
    else:
        with tempfile.TemporaryDirectory(prefix="daphne-phy-clock-reset-") as directory:
            test(Path(directory), ghdl)


if __name__ == "__main__":
    main()
