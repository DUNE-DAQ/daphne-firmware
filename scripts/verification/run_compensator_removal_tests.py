#!/usr/bin/env python3
"""Verify hard removal of AFE compensation and its legacy read-zero controls."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]

def main():
    ghdl = os.environ.get("GHDL") or shutil.which("ghdl") or str(Path.home() / "tools/oss-cad-suite/bin/ghdl")
    sources = [
        "ip_repo/daphne_ip/rtl/daphne_package.vhd",
        "rtl/isolated/common/primitives/configurable_delay_line.vhd",
        "rtl/isolated/subsystems/trigger/validate/k_low_pass_filter.vhd",
        "rtl/isolated/subsystems/trigger/validate/st_xc.vhd",
        "ip_repo/daphne_ip/rtl/selftrig/peak_descriptor_import/Configurable_CFD.vhd",
        "ip_repo/daphne_ip/rtl/selftrig/xcorr_import/hpf_pedestal_recovery_filter_trigger.vhd",
        "rtl/isolated/subsystems/control/legacy_stuff_selftrigger_register_bank.vhd",
        "ip_repo/daphne_ip/rtl/config/fanmon.vhd",
        "ip_repo/daphne_ip/rtl/config/stuff.vhd",
        "tests/logic/stuff_axi_smoke_tb.vhd",
        "tests/logic/afe_compensator_removed_tb.vhd",
    ]
    with tempfile.TemporaryDirectory(prefix="daphne-no-comp-") as build:
        def run(*args):
            subprocess.run([ghdl, *args], cwd=build, check=True)
        run("-a", "--std=08", *(str(ROOT / p) for p in sources))
        for bench in ("afe_compensator_removed_tb", "stuff_axi_smoke_tb"):
            run("-e", "--std=08", bench)
            run("-r", "--std=08", bench, "--assert-level=error", "--ieee-asserts=disable-at-0", "--stop-time=11us")

if __name__ == "__main__":
    main()
