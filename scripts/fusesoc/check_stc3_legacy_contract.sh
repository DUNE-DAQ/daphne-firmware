#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
LEGACY_ROOT="${DAPHNE_LEGACY_ROOT:-$ROOT_DIR/../Daphne_MEZZ}"

CURRENT_STC3="$ROOT_DIR/ip_repo/daphne_ip/rtl/selftrig/stc3.vhd"
CURRENT_RECORD_BUILDER="$ROOT_DIR/rtl/isolated/subsystems/trigger/stc3_record_builder.vhd"
CURRENT_XCORR_WRAPPER="$ROOT_DIR/rtl/isolated/subsystems/trigger/self_trigger_xcorr_channel.vhd"
CURRENT_DESCRIPTOR_WRAPPER="$ROOT_DIR/rtl/isolated/subsystems/trigger/peak_descriptor_channel.vhd"
CURRENT_TB="$ROOT_DIR/ip_repo/daphne_ip/sim/selftrig/stc3_testbench.vhd"
CURRENT_VECTOR="$ROOT_DIR/ip_repo/daphne_ip/sim/selftrig/stc3_testbench.txt"

LEGACY_STC3="$LEGACY_ROOT/ip_repo/daphne3_ip/rtl/selftrig/stc3.vhd"
LEGACY_TB="$LEGACY_ROOT/ip_repo/daphne3_ip/sim/selftrig/stc3_testbench.vhd"
LEGACY_VECTOR="$LEGACY_ROOT/ip_repo/daphne3_ip/sim/selftrig/stc3_testbench.txt"

require_file() {
  if [ ! -f "$1" ]; then
    echo "ERROR: missing required file: $1" >&2
    exit 1
  fi
}

require_pattern() {
  pattern="$1"
  file="$2"
  label="$3"
  if ! rg -n --fixed-strings -- "$pattern" "$file" >/dev/null 2>&1; then
    echo "ERROR: missing legacy STC3 contract fragment for $label" >&2
    echo "Pattern: $pattern" >&2
    echo "File: $file" >&2
    exit 1
  fi
}

require_file "$CURRENT_STC3"
require_file "$CURRENT_RECORD_BUILDER"
require_file "$CURRENT_XCORR_WRAPPER"
require_file "$CURRENT_DESCRIPTOR_WRAPPER"
require_file "$CURRENT_TB"
require_file "$CURRENT_VECTOR"
require_file "$LEGACY_STC3"
require_file "$LEGACY_TB"
require_file "$LEGACY_VECTOR"

if ! cmp -s "$LEGACY_VECTOR" "$CURRENT_VECTOR"; then
  echo "ERROR: STC3 legacy stimulus drifted from Daphne_MEZZ." >&2
  exit 1
fi

old_tb_body="$(mktemp)"
new_tb_body="$(mktemp)"
trap 'rm -f "$old_tb_body" "$new_tb_body"' EXIT INT TERM HUP

sed '1d' "$LEGACY_TB" >"$old_tb_body"
sed '1d' "$CURRENT_TB" >"$new_tb_body"
if ! cmp -s "$old_tb_body" "$new_tb_body"; then
  echo "ERROR: STC3 legacy testbench changed beyond the banner comment." >&2
  exit 1
fi

require_pattern "sample0_ts <= std_logic_vector( unsigned(trig_sample_ts) - 64 );" "$LEGACY_STC3" "legacy sample0 timestamp offset"
require_pattern "FIFO_WRITE_DEPTH => 4096," "$LEGACY_STC3" "legacy FIFO depth"
require_pattern "PROG_EMPTY_THRESH => 220," "$LEGACY_STC3" "legacy FIFO prog_empty threshold"
require_pattern "PROG_FULL_THRESH => 200," "$LEGACY_STC3" "legacy FIFO prog_full threshold"
require_pattern "marker & sample0_ts when (state=h1) else" "$LEGACY_STC3" "legacy header word 0 packing"
require_pattern "marker & ch_id(7 downto 0) & version(3 downto 0) & \"000000\" & calculated_baseline(13 downto 0) & \"00\" & threshold_xc(13 downto 0) & \"00\" & trig_sample_dat(13 downto 0) when (state=h2) else" "$LEGACY_STC3" "legacy header word 1 packing"
require_pattern "marker & Trailer_Word_1_reg(31 downto 0) & Trailer_Word_0_reg(31 downto 0) when (state=h3) else" "$LEGACY_STC3" "legacy trailer header packing"
require_pattern "marker & R0(7 downto 0) & R1 & R2 & R3 & R4                    when (state=d0) else" "$LEGACY_STC3" "legacy dense pack first word"
require_pattern "marker & R0 & R1 & R2 & R3 & R4(13 downto 6)                   when (state=d27) else" "$LEGACY_STC3" "legacy dense pack last word"

require_pattern "trig_xc_inst : trig_xc" "$CURRENT_XCORR_WRAPPER" "current trigger algorithm import"
require_pattern "descriptor_inst : Self_Trigger_Primitive_Calculation" "$CURRENT_DESCRIPTOR_WRAPPER" "current descriptor algorithm import"
require_pattern "record_builder_inst: entity work.stc3_record_builder" "$CURRENT_STC3" "current STC3 record-builder split"
require_pattern "fixed_delay_inst : entity work.fixed_delay_line" "$CURRENT_RECORD_BUILDER" "current fixed delay line"
require_pattern "DELAY_G => 288" "$CURRENT_RECORD_BUILDER" "current fixed delay length"
require_pattern "sample0_ts_s <= std_logic_vector(unsigned(trigger_i.trigger_timestamp) - 64);" "$CURRENT_RECORD_BUILDER" "current sample0 timestamp offset"
require_pattern "marker_s <= X\"BE\" when (state_s = h1) else" "$CURRENT_RECORD_BUILDER" "current first-word marker"
require_pattern "X\"ED\" when (state_s = d27 and block_count_s = 31) else" "$CURRENT_RECORD_BUILDER" "current last-word marker"
require_pattern "fifo_din_s <= marker_s & sample0_ts_s when (state_s = h1) else" "$CURRENT_RECORD_BUILDER" "current header word 0 packing"
require_pattern "marker_s & ch_id_i(7 downto 0) & version_i(3 downto 0) & \"000000\" &" "$CURRENT_RECORD_BUILDER" "current header word 1 packing"
require_pattern "trigger_i.baseline(13 downto 0) & \"00\" & threshold_xc_i(13 downto 0) &" "$CURRENT_RECORD_BUILDER" "current baseline-threshold packing"
require_pattern "\"00\" & trigger_i.trigger_sample(13 downto 0) when (state_s = h2) else" "$CURRENT_RECORD_BUILDER" "current trigger sample packing"
require_pattern "marker_s & trailer_reg_s(1) & trailer_reg_s(0) when (state_s = h3) else" "$CURRENT_RECORD_BUILDER" "current trailer header packing"
require_pattern "marker_s & r0_s(7 downto 0) & r1_s & r2_s & r3_s & r4_s when (state_s = d0) else" "$CURRENT_RECORD_BUILDER" "current dense pack first word"
require_pattern "marker_s & r0_s & r1_s & r2_s & r3_s & r4_s(13 downto 6) when (state_s = d27) else" "$CURRENT_RECORD_BUILDER" "current dense pack last word"
require_pattern "output_fifo_inst : entity work.sync_fifo_fwft" "$CURRENT_RECORD_BUILDER" "current FIFO wrapper"
require_pattern "DATA_WIDTH_G        => 72," "$CURRENT_RECORD_BUILDER" "current FIFO width"
require_pattern "DEPTH_G             => 4096," "$CURRENT_RECORD_BUILDER" "current FIFO depth"
require_pattern "COUNT_WIDTH_G       => 13," "$CURRENT_RECORD_BUILDER" "current FIFO count width"
require_pattern "PROG_EMPTY_THRESH_G => 220," "$CURRENT_RECORD_BUILDER" "current FIFO prog_empty threshold"
require_pattern "PROG_FULL_THRESH_G  => 200" "$CURRENT_RECORD_BUILDER" "current FIFO prog_full threshold"
require_pattern "ready_o          <= not prog_empty_s;" "$CURRENT_RECORD_BUILDER" "current ready semantics"

echo "STC3 legacy continuity contract checks passed."
