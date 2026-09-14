from __future__ import annotations

import csv
import hashlib
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/deploy/render_board_config.py"


class RenderBoardConfigTests(unittest.TestCase):
    def test_render_versioned_board_config_with_checksum(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            record = {
                "contract": "daphne.board-config",
                "version": 1,
                "asset": {
                    "asset_id": "DAPHNE-EXAMPLE-001",
                    "carrier_revision": "DAPHNE V2",
                },
                "som": {
                    "uuid": "00000000-0000-4000-8000-000000000001",
                    "serial": "SOM-EXAMPLE-001",
                    "product": "SM-K26-XCL2GC-ED",
                    "factory_mac_id_0": "02:00:00:00:00:01",
                },
                "network": {
                    "mac_source": "som_eeprom",
                    "production_mac": "02:00:00:00:00:01",
                    "ipv4_address": "192.0.2.10",
                    "hostname": "daphne-example-001.example",
                    "vlan": 100,
                    "authorized": False,
                },
                "runtime": {
                    "timing_endpoint": "0x001",
                    "firmware_release": "daphne-test-release",
                },
                "source": {"assignment_revision": 1, "asset_record_revision": 3},
            }
            record_path = tmp_path / "board-config-v1.json"
            record_path.write_text(
                json.dumps(record, sort_keys=True, separators=(",", ":")), encoding="utf-8"
            )
            digest = hashlib.sha256(record_path.read_bytes()).hexdigest()
            output = tmp_path / "rendered"
            subprocess.run(
                [
                    "python3",
                    str(SCRIPT),
                    "--record",
                    str(record_path),
                    "--record-sha256",
                    digest,
                    "--allow-unapproved",
                    "--output",
                    str(output),
                    "--gateway",
                    "192.0.2.1",
                    "--dns",
                    "192.0.2.53",
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            combined = "\n".join(path.read_text() for path in output.iterdir())
            self.assertIn(f"BOARD_CONFIG_SHA256={digest}", combined)
            self.assertIn("FIRMWARE_RELEASE=daphne-test-release", combined)
            self.assertIn("Address=192.0.2.10/24", combined)
            self.assertNotIn("MACAddress=", combined)
            self.assertNotIn("ethaddr=", combined)

    def test_render_has_identity_but_no_mac_setter(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            inventory = tmp_path / "inventory.csv"
            fields = [
                "asset_id", "som_uuid", "factory_mac_id_0", "mac_source",
                "production_mac", "ipv4_address", "hostname", "timing_endpoint",
                "network_admission_approved",
            ]
            with inventory.open("w", newline="", encoding="utf-8") as target:
                writer = csv.DictWriter(target, fieldnames=fields)
                writer.writeheader()
                writer.writerow(
                    {
                        "asset_id": "NP04-DAPHNE-015",
                        "som_uuid": "70c5439d-de29-4263-8066-99627ad4ae5e",
                        "factory_mac_id_0": "00:0a:35:0e:9b:63",
                        "mac_source": "som_eeprom",
                        "production_mac": "00:0a:35:0e:9b:63",
                        "ipv4_address": "10.73.137.16",
                        "hostname": "NP04-DAPHNE-015.CERN.CH",
                        "timing_endpoint": "0x15",
                        "network_admission_approved": "1",
                    }
                )
            output = tmp_path / "rendered"
            subprocess.run(
                [
                    "python3", str(SCRIPT), "--inventory", str(inventory),
                    "--asset", "NP04-DAPHNE-015", "--output", str(output),
                    "--gateway", "10.73.137.1", "--dns", "137.138.16.5",
                    "--dns", "137.138.17.5",
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            combined = "\n".join(path.read_text() for path in output.iterdir())
            self.assertNotIn("MACAddress=", combined)
            self.assertNotIn("ethaddr=", combined)
            self.assertIn("FACTORY_MAC_ID_0=00:0a:35:0e:9b:63", combined)
            self.assertIn("Address=10.73.137.16/24", combined)


if __name__ == "__main__":
    unittest.main()
