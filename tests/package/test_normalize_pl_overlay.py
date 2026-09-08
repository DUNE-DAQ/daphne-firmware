#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
NORMALIZER_PATH = ROOT / "scripts/package/normalize_pl_overlay.py"
SPEC = importlib.util.spec_from_file_location("normalize_pl_overlay", NORMALIZER_PATH)
assert SPEC is not None and SPEC.loader is not None
NORMALIZER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NORMALIZER)


PL_BODY = """
    #address-cells = <2>;
    #size-cells = <2>;
    compatible = "simple-bus";
    ranges;
    firmware-name = "generated.bit.bin";
    clocking0: clocking0 {
        compatible = "xlnx,fclk";
    };
    afi0: afi0 {
        compatible = "xlnx,afi-fpga";
    };
    axi_intc_0: interrupt-controller@9c010000 {
        compatible = "xlnx,axi-intc-4.1";
        interrupt-parent = <&imux>;
        #interrupt-cells = <1>;
    };
    axi_iic_0: i2c@9c000000 {
        compatible = "xlnx,axi-iic-2.1";
    };
    axi_quad_spi_0: axi_quad_spi@9c020000 {
        compatible = "xlnx,axi-quad-spi-3.2";
        #address-cells = <2>;
        #size-cells = <1>;
        spidev@0 {
            compatible = "legacy,spidev";
            reg = <1>;
        };
    };
""".strip("\n")


class NormalizePlOverlayTests(unittest.TestCase):
    def test_splits_generated_amba_pl_into_region_and_bus_fragments(self) -> None:
        source = "/dts-v1/;\n/plugin/;\n/ {\n\tamba_pl {\n" + PL_BODY + "\n\t};\n};\n"

        result = NORMALIZER.normalize_overlay_text(
            source, "daphne_selftrigger_ol_3f17f1b.bin"
        )

        self.assertEqual(result.count("target = <&fpga_full>;"), 1)
        self.assertEqual(result.count("target = <&amba>;"), 1)
        self.assertNotIn('target-path = "/axi";', result)
        self.assertEqual(
            result.count(
                'firmware-name = "daphne_selftrigger_ol_3f17f1b.bin";'
            ),
            1,
        )
        fpga_fragment, amba_fragment = result.split("\tfragment@1 {", 1)
        self.assertIn("firmware-name", fpga_fragment)
        self.assertNotIn("firmware-name", amba_fragment)
        self.assertIn(
            "resets = <&zynqmp_reset 116>, <&zynqmp_reset 117>;",
            fpga_fragment,
        )
        self.assertIn("interrupt-controller@9c010000", amba_fragment)
        self.assertIn("i2c@9c000000", amba_fragment)
        self.assertIn("interrupt-parent = <&gic>;", amba_fragment)
        self.assertIn("#interrupt-cells = <2>;", amba_fragment)
        self.assertIn('compatible = "rohm,dh2228fv";', amba_fragment)
        self.assertNotIn("&imux", result)

    def test_accepts_sdt_axi_fragment_and_is_idempotent(self) -> None:
        indented_body = "\n".join(f"\t\t\t{line}" for line in PL_BODY.splitlines())
        source = (
            "/dts-v1/;\n/plugin/;\n/ {\n"
            "\tfragment@0 {\n"
            '\t\ttarget-path = "/axi";\n'
            "\t\t__overlay__ {\n"
            f"{indented_body}\n"
            "\t\t};\n"
            "\t};\n"
            "};\n"
        )

        normalized = NORMALIZER.normalize_overlay_text(
            source, "daphne_fullstream_ol_b24e416.bin"
        )
        repeated = NORMALIZER.normalize_overlay_text(
            normalized, "daphne_fullstream_ol_b24e416.bin"
        )

        self.assertEqual(repeated, normalized)

    def test_rejects_firmware_name_on_amba_fragment(self) -> None:
        source = (
            "/dts-v1/;\n/plugin/;\n/ {\n"
            "\tfragment@0 {\n"
            "\t\ttarget = <&fpga_full>;\n"
            "\t\t__overlay__ {\n"
            "\t\t\tresets = <&zynqmp_reset 116>, <&zynqmp_reset 117>;\n"
            "\t\t};\n"
            "\t};\n"
            "\tfragment@1 {\n"
            "\t\ttarget = <&amba>;\n"
            "\t\t__overlay__ {\n"
            '\t\t\tfirmware-name = "wrong.bin";\n'
            "\t\t\tinterrupt-controller@9c010000 {};\n"
            "\t\t\ti2c@9c000000 {};\n"
            "\t\t};\n"
            "\t};\n"
            "};\n"
        )

        with self.assertRaisesRegex(ValueError, "firmware-name"):
            NORMALIZER.normalize_overlay_text(source, "expected.bin")


if __name__ == "__main__":
    unittest.main()
