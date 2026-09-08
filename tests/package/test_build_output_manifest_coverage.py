from __future__ import annotations

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "scripts/fusesoc/check_build_outputs.sh"
BUILD_SHA = "abcdef0"
BUILD_NAME = f"daphne_selftrigger_{BUILD_SHA}"
OVERLAY_NAME = f"daphne_selftrigger_ol_{BUILD_SHA}"


class BuildOutputManifestCoverageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.base = Path(self.temporary.name)
        self.output = self.base / "output"
        self.overlay = self.output / OVERLAY_NAME
        self.overlay.mkdir(parents=True)

        self.fake_bin = self.base / "fake-bin"
        self.fake_bin.mkdir()
        for command in ("dtc", "unzip"):
            executable = self.fake_bin / command
            executable.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            executable.chmod(0o755)

        self.env = os.environ.copy()
        self.env["PATH"] = f"{self.fake_bin}:{self.env['PATH']}"
        self.env["DAPHNE_FIRMWARE_ROOT"] = str(ROOT)

        self.bundle_paths = [
            f"{OVERLAY_NAME}.zip",
            f"{OVERLAY_NAME}/{OVERLAY_NAME}.bin",
            f"{OVERLAY_NAME}/{OVERLAY_NAME}.dtbo",
            f"{OVERLAY_NAME}/shell.json",
        ]
        self.global_paths = [
            f"{BUILD_NAME}.bit",
            f"{BUILD_NAME}.bin",
            f"{BUILD_NAME}.xsa",
            f"{BUILD_NAME}.dtbo",
            *self.bundle_paths,
            f"{OVERLAY_NAME}.SHA256SUMS",
            "post_route_timing_summary.rpt",
            "post_route_bus_skew.rpt",
            "post_route_cdc.rpt",
            "post_route_methodology.rpt",
            "post_route_status.rpt",
            "post_route_power.rpt",
            "post_route_util.rpt",
            "post_imp_drc.rpt",
        ]

        for relative_path in self.global_paths:
            if relative_path.endswith(".SHA256SUMS"):
                continue
            artifact = self.output / relative_path
            artifact.parent.mkdir(parents=True, exist_ok=True)
            artifact.write_text(f"fixture:{relative_path}\n", encoding="utf-8")

        (self.output / "post_route_timing_summary.rpt").write_text(
            "All user specified timing constraints are met.\n", encoding="utf-8"
        )
        (self.output / "post_route_bus_skew.rpt").write_text(
            "Slack (MET)\n", encoding="utf-8"
        )
        (self.output / "post_route_status.rpt").write_text(
            "# of nets with routing errors : 0\n", encoding="utf-8"
        )
        self.write_manifest(self.bundle_manifest, self.bundle_paths)
        self.write_manifest(self.global_manifest, self.global_paths)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    @property
    def bundle_manifest(self) -> Path:
        return self.output / f"{OVERLAY_NAME}.SHA256SUMS"

    @property
    def global_manifest(self) -> Path:
        return self.output / "SHA256SUMS"

    @staticmethod
    def digest(path: Path) -> str:
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def write_manifest(self, manifest: Path, relative_paths: list[str]) -> None:
        manifest.write_text(
            "".join(
                f"{self.digest(self.output / relative_path)}  {relative_path}\n"
                for relative_path in relative_paths
            ),
            encoding="utf-8",
        )

    def replace_with_suffixed_entry(
        self, manifest: Path, relative_path: str, suffix: str = ".backup"
    ) -> None:
        suffixed_path = f"{relative_path}{suffix}"
        backup = self.output / suffixed_path
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(self.output / relative_path, backup)
        exact_line = (
            f"{self.digest(self.output / relative_path)}  {relative_path}\n"
        )
        suffixed_line = f"{self.digest(backup)}  {suffixed_path}\n"
        contents = manifest.read_text(encoding="utf-8")
        self.assertEqual(contents.count(exact_line), 1)
        manifest.write_text(
            contents.replace(exact_line, suffixed_line, 1), encoding="utf-8"
        )

    def duplicate_entry(self, manifest: Path, relative_path: str) -> None:
        line = f"{self.digest(self.output / relative_path)}  {relative_path}\n"
        contents = manifest.read_text(encoding="utf-8")
        self.assertEqual(contents.count(line), 1)
        manifest.write_text(contents + line, encoding="utf-8")

    def run_checker(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(CHECKER), str(self.output), BUILD_SHA],
            env=self.env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def assert_rejected(self, result: subprocess.CompletedProcess[str], message: str) -> None:
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(message, result.stderr)

    def test_complete_exact_manifests_pass(self) -> None:
        result = self.run_checker()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_global_manifest_suffix_cannot_substitute_for_required_path(self) -> None:
        required = f"{BUILD_NAME}.bit"
        self.replace_with_suffixed_entry(self.global_manifest, required, " backup")
        (self.output / required).write_text("tampered but unchecked\n", encoding="utf-8")

        result = self.run_checker()

        self.assert_rejected(
            result,
            f"checksum manifest must contain exactly one checksum for {required} (found 0)",
        )

    def test_global_manifest_duplicate_required_path_is_rejected(self) -> None:
        required = f"{BUILD_NAME}.bit"
        self.duplicate_entry(self.global_manifest, required)

        result = self.run_checker()

        self.assert_rejected(
            result,
            f"checksum manifest must contain exactly one checksum for {required} (found 2)",
        )

    def test_overlay_manifest_suffix_cannot_substitute_for_required_path(self) -> None:
        required = f"{OVERLAY_NAME}.zip"
        self.replace_with_suffixed_entry(self.bundle_manifest, required)
        self.write_manifest(self.global_manifest, self.global_paths)

        result = self.run_checker()

        self.assert_rejected(
            result,
            f"overlay manifest must contain exactly one checksum for {required} (found 0)",
        )

    def test_overlay_manifest_duplicate_required_path_is_rejected(self) -> None:
        required = f"{OVERLAY_NAME}.zip"
        self.duplicate_entry(self.bundle_manifest, required)
        self.write_manifest(self.global_manifest, self.global_paths)

        result = self.run_checker()

        self.assert_rejected(
            result,
            f"overlay manifest must contain exactly one checksum for {required} (found 2)",
        )


if __name__ == "__main__":
    unittest.main()
