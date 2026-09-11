#!/usr/bin/env python3
"""Elaborate board readout wiring using real entities and hardware-boundary stubs.

The frontend, timing, analog, composable-core and imported-Hermes implementations
are replaced by empty architectures generated from their actual entity ports.
This checks interface widths/binding, not PHY, trigger, or transport behavior.
"""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packaged-root", type=Path, help="Use the actual packager staging output")
    args = parser.parse_args()
    def source_path(relative):
        if args.packaged_root is None:
            return ROOT / relative
        if relative.startswith("rtl/isolated/"):
            path = args.packaged_root / "src/generated_support" / Path(relative).name
        else:
            path = args.packaged_root / Path(relative).relative_to("ip_repo/daphne_ip")
        if not path.is_file():
            raise RuntimeError(f"Source missing from packaged staging: {path}")
        return path
    ghdl = os.environ.get("GHDL") or shutil.which("ghdl") or str(Path.home() / "tools/oss-cad-suite/bin/ghdl")
    boundaries = {
        "daphne_top": "ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/deimos/daphne_top.vhd",
        "daphne_composable_core_top": "rtl/isolated/tops/daphne_composable_core_top.vhd",
        "k26c_board_frontend_plane": "rtl/isolated/subsystems/frontend/k26c_board_frontend_plane.vhd",
        "k26c_board_timing_plane": "rtl/isolated/subsystems/timing/k26c_board_timing_plane.vhd",
        "k26c_board_analog_control_plane": "rtl/isolated/subsystems/analog/k26c_board_analog_control_plane.vhd",
    }
    sources = [
        "rtl/isolated/common/primitives/axi_lite_unavailable.vhd",
        "rtl/isolated/subsystems/trigger/afe_capture_to_trigger_bank.vhd",
        "rtl/isolated/subsystems/trigger/frontend_to_selftrigger_adapter.vhd",
        "rtl/isolated/subsystems/control/trigger_control_adapter.vhd",
        "rtl/isolated/subsystems/control/selftrigger_register_bank.vhd",
        "rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd",
        "rtl/isolated/subsystems/readout/k26c_selftrigger_datapath_plane.vhd",
        "rtl/isolated/subsystems/readout/k26c_board_hermes_transport_plane.vhd",
        "rtl/isolated/subsystems/readout/k26c_board_outbuffer_plane.vhd",
        "rtl/isolated/subsystems/readout/k26c_board_transport_plane.vhd",
        "rtl/isolated/subsystems/readout/k26c_board_selftrigger_plane.vhd",
        "rtl/isolated/tops/k26c_board_shell.vhd",
        "ip_repo/daphne_ip/rtl/daphne_selftrigger_top.vhd",
    ]
    with tempfile.TemporaryDirectory(prefix="daphne-board-readout-") as directory:
        build = Path(directory)
        def run(*args):
            subprocess.run([ghdl, *args], cwd=build, check=True)
        run("-a", "--std=08", str(source_path("ip_repo/daphne_ip/rtl/daphne_package.vhd")),
            str(source_path("rtl/isolated/common/daphne_subsystem_pkg.vhd")))
        for entity, relative in boundaries.items():
            text = source_path(relative).read_text()
            declaration = re.search(rf"\bentity\s+{entity}\s+is\b.*?\bend\s+(?:entity\s+)?{entity}\s*;", text, re.I | re.S)
            if not declaration:
                raise RuntimeError(f"Cannot extract hardware-boundary entity: {relative}")
            fixture = build / f"{entity}_interface.vhd"
            fixture.write_text("library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;\n"
                               "use work.daphne_package.all; use work.daphne_subsystem_pkg.all;\n" +
                               declaration.group(0) + f"\narchitecture interface_stub of {entity} is begin end;\n")
            run("-a", "--std=08", str(fixture))
        run("-a", "--std=08", *(str(source_path(source)) for source in sources))
        for top in ("k26c_board_transport_plane", "k26c_board_selftrigger_plane", "k26c_board_shell", "daphne_selftrigger_top"):
            run("-e", "--std=08", top)
            run("-r", "--std=08", top, "--assert-level=error", "--ieee-asserts=disable-at-0", "--stop-time=0ns")
            print(f"PASS board interface elaboration: {top}")

if __name__ == "__main__":
    main()
