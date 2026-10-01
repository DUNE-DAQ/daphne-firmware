#!/usr/bin/env python3
"""Exercise calibration routing through the production eight-channel island."""
import subprocess
import tempfile
from run_grouped32_tests import GHDL, ROOT, SOURCES

sources = SOURCES + [
    "rtl/isolated/common/primitives/fixed_delay_line.vhd",
    "rtl/isolated/common/primitives/configurable_delay_line.vhd",
    "tests/logic/models/hpf_channel_calibration_fixture.vhd",
    "ip_repo/daphne_ip/rtl/selftrig/trig_xc.vhd",
    "rtl/isolated/subsystems/trigger/self_trigger_xcorr_channel.vhd",
    "ip_repo/daphne_ip/rtl/selftrig/peak_descriptor_import/Configurable_CFD.vhd",
    "ip_repo/daphne_ip/rtl/selftrig/peak_descriptor_import/PeakDetector_SelfTrigger.vhd",
    "ip_repo/daphne_ip/rtl/selftrig/peak_descriptor_import/Peak_Descriptors.vhd",
    "ip_repo/daphne_ip/rtl/selftrig/peak_descriptor_import/Peak_Descriptor_Calculation.vhd",
    "rtl/isolated/subsystems/trigger/peak_descriptor_channel.vhd",
    "rtl/isolated/subsystems/trigger/afe_trigger_bank.vhd",
    "rtl/isolated/subsystems/trigger/channel_calibration_policy.vhd",
    "rtl/isolated/subsystems/trigger/afe_grouped_selftrigger_island.vhd",
    "rtl/isolated/subsystems/trigger/grouped_selftrigger_fabric.vhd",
    "tests/logic/channel_calibration_tb.vhd",
]
with tempfile.TemporaryDirectory(prefix="daphne-calibration-") as directory:
    def run(*args):
        subprocess.run([GHDL, *map(str,args)], cwd=directory, check=True)
    run("-a", "--std=08", "--work=xpm", *[ROOT/"tests/logic/models"/name for name in
        ("xpm_vcomponents.vhd", "xpm_memory_sdpram.vhd", "xpm_cdc_handshake.vhd", "xpm_fifo_async.vhd")])
    run("-a", "--std=08", *[ROOT/path for path in sources])
    run("-e", "--std=08", "channel_calibration_tb")
    run("-r", "--std=08", "channel_calibration_tb", "--assert-level=error", "--ieee-asserts=disable-at-0")
