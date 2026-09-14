#!/usr/bin/env python3
"""Check the real package source staging and active K26C board hookup.

Vivado API recording stubs capture the actual packager file groups through port
inference. GHDL then analyzes/elaborates the copied model and shell against the
staged support closure. Vendor IP generation and physical routing are not modeled.
"""
from pathlib import Path
import os
import re
import shutil
import subprocess
import sys
import tempfile
import tkinter

ROOT = Path(__file__).resolve().parents[2]
SFP_PORTS = {f"eth{i}_{suffix}" for i in range(4)
             for suffix in ("rx_p", "rx_n", "tx_p", "tx_n", "tx_dis")}


def entity_ports(path, entity):
    text = path.read_text()
    declaration = re.search(rf"\bentity\s+{entity}\s+is\b.*?\bend\s+(?:entity\s+)?{entity}\s*;",
                            text, re.I | re.S).group(0)
    return {
        name: (direction, re.sub(r"\s+", "", kind.lower()))
        for name, direction, kind in re.findall(r"\b(eth\w+)\s*:\s*(in|out)\s+([^;]+);", declaration, re.I)
    }


def main():
    shell = ROOT / "rtl/isolated/tops/k26c_board_shell.vhd"
    wrapper = ROOT / "ip_repo/daphne_ip/rtl/daphne_selftrigger_top.vhd"
    shell_ports = entity_ports(shell, "k26c_board_shell")
    wrapper_ports = entity_ports(wrapper, "daphne_selftrigger_top")
    assert SFP_PORTS <= shell_ports.keys(), "Selected shell is missing SFP ports"
    assert shell_ports == wrapper_ports, "Packaged model and inferred shell interfaces differ"
    xdc = ROOT / "xilinx/daphne_selftrigger_pin_map.xdc"
    active_xdc = [(number, line) for number, line in enumerate(xdc.read_text().splitlines(), 1)
                  if line.strip() and not line.lstrip().startswith("#")]
    bad_inline_comments = [number for number, line in active_xdc if re.search(r"\]\s+#", line)]
    unsupported_control = [number for number, line in active_xdc
                           if re.match(r"\s*(if|for|foreach|while|switch)\b", line)]
    assert not bad_inline_comments, f"XDC inline comments need a semicolon on lines {bad_inline_comments}"
    assert not unsupported_control, f"XDC control flow is unsupported on lines {unsupported_control}"
    assert "create_clock -name eth_refclk -period 6.400 [get_ports GTH0_REFCLK_P]" in xdc.read_text()
    with tempfile.TemporaryDirectory(prefix="daphne-four-sfp-package-") as directory:
        stage = Path(directory) / "ip_repo/daphne_ip"
        shutil.copytree(ROOT / "ip_repo/daphne_ip/rtl", stage / "rtl")
        hermes = Path("src/dune.daq_user_hermes_daphne_1.0/src/deimos/daphne_top.vhd")
        (stage / hermes).parent.mkdir(parents=True)
        shutil.copy2(ROOT / "ip_repo/daphne_ip" / hermes, stage / hermes)
        # Avoid inherited caller overrides changing the board/source selection.
        interp = tkinter.Tcl()
        for key in os.environ:
            if key.startswith("DAPHNE_"):
                interp.call("unset", "-nocomplain", f"env({key})")
        interp.call("set", "argv", (str(ROOT), str(stage), " ".join(shell_ports)))
        interp.call("source", str(ROOT / "tests/logic/models/four_sfp_packaging_contract.tcl"))
        rows = [line.split("\t") for line in (stage / "packaging-files.tsv").read_text().splitlines()]
        for group in ("xilinx_anylanguagesynthesis", "xilinx_anylanguagebehavioralsimulation"):
            assert ["MODEL", group, "daphne_selftrigger_top"] in rows, "Compatibility model changed"
            paths = {Path(path) for kind, name, path in rows if kind == "FILE" and name == group}
            assert stage / "rtl/daphne_selftrigger_top.vhd" in paths, "Model missing from package"
            assert stage / "src/generated_support/k26c_board_shell.vhd" in paths, "Shell missing from package"
            assert shell in paths, "Selected top missing from package"
        assert (stage / "rtl/daphne_selftrigger_top.vhd").read_bytes() == wrapper.read_bytes()
        subprocess.run([sys.executable, str(ROOT / "scripts/verification/run_board_readout_elaboration.py"),
                        "--packaged-root", str(stage)], check=True)
    print("PASS actual package staging: matching 20 SFP ports, XDC syntax contract, model/file groups, copied wrapper and shell elaboration")


if __name__ == "__main__":
    main()
