#!/usr/bin/env python3
"""Check eight concurrent readout lanes, whole-packet credits and round-robin order."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]

def main():
    ghdl = os.environ.get("GHDL") or shutil.which("ghdl") or str(Path.home() / "tools/oss-cad-suite/bin/ghdl")
    sources = ["ip_repo/daphne_ip/rtl/daphne_package.vhd",
               "rtl/isolated/common/daphne_subsystem_pkg.vhd",
               "rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd",
               "tests/logic/multilane_readout_mux_tb.vhd"]
    with tempfile.TemporaryDirectory(prefix="daphne-eight-lanes-") as build:
        def run(*args):
            subprocess.run([ghdl, *args], cwd=build, check=True)
        run("-a", "--std=08", *(str(ROOT / p) for p in sources))
        run("-e", "--std=08", "multilane_readout_mux_tb")
        run("-r", "--std=08", "multilane_readout_mux_tb", "--assert-level=error")

if __name__ == "__main__":
    main()
