"""Check phase instrumentation without a Vivado license or synthesized design."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which("tclsh"), "tclsh unavailable")
class BuildPhaseTimingTests(unittest.TestCase):
    def test_timing_preserves_configuration_results_and_errors(self):
        with tempfile.TemporaryDirectory() as tmp:
            script = r'''
# Plain Tcl lacks Vivado's source -notrace extension.
rename source native_source
proc source {args} { native_source [lindex $args end] }
source [file join $::env(TEST_REPO) xilinx daphne_vivado_flow.tcl]
array set cfg [list output_dir $::env(TEST_OUTPUT) synth_directive PerformanceOptimized max_threads 4]
proc passing {name} {
    upvar 1 $name config
    set config(observed) 1
    return phase_result
}
proc failing {name} { return -code error -errorcode {DAPHNE TEST} expected_failure }
if {[daphne_measure_build_phase pass passing cfg] ne "phase_result"} { error "lost result" }
if {$cfg(observed) != 1} { error "lost configuration alias" }
set status [catch {daphne_measure_build_phase fail failing cfg} result options]
if {$status != 1 || $result ne "expected_failure"} { error "lost failure" }
if {[dict get $options -errorcode] ne "DAPHNE TEST"} { error "lost error code" }
'''
            import os
            result = subprocess.run(
                ["tclsh"], input=script, text=True, capture_output=True,
                env={**os.environ, "TEST_REPO": str(ROOT), "TEST_OUTPUT": tmp},
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, "")
            rows = (Path(tmp) / "build-phase-times.tsv").read_text().splitlines()
            self.assertEqual(len(rows), 3)
            for row, phase, status in zip(rows[1:], ("pass", "fail"), ("0", "1")):
                fields = row.split("\t")
                self.assertEqual(fields[0], phase)
                self.assertGreaterEqual(int(fields[1]), 0)
                self.assertEqual(fields[2:], [status, "PerformanceOptimized", "4"])


if __name__ == "__main__":
    unittest.main()
