#!/usr/bin/env python3
"""Run continuation RTL contracts in a fresh temporary GHDL library."""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trace", type=Path, help="replay a waveform_packet_sim trace DAT")
    parser.add_argument("--output", type=Path, help="write replay transport words CSV")
    parser.add_argument("--channels", type=int, default=2)
    parser.add_argument("--replay-only", action="store_true")
    args = parser.parse_args()
    if args.trace and not args.output:
        parser.error("--trace requires --output")
    if args.replay_only and not args.trace:
        parser.error("--replay-only requires --trace")
    ghdl = os.environ.get("GHDL") or shutil.which("ghdl")
    if not ghdl:
        fallback = Path.home() / "tools/oss-cad-suite/bin/ghdl"
        if fallback.is_file():
            ghdl = str(fallback)
    if not ghdl:
        raise SystemExit("GHDL is required; set GHDL to its executable path")
    sources = [
        "ip_repo/daphne_ip/rtl/daphne_package.vhd",
        "rtl/isolated/common/daphne_subsystem_pkg.vhd",
        "rtl/isolated/common/primitives/axi_lite_unavailable.vhd",
        "rtl/isolated/subsystems/readout/k26c_board_outbuffer_plane.vhd",
        "tests/logic/axi_lite_unavailable_tb.vhd",
        "rtl/isolated/subsystems/trigger/fragment_peak_descriptors.vhd",
        "rtl/isolated/subsystems/trigger/fragment_peak_descriptors_serial.vhd",
        "rtl/isolated/subsystems/trigger/fragment_peak_descriptors_banked.vhd",
        "rtl/isolated/subsystems/control/selftrigger_register_bank.vhd",
        "rtl/isolated/subsystems/control/legacy_selftrigger_register_bank.vhd",
        "rtl/isolated/subsystems/control/trigger_control_adapter.vhd",
        "rtl/isolated/common/primitives/sample_ring_buffer.vhd",
        "rtl/isolated/common/primitives/sample_ring_buffer_single.vhd",
        "rtl/isolated/common/primitives/packet_frame_store.vhd",
        "rtl/isolated/subsystems/trigger/stc3_record_builder.vhd",
        "rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd",
        "rtl/isolated/common/primitives/fixed_delay_line.vhd",
        "tests/logic/models/hpf_pedestal_recovery_filter_trigger_stub.vhd",
        "ip_repo/daphne_ip/rtl/selftrig/trig_xc.vhd",
        "tests/logic/trig_xc_alignment_tb.vhd",
        "tests/logic/fragment_peak_descriptors_tb.vhd",
        "tests/logic/fragment_peak_descriptors_serial_tb.vhd",
        "tests/logic/fragment_peak_descriptors_banked_tb.vhd",
        "tests/logic/continuation_registers_tb.vhd",
        "tests/logic/stc3_continuation_tb.vhd",
        "tests/logic/stc3_continuation_edges_tb.vhd",
        "tests/logic/stc3_continuation_overload_tb.vhd",
        "tests/logic/stc3_trace_replay_tb.vhd",
    ]
    with tempfile.TemporaryDirectory(prefix="daphne-continuation-") as build_dir:
        def run(*args):
            subprocess.run([ghdl, *args], cwd=build_dir, check=True)
        run("-a", "--std=08", "--work=xpm", str(ROOT / "tests/logic/models/xpm_vcomponents.vhd"),
            str(ROOT / "tests/logic/models/xpm_memory_sdpram.vhd"))
        run("-a", "--std=08", *(str(ROOT / p) for p in sources))
        if args.trace:
            args.output.resolve().parent.mkdir(parents=True, exist_ok=True)
            run("-e", "--std=08", "stc3_trace_replay_tb")
            run("-r", "--std=08", "stc3_trace_replay_tb", f"-gTRACE_G={args.trace.resolve()}",
                f"-gOUTPUT_G={args.output.resolve()}", f"-gCHANNELS_G={args.channels}", "--assert-level=error")
        if args.replay_only:
            return
        for bench in ("axi_lite_unavailable_tb", "fragment_peak_descriptors_tb", "fragment_peak_descriptors_serial_tb", "fragment_peak_descriptors_banked_tb", "continuation_registers_tb", "trig_xc_alignment_tb"):
            run("-e", "--std=08", bench)
            run("-r", "--std=08", bench, "--assert-level=error", "--stop-time=100us")
        run("-e", "--std=08", "stc3_continuation_tb")
        for odd in (0, 1):
            run("-r", "--std=08", "stc3_continuation_tb", f"-gODD_START_G={odd}", "--assert-level=error", "--stop-time=1ms")
        run("-e", "--std=08", "stc3_continuation_edges_tb")
        run("-r", "--std=08", "stc3_continuation_edges_tb", "--assert-level=error", "--stop-time=1ms")
        run("-e", "--std=08", "stc3_continuation_overload_tb")
        run("-r", "--std=08", "stc3_continuation_overload_tb", "--assert-level=error", "--stop-time=1ms")

if __name__ == "__main__":
    main()
