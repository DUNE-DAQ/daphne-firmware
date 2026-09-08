"""Keep the hardware-artifact packaging contract with its producer."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class DtboBundleContractTests(unittest.TestCase):
    def test_self_trigger_packager_emits_bundle_scoped_manifest(self) -> None:
        packager = (ROOT / "scripts/package/complete_dtbo_bundle.sh").read_text()
        checker = (ROOT / "scripts/fusesoc/check_build_outputs.sh").read_text()
        self.assertIn('bundle_manifest="${overlay_prefix}_${git_sha}.SHA256SUMS"', packager)
        self.assertIn('check_file "overlay manifest"', checker)

    def test_os_implementation_is_not_in_firmware(self) -> None:
        for path in ("petalinux", "daphne-server", "scripts/petalinux", "scripts/deploy"):
            self.assertFalse((ROOT / path).exists(), path)


if __name__ == "__main__":
    unittest.main()
