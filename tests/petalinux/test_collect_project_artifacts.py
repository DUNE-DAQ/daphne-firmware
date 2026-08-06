from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COLLECT = ROOT / "scripts" / "petalinux" / "collect_project_artifacts.sh"


class CollectProjectArtifactsTests(unittest.TestCase):
    def test_collects_xsdb_ram_boot_inputs_and_wic_image(self) -> None:
        with tempfile.TemporaryDirectory() as root_text:
            root = Path(root_text)
            project = root / "daphne-petalinux"
            images = project / "images" / "linux"
            overlay = (
                project
                / "project-spec"
                / "meta-daphne"
                / "recipes-firmware"
                / "daphne-overlay"
                / "files"
                / "staged"
            )
            (project / "project-spec").mkdir(parents=True)
            (project / "build" / "conf").mkdir(parents=True)
            (project / "build" / "conf" / "local.conf").write_text(
                'DAPHNE_IMAGE_PROFILE = "minimal"\n', encoding="utf-8"
            )
            images.mkdir(parents=True)
            overlay.mkdir(parents=True)

            for name in (
                "BOOT.BIN",
                "zynqmp_fsbl.elf",
                "pmufw.elf",
                "bl31.elf",
                "u-boot-dtb.elf",
                "Image",
                "system.dtb",
                "rootfs.wic.gz",
            ):
                (images / name).write_text(f"{name}\n", encoding="utf-8")
            (overlay / "daphne-overlay.dtbo").write_text("overlay\n", encoding="utf-8")
            bundle = root / "bundle"

            subprocess.run([str(COLLECT), str(project), str(bundle)], check=True, text=True)

            for relative in (
                "boot/BOOT.BIN",
                "boot/zynqmp_fsbl.elf",
                "boot/pmufw.elf",
                "boot/bl31.elf",
                "boot/u-boot-dtb.elf",
                "boot/Image",
                "boot/system.dtb",
                "rootfs/rootfs.wic.gz",
                "overlay/daphne-overlay.dtbo",
                "MANIFEST.txt",
                "SHA256SUMS",
            ):
                self.assertTrue((bundle / relative).is_file(), relative)

            metadata = (bundle / "meta" / "COLLECT-METADATA.txt").read_text(
                encoding="utf-8"
            )
            self.assertIn("image_profile=minimal", metadata)
            self.assertIn("deployment_scope=whole-emmc-and-inactive-slot", metadata)
            self.assertIn("overlay_policy=included-from-staged-artifacts", metadata)

    def test_provisioning_bundle_excludes_stale_staged_overlay(self) -> None:
        with tempfile.TemporaryDirectory() as root_text:
            root = Path(root_text)
            project = root / "daphne-petalinux"
            images = project / "images" / "linux"
            overlay = (
                project
                / "project-spec"
                / "meta-daphne"
                / "recipes-firmware"
                / "daphne-overlay"
                / "files"
                / "staged"
            )
            (project / "project-spec").mkdir(parents=True)
            (project / "build" / "conf").mkdir(parents=True)
            (project / "build" / "conf" / "local.conf").write_text(
                'DAPHNE_IMAGE_PROFILE ?= "minimal"\n'
                'DAPHNE_IMAGE_PROFILE = "provisioning"\n',
                encoding="utf-8",
            )
            images.mkdir(parents=True)
            overlay.mkdir(parents=True)
            (images / "rootfs.wic.gz").write_text("wic\n", encoding="utf-8")
            (overlay / "daphne-overlay.dtbo").write_text("stale\n", encoding="utf-8")
            bundle = root / "bundle"

            subprocess.run([str(COLLECT), str(project), str(bundle)], check=True, text=True)

            self.assertTrue((bundle / "rootfs" / "rootfs.wic.gz").is_file())
            self.assertFalse((bundle / "overlay" / "daphne-overlay.dtbo").exists())
            metadata = (bundle / "meta" / "COLLECT-METADATA.txt").read_text(
                encoding="utf-8"
            )
            self.assertIn("image_profile=provisioning", metadata)
            self.assertIn("deployment_scope=virgin-som-whole-emmc", metadata)
            self.assertIn("overlay_policy=excluded-for-provisioning", metadata)


if __name__ == "__main__":
    unittest.main()
