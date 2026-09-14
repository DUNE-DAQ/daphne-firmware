#!/usr/bin/env python3
"""Replay a DAT trace through pinned reference RTL and write cycle-level packet CSV.

The builder, ring, mux, and types come from git-show of --reference. The local
behavioral FIFO fixture models FWFT storage and immediate programmable flags;
this is functional RTL validation, not a vendor XPM timing simulation. No files
in the source checkout are rewritten and no baseline implementation is patched.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = "7d5d3a64339c78cdf4a2052079300563bdde215e"
REFERENCE_FILES = (
    "ip_repo/daphne_ip/rtl/daphne_package.vhd",
    "rtl/isolated/common/daphne_subsystem_pkg.vhd",
    "rtl/isolated/common/primitives/sample_ring_buffer.vhd",
    "rtl/isolated/subsystems/trigger/stc3_record_builder.vhd",
    "rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd",
)
FIXTURE_FILES = (
    "tests/logic/models/xpm_vcomponents.vhd",
    "tests/logic/models/xpm_memory_sdpram.vhd",
    "tests/logic/models/reference_sync_fifo_fwft.vhd",
    "tests/logic/stc3_reference_trace_replay_tb.vhd",
)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trace", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--channels", type=int, default=2)
    parser.add_argument("--overlap", type=int, choices=range(32), default=0,
                        help="signal_delay register value; 16 means256 overlapping samples")
    parser.add_argument("--reference", default=REFERENCE)
    args = parser.parse_args()
    if args.channels < 2 or args.channels > 40 or args.channels % 2:
        parser.error("--channels must be even and between2 and40")
    ghdl = os.environ.get("GHDL") or shutil.which("ghdl")
    if not ghdl:
        fallback = Path.home()/"tools/oss-cad-suite/bin/ghdl"
        if fallback.is_file():
            ghdl = str(fallback)
    if not ghdl:
        raise SystemExit("GHDL is required; set GHDL to the executable")
    trace = args.trace.resolve()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    reference = subprocess.check_output(
        ["git", "rev-parse", "--verify", f"{args.reference}^{{commit}}"], cwd=ROOT, text=True).strip()
    sources = {p: subprocess.check_output(["git", "show", f"{reference}:{p}"], cwd=ROOT)
               for p in REFERENCE_FILES}
    fixtures = {p: (ROOT/p).read_bytes() for p in FIXTURE_FILES}
    frozen_trace = trace.read_bytes()
    command_log = []
    with tempfile.TemporaryDirectory(prefix="daphne-reference-replay-") as build_path:
        build = Path(build_path)
        input_path = build/"input.dat"
        input_path.write_bytes(frozen_trace)
        local = {}
        for relative, data in {**sources, **fixtures}.items():
            path = build/relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            local[relative] = str(path)
        def run(*arguments):
            command = [ghdl, *arguments]
            process = subprocess.run(command, cwd=build, text=True, stdout=subprocess.PIPE,
                                     stderr=subprocess.STDOUT)
            command_log.append({"command": command, "returncode": process.returncode,
                                "output": process.stdout})
            if process.returncode:
                raise RuntimeError(process.stdout)
            return process.stdout
        try:
            version = run("--version")
            run("-a", "--std=08", "--work=xpm", local[FIXTURE_FILES[0]], local[FIXTURE_FILES[1]])
            # Analyze the logical FIFO before the unmodified reference builder.
            run("-a", "--std=08", local[REFERENCE_FILES[0]], local[REFERENCE_FILES[1]],
                local[REFERENCE_FILES[2]], local[FIXTURE_FILES[2]], local[REFERENCE_FILES[3]],
                local[REFERENCE_FILES[4]], local[FIXTURE_FILES[3]])
            run("-e", "--std=08", "stc3_reference_trace_replay_tb")
            result = run("-r", "--std=08", "stc3_reference_trace_replay_tb",
                         f"-gTRACE_G={input_path}", f"-gOUTPUT_G={output}",
                         f"-gCHANNELS_G={args.channels}", f"-gOVERLAP_G={args.overlap}",
                         "--assert-level=error")
        finally:
            output.with_suffix(output.suffix+".log").write_text(
                "\n".join(json.dumps(c["command"])+"\n"+c["output"] for c in command_log))
    metadata = {
        "reference_commit": reference, "channels": args.channels,
        "signal_delay_register": args.overlap, "overlap_samples": args.overlap*16,
        "trace_path": str(trace), "trace_sha256": digest(frozen_trace),
        "reference_source_sha256": {p:digest(data) for p,data in sources.items()},
        "fixture_sha256": {p:digest(data) for p,data in fixtures.items()},
        "output_sha256": digest(output.read_bytes()), "ghdl_version": version,
        "model_limitations": ["Logical FWFT FIFO with immediate programmable flags",
                              "No vendor XPM flag-latency or physical memory timing simulation",
                              "Legacy descriptor trailer inputs are zero; waveform and scheduler comparison only"],
    }
    output.with_suffix(output.suffix+".provenance.json").write_text(json.dumps(metadata,indent=2)+"\n")
    print(result,end="")
    print(f"CSV: {output}")

if __name__ == "__main__":
    main()
