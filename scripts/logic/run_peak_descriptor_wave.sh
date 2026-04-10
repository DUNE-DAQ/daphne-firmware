#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
BUILD_DIR="${DAPHNE_PEAK_DESCRIPTOR_BUILD_ROOT:-$ROOT_DIR/build/peak-descriptor-wave}"
INPUT_FILE="${1:-/Users/marroyav/repo/daphne_mezz_xc_sim/data/input/run039344_ch35.txt}"

if [ ! -f "$INPUT_FILE" ]; then
  echo "ERROR: waveform file not found: $INPUT_FILE" >&2
  exit 2
fi

mkdir -p "$BUILD_DIR"

OUTPUT_CSV="${OUTPUT_CSV:-$BUILD_DIR/peak_descriptor_wave_events.csv}"
OUTPUT_VCD="${OUTPUT_VCD:-$BUILD_DIR/peak_descriptor_wave.vcd}"
GHDL_BIN="${GHDL_BIN:-${DAPHNE_GHDL_BIN:-ghdl}}"
BASELINE_SAMPLES="${BASELINE_SAMPLES:-512}"
BASELINE="${BASELINE:-$(awk -v limit="$BASELINE_SAMPLES" 'NF && $1 !~ /^#/ {sum += $1; count += 1; if (count >= limit) exit} END {if (count == 0) exit 1; print int(sum / count)}' "$INPUT_FILE")}"
TRIGGER_DELTA="${TRIGGER_DELTA:-64}"
TRIGGER_HOLDOFF="${TRIGGER_HOLDOFF:-1024}"
DESCRIPTOR_CONFIG="${DESCRIPTOR_CONFIG:-14029}"
MAX_SAMPLES="${MAX_SAMPLES:-4096}"
FLUSH_SAMPLES="${FLUSH_SAMPLES:-2048}"

cd "$BUILD_DIR"

"$GHDL_BIN" -a --std=08 \
  "$ROOT_DIR/rtl/isolated/common/daphne_subsystem_pkg.vhd" \
  "$ROOT_DIR/rtl/isolated/common/primitives/fixed_delay_line.vhd" \
  "$ROOT_DIR/ip_repo/daphne_ip/rtl/selftrig/ciemat_selftrig/PeakDetector_SelfTrigger_CIEMAT.vhd" \
  "$ROOT_DIR/ip_repo/daphne_ip/rtl/selftrig/ciemat_selftrig/LocalPrimitives_CIEMAT.vhd" \
  "$ROOT_DIR/ip_repo/daphne_ip/rtl/selftrig/ciemat_selftrig/Self_Trigger_Primitive_Calculation.vhd" \
  "$ROOT_DIR/rtl/isolated/subsystems/trigger/peak_descriptor_channel.vhd" \
  "$ROOT_DIR/tests/logic/peak_descriptor_wave_tb.vhd"

"$GHDL_BIN" -e --std=08 peak_descriptor_wave_tb

"$GHDL_BIN" -r --std=08 peak_descriptor_wave_tb \
  -gINPUT_FILE_G="$INPUT_FILE" \
  -gOUTPUT_FILE_G="$OUTPUT_CSV" \
  -gBASELINE_G="$BASELINE" \
  -gTRIGGER_DELTA_G="$TRIGGER_DELTA" \
  -gTRIGGER_HOLDOFF_G="$TRIGGER_HOLDOFF" \
  -gDESCRIPTOR_CONFIG_G="$DESCRIPTOR_CONFIG" \
  -gMAX_SAMPLES_G="$MAX_SAMPLES" \
  -gFLUSH_SAMPLES_G="$FLUSH_SAMPLES" \
  --assert-level=error \
  --vcd="$OUTPUT_VCD"

printf 'waveform: %s\n' "$INPUT_FILE"
printf 'baseline: %s\n' "$BASELINE"
printf 'events:   %s\n' "$OUTPUT_CSV"
printf 'vcd:      %s\n' "$OUTPUT_VCD"
