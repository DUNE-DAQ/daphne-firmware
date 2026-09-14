"""Exercise build status handling with mock tools, without launching Vivado."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]


class VivadoBuildStatusTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.root / "xilinx").mkdir()
        self.work = self.root / "work"
        self.work.mkdir()
        (self.work / "project_run.tcl").touch()
        self.output = self.root / "output"
        self.output.mkdir()
        for relative in (
            "scripts/remote/run_remote_vivado_chain.sh",
            "scripts/fusesoc/vivado_batch_hook.sh",
        ):
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(REPO_ROOT / relative, destination)
        (self.root / "scripts/fusesoc/board_env.sh").write_text(
            """daphne_resolve_board_defaults() {
  DAPHNE_FPGA_PART=mock
  DAPHNE_BOARD_PART=mock
  DAPHNE_PFM_NAME=mock
  DAPHNE_CONSTRAINT_FILE=mock
  DAPHNE_CONSTRAINT_FILES=mock
}
daphne_default_platform_core() { echo mock:platform:0; }
daphne_default_platform_target() { echo impl; }
daphne_platform_requires_packaged_ip_preflight() { return 0; }
daphne_platform_exports_flow_bundle() { return 0; }
daphne_platform_system_name() { echo mock; }
daphne_platform_flow_work_dir() { echo "$1/work"; }
"""
        )
        self.write_executable(
            self.bin / "git",
            'case "$*" in *--abbrev-ref*) echo test-branch;; *) echo abc1234;; esac\n',
        )
        self.write_executable(self.bin / "xsct", "exit 0\n")
        self.write_executable(
            self.bin / "vivado",
            'echo "mock Vivado exit=${MOCK_VIVADO_EXIT:-0}"\n'
            'exit "${MOCK_VIVADO_EXIT:-0}"\n',
        )
        for stage, relative in (
            ("preflight", "scripts/fusesoc/preflight_vivado_build.sh"),
            ("build", "scripts/fusesoc/run_vivado_batch.sh"),
            ("package", "scripts/package/complete_dtbo_bundle.sh"),
        ):
            self.write_executable(
                self.root / relative,
                f'echo {stage} >>"$MOCK_STAGE_TRACE"\n'
                f'echo "mock {stage} output"\n'
                f'exit "${{MOCK_{stage.upper()}_EXIT:-0}}"\n',
            )
        self.env = {
            key: value
            for key, value in os.environ.items()
            if not key.startswith(("DAPHNE_", "XILINX_", "MOCK_", "WSL_"))
            and key not in ("BASH_ENV", "ENV", "SHELLOPTS", "BASHOPTS")
        }
        self.env.update(
            PATH=f"{self.bin}{os.pathsep}{os.environ['PATH']}",
            DAPHNE_FIRMWARE_ROOT=str(self.root),
            DAPHNE_GIT_SHA="abc1234",
            DAPHNE_OUTPUT_DIR=str(self.output),
            DAPHNE_REMOTE_RUN_ID="test-run",
            DAPHNE_REMOTE_PACKAGE_DTBO="1",
            MOCK_STAGE_TRACE=str(self.root / "stages.txt"),
        )

    @staticmethod
    def write_executable(path: Path, body: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/bin/sh\nset -eu\n" + body)
        path.chmod(0o755)

    def run_script(self, relative: str, **overrides: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(self.root / relative)],
            cwd=self.work,
            env={**self.env, **overrides},
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=10,
        )

    def test_remote_chain_preserves_each_stage_failure(self) -> None:
        stages = ["preflight", "build", "package"]
        trace = Path(self.env["MOCK_STAGE_TRACE"])
        for index, stage in enumerate(stages):
            with self.subTest(stage=stage):
                trace.unlink(missing_ok=True)
                status = 17 + index
                result = self.run_script(
                    "scripts/remote/run_remote_vivado_chain.sh",
                    **{f"MOCK_{stage.upper()}_EXIT": str(status)},
                )
                self.assertEqual(result.returncode, status, result.stdout)
                self.assertEqual(trace.read_text().splitlines(), stages[: index + 1])
                log = self.root / f"build/remote-vivado/test-run/{stage}.log"
                self.assertIn(f"mock {stage} output", log.read_text())
                self.assertNotIn("Remote Vivado chain completed.", result.stdout)
                self.assertFalse((log.parent / "artifacts.txt").exists())

    def test_remote_chain_reports_success_after_all_stages(self) -> None:
        result = self.run_script("scripts/remote/run_remote_vivado_chain.sh")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(
            Path(self.env["MOCK_STAGE_TRACE"]).read_text().splitlines(),
            ["preflight", "build", "package"],
        )
        self.assertIn("Remote Vivado chain completed.", result.stdout)
        self.assertTrue((self.root / "build/remote-vivado/test-run/artifacts.txt").exists())

    def test_synthesis_only_accepts_tcl_truth_values_without_bitstream(self) -> None:
        for value in ("1", "true", "TRUE", "TrUe", "yes", "YeS", "on", "ON"):
            with self.subTest(value=value):
                result = self.run_script(
                    "scripts/fusesoc/vivado_batch_hook.sh", DAPHNE_STOP_AFTER_SYNTH=value
                )
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertIn("Synthesis-only build completed", result.stdout)
                self.assertFalse((self.work / "project.bit").exists())
                self.assertFalse((self.work / "project.xpr").exists())

    def test_other_stop_values_still_require_full_build_bitstream(self) -> None:
        for value in ("", "0", "false", "no", "off", "t", "2", " true "):
            with self.subTest(value=value):
                result = self.run_script(
                    "scripts/fusesoc/vivado_batch_hook.sh", DAPHNE_STOP_AFTER_SYNTH=value
                )
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn("expected batch bitstream", result.stdout)

    def test_full_build_stages_existing_bitstream(self) -> None:
        data = b"mock bitstream\x00\x01"
        (self.output / "daphne_selftrigger_abc1234.bit").write_bytes(data)
        result = self.run_script("scripts/fusesoc/vivado_batch_hook.sh")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual((self.work / "project.bit").read_bytes(), data)
        self.assertTrue((self.work / "project.xpr").exists())

    def test_synthesis_only_does_not_mask_vivado_failure(self) -> None:
        result = self.run_script(
            "scripts/fusesoc/vivado_batch_hook.sh",
            DAPHNE_STOP_AFTER_SYNTH="1",
            MOCK_VIVADO_EXIT="31",
        )
        self.assertEqual(result.returncode, 31, result.stdout)
        self.assertNotIn("Synthesis-only build completed", result.stdout)


if __name__ == "__main__":
    unittest.main()
