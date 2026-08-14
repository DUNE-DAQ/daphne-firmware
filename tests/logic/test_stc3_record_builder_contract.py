#!/usr/bin/env python3
from __future__ import annotations

import re
import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
BUILDER = "rtl/isolated/subsystems/trigger/stc3_record_builder.vhd"


def read_repo(path: str) -> str:
    return (REPO_ROOT / path).read_text(encoding="utf-8")


def git_show(rev: str, path: str) -> str:
    return subprocess.check_output(
        ["git", "show", f"{rev}:{path}"],
        cwd=REPO_ROOT,
        text=True,
    )


def git_diff_names(*args: str) -> list[str]:
    output = subprocess.check_output(
        ["git", "diff", "--name-only", *args],
        cwd=REPO_ROOT,
        text=True,
    )
    return [line for line in output.splitlines() if line]


def natural_constant(vhdl: str, name: str) -> int:
    match = re.search(
        rf"constant\s+{re.escape(name)}\s*:\s*(?:natural|positive)\s*:=\s*(\d+)\s*;",
        vhdl,
    )
    if match is None:
        raise AssertionError(f"missing natural constant {name}")
    return int(match.group(1))


class Stc3RecordBuilderContractTest(unittest.TestCase):
    def test_baseline_d7c9f04_is_1024_sample_232_word_builder(self) -> None:
        baseline = git_show("d7c9f04", BUILDER)

        self.assertIn("block_count_s        : integer range 0 to 31", baseline)
        self.assertIn("if block_count_s = 31 then", baseline)
        self.assertIn("PROG_EMPTY_THRESH_G => 220", baseline)
        self.assertIn("DELAY_G => 288", baseline)
        self.assertIn(
            "sample0_ts_s <= std_logic_vector(unsigned(trigger_i.trigger_timestamp) - 64);",
            baseline,
        )
        self.assertIn("delayed_sample_o <= din_delay(9);", baseline)
        self.assertIn('marker_s <= X"BE"', baseline)
        self.assertIn('X"ED" when (state_s = d27 and block_count_s = 31)', baseline)

        header_words = 8
        blocks = 32
        words_per_block = 7
        self.assertEqual(header_words + blocks * words_per_block, 232)

    def test_current_builder_is_512_sample_2k_ring_contract(self) -> None:
        current = read_repo(BUILDER)

        frame_samples = natural_constant(current, "FRAME_SAMPLE_COUNT_C")
        frame_blocks = frame_samples // 32
        frame_words = natural_constant(current, "HEADER_WORD_COUNT_C") + (
            frame_blocks * natural_constant(current, "WORDS_PER_BLOCK_C")
        )

        self.assertEqual(frame_samples, 512)
        self.assertEqual(natural_constant(current, "PRETRIGGER_SAMPLES_C"), 64)
        self.assertEqual(frame_blocks, 16)
        self.assertEqual(frame_words, 120)
        self.assertEqual(natural_constant(current, "FIFO_READY_MARGIN_C"), 12)
        self.assertEqual(frame_words - natural_constant(current, "FIFO_READY_MARGIN_C"), 108)
        self.assertEqual(natural_constant(current, "RING_DEPTH_C"), 2048)
        self.assertEqual(natural_constant(current, "RING_ADDR_WIDTH_C"), 11)
        self.assertEqual(natural_constant(current, "FRAME_QUEUE_DEPTH_C"), 2)
        self.assertEqual(natural_constant(current, "OVERLAP_GRANULARITY_C"), 16)

        self.assertIn("sample_ring_inst : entity work.sample_ring_buffer", current)
        self.assertIn("output_fifo_inst : entity work.sync_fifo_fwft", current)
        self.assertIn("spacing_reject_count_o", current)
        self.assertIn("queue_reject_count_o", current)
        self.assertIn("ring_reject_count_o", current)
        self.assertIn("output_reject_count_o", current)
        self.assertIn("overlap_v := to_integer(unsigned(signal_delay)) * OVERLAP_GRANULARITY_C;", current)
        self.assertIn("min_trigger_spacing_s <= FRAME_SAMPLE_COUNT_C - overlap_samples_s;", current)
        self.assertIn("ring_distance(write_ptr_s, frame_queue_s(frame_queue_head_s).start_ptr) >= FRAME_SAMPLE_COUNT_C - 1", current)
        self.assertIn("ring_distance(write_ptr_s, oldest_pending_ptr_s) <= RING_DEPTH_C - FRAME_SAMPLE_COUNT_C", current)
        self.assertIn("sample0_ts_v  := unsigned(event_timestamp_s) - to_unsigned(PRETRIGGER_SAMPLES_C", current)
        self.assertIn("delayed_sample_o <= din_i;", current)

    def test_current_builder_tags_calibration_in_reserved_header_bits(self) -> None:
        current = read_repo(BUILDER)
        pkg = read_repo("rtl/isolated/common/daphne_subsystem_pkg.vhd")

        self.assertIn('CALIBRATION_TAG_NORMAL_C   : std_logic_vector(1 downto 0) := "00"', pkg)
        self.assertIn('CALIBRATION_TAG_BNC_C      : std_logic_vector(1 downto 0) := "01"', pkg)
        self.assertIn('CALIBRATION_TAG_TIMING_C   : std_logic_vector(1 downto 0) := "10"', pkg)
        self.assertIn('CALIBRATION_TAG_SOFTWARE_C : std_logic_vector(1 downto 0) := "11"', pkg)

        self.assertIn("force_calibration_tag_i  : in  std_logic_vector(1 downto 0);", current)
        self.assertIn("calibration_tag : std_logic_vector(1 downto 0);", current)
        self.assertIn(
            'version_i(3 downto 0) & "0000" & active_frame_s.calibration_tag &',
            current,
        )
        self.assertIn(
            "event_calibration_tag_s <= force_calibration_tag_i when force_trigger_i = '1' else trigger_i.calibration_tag;",
            current,
        )
        self.assertIn("event_timestamp_s <= timestamp_i when force_trigger_i = '1' else trigger_i.trigger_timestamp;", current)
        self.assertIn("event_trigger_sample_s <= din_i when force_trigger_i = '1' else trigger_i.trigger_sample;", current)
        self.assertIn("queue_v(tail_v).calibration_tag := event_calibration_tag_s;", current)

    def test_current_xpm_memory_contracts_are_explicit(self) -> None:
        ring = read_repo("rtl/isolated/common/primitives/sample_ring_buffer.vhd")
        fifo = read_repo("rtl/isolated/common/primitives/sync_fifo_fwft.vhd")

        self.assertIn('MEMORY_PRIMITIVE        => "block"', ring)
        self.assertIn("READ_LATENCY_B          => 1", ring)
        self.assertIn('WRITE_MODE_B            => "read_first"', ring)
        self.assertIn('FIFO_MEMORY_TYPE    => "ultra"', fifo)
        self.assertIn('READ_MODE           => "fwft"', fifo)
        self.assertIn('USE_ADV_FEATURES    => "0202"', fifo)

    def test_formal_tree_did_not_change_between_reviewed_firmwares(self) -> None:
        changed = git_diff_names(
            "d7c9f04..5334b9f",
            "--",
            "formal",
            "scripts/formal",
            ".github/workflows/formal.yml",
        )
        self.assertEqual(changed, [])

    def test_readout_mux_dumps_after_one_ready_sample_gate(self) -> None:
        mux = read_repo("rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd")
        current = read_repo(BUILDER)

        frame_words = 8 + (natural_constant(current, "FRAME_SAMPLE_COUNT_C") // 32) * 7
        ready_threshold = frame_words - natural_constant(current, "FIFO_READY_MARGIN_C")

        self.assertEqual(frame_words, 120)
        self.assertEqual(ready_threshold, 108)
        self.assertLess(ready_threshold, frame_words)
        self.assertIn("if ready_i(CHANNEL_BASE_C + sel_s) = '1' then", mux)
        self.assertIn("state_s <= dump;", mux)
        self.assertIn('if fifo_dout_mux_s(71 downto 64) = X"ED" then', mux)
        self.assertIn("rd_en_o(CHANNEL_BASE_C + ch_idx) <= '1'", mux)
        self.assertIn("when (sel_s = ch_idx and state_s = dump)", mux)


if __name__ == "__main__":
    unittest.main()
