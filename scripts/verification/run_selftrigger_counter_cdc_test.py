#!/usr/bin/env python3
"""Test counter snapshots, AXI backpressure, stopped clocks and reset recovery.

Run both the 32-channel target and the 40-channel compatibility configuration.
GHDL uses the behavioral handshake model; --vendor uses unmodified installed
AMD XPM models. Neither simulation models physical metastability.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

from run_grouped32_vendor_tests import host_link_environment

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="New evidence directory")
    parser.add_argument("--vendor", type=Path, help="Vivado installation for actual XPM simulation")
    parser.add_argument("--channels", type=int, choices=(32, 40), action="append")
    args = parser.parse_args()
    build = args.output.resolve()
    build.mkdir(parents=True, exist_ok=False)
    summary = {"result": "running", "started_utc": datetime.now(timezone.utc).isoformat(),
               "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "source_status": subprocess.check_output(["git", "status", "--short"], cwd=ROOT, text=True),
               "mode": "vendor-xpm" if args.vendor else "behavioral-xpm", "sources": [], "commands": [], "runs": []}

    def freeze(path, relative):
        data = path.read_bytes()
        target = build / "sources" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        summary["sources"].append({"original": str(path), "snapshot": str(target.relative_to(build)),
                                   "sha256": hashlib.sha256(data).hexdigest()})
        return target

    def save():
        (build / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")

    sources = [freeze(ROOT / path, path) for path in (
        "ip_repo/daphne_ip/rtl/daphne_package.vhd", "rtl/isolated/common/daphne_subsystem_pkg.vhd",
        "rtl/isolated/subsystems/control/selftrigger_register_bank.vhd", "tests/logic/selftrigger_counter_cdc_tb.vhd")]
    for path in (Path(__file__).resolve(), ROOT / "scripts/verification/run_grouped32_vendor_tests.py",
                 ROOT / "scripts/verification/run_grouped32_tests.py"):
        freeze(path, path.relative_to(ROOT))
    environment = os.environ.copy()
    channels = args.channels or [32, 40]
    try:
        if args.vendor:
            vivado = args.vendor.resolve()
            environment, summary["toolchain"] = host_link_environment("gcc")
            models = [freeze(vivado / relative, Path("vendor") / relative) for relative in (
                "data/ip/xpm/xpm_VCOMP.vhd", "data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv", "data/verilog/src/glbl.v")]
        else:
            ghdl = os.environ.get("GHDL") or shutil.which("ghdl")
            if not ghdl:
                raise RuntimeError("GHDL is not available")
            models = [freeze(ROOT / "tests/logic/models" / name, Path("models") / name)
                      for name in ("xpm_vcomponents.vhd", "xpm_cdc_handshake.vhd")]
        save()
        with (build / "test.log").open("w") as combined:
            def run(*command):
                command = list(map(str, command))
                number = len(summary["commands"])
                result = subprocess.run(command, cwd=build, env=environment, text=True,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                logfile = f"command-{number:02d}.log"
                (build / logfile).write_text(result.stdout)
                combined.write(result.stdout); combined.flush()
                print(result.stdout, end="", flush=True)
                summary["commands"].append({"argv": command, "exit_code": result.returncode, "log": logfile})
                save()
                result.check_returncode()
                return result.stdout

            if args.vendor:
                (build / "xpm").mkdir()
                library = "xpm=" + str(build / "xpm")
                run(vivado / "bin/xvhdl", "--version")
                run(vivado / "bin/xvhdl", "--2008", "--work", library, models[0])
                run(vivado / "bin/xvlog", "--sv", "--work", library, models[1])
                run(vivado / "bin/xvlog", models[2])
                run(vivado / "bin/xvhdl", "--2008", *sources)
            else:
                flags = ("--std=08", "-frelaxed-rules")
                run(ghdl, "--version")
                run(ghdl, "-a", *flags, "--work=xpm", *models)
                run(ghdl, "-a", *flags, *sources)
                run(ghdl, "-e", *flags, "selftrigger_counter_cdc_tb")
            for count in channels:
                if args.vendor:
                    snapshot = "counter_cdc_" + str(count)
                    run(vivado / "bin/xelab", "--debug", "typical", "--relax", "--mt", "4", "-L", library,
                        "-L", "unisims_ver", "work.selftrigger_counter_cdc_tb", "work.glbl",
                        "--generic_top", f"CHANNEL_COUNT_G={count}", "--snapshot", snapshot)
                    output = run(vivado / "bin/xsim", snapshot, "--onerror", "quit", "--runall")
                else:
                    output = run(ghdl, "-r", *flags, "selftrigger_counter_cdc_tb", f"-gCHANNEL_COUNT_G={count}",
                                 "--assert-level=error", "--ieee-asserts=disable-at-0")
                if (f"selftrigger_counter_cdc_tb PASS channels={count}" not in output or
                        re.search(r"(?im)^\s*(?:Error:|Fatal:|Failure:)|\(assertion (?:error|failure)\)", output)):
                    raise RuntimeError(f"Simulation failed or ended without PASS for {count} channels")
                summary["runs"].append({"channels": count, "result": "PASS"})
            summary["result"] = "PASS"
    except Exception as error:
        summary["result"] = "FAIL"
        summary["error"] = str(error)
        raise
    finally:
        summary["finished_utc"] = datetime.now(timezone.utc).isoformat()
        save()


if __name__ == "__main__":
    main()
