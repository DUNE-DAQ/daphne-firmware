#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"

FRONTEND_ISLAND="$ROOT_DIR/rtl/isolated/subsystems/frontend/frontend_island.vhd"
LEGACY_FRONTEND="$ROOT_DIR/ip_repo/daphne_ip/rtl/frontend/front_end.vhd"
FEBIT3="$ROOT_DIR/ip_repo/daphne_ip/rtl/frontend/febit3.vhd"
ENDPOINT_RTL="$ROOT_DIR/ip_repo/daphne_ip/rtl/timing/endpoint.vhd"

require_file() {
  if [ ! -f "$1" ]; then
    echo "ERROR: required file not found: $1" >&2
    exit 2
  fi
}

require_regex() {
  pattern="$1"
  file_path="$2"
  description="$3"
  if ! rg -q "$pattern" "$file_path"; then
    echo "ERROR: $description" >&2
    echo "INFO: missing pattern: $pattern" >&2
    echo "INFO: file: $file_path" >&2
    exit 1
  fi
}

for file_path in "$FRONTEND_ISLAND" "$LEGACY_FRONTEND" "$FEBIT3" "$ENDPOINT_RTL"; do
  require_file "$file_path"
done

require_regex "clk500[[:space:]]*:[[:space:]]*in[[:space:]]+std_logic" "$LEGACY_FRONTEND" \
  "legacy front_end no longer exposes the 500 MHz frontend bit clock."
require_regex "clk125[[:space:]]*:[[:space:]]*in[[:space:]]+std_logic" "$LEGACY_FRONTEND" \
  "legacy front_end no longer exposes the 125 MHz frontend byte clock."
require_regex "clock[[:space:]]*:[[:space:]]*in[[:space:]]+std_logic" "$LEGACY_FRONTEND" \
  "legacy front_end no longer exposes the 62.5 MHz frontend master clock."
require_regex "clk500[[:space:]]*=>[[:space:]]*clk500" "$LEGACY_FRONTEND" \
  "legacy front_end no longer passes clk500 into frontend_island."
require_regex "clk125[[:space:]]*=>[[:space:]]*clk125" "$LEGACY_FRONTEND" \
  "legacy front_end no longer passes clk125 into frontend_island."
require_regex "clock[[:space:]]*=>[[:space:]]*clock" "$LEGACY_FRONTEND" \
  "legacy front_end no longer passes clock into frontend_island."

require_regex "clk500[[:space:]]*:[[:space:]]*in[[:space:]]+std_logic" "$FRONTEND_ISLAND" \
  "frontend_island no longer accepts the 500 MHz frontend bit clock."
require_regex "clk125[[:space:]]*:[[:space:]]*in[[:space:]]+std_logic" "$FRONTEND_ISLAND" \
  "frontend_island no longer accepts the 125 MHz frontend byte clock."
require_regex "clock[[:space:]]*:[[:space:]]*in[[:space:]]+std_logic" "$FRONTEND_ISLAND" \
  "frontend_island no longer accepts the 62.5 MHz frontend master clock."
require_regex "clk500_i[[:space:]]*=>[[:space:]]*clk500" "$FRONTEND_ISLAND" \
  "frontend_island no longer passes clk500 into the capture bank/common block."
require_regex "clk125_i[[:space:]]*=>[[:space:]]*clk125" "$FRONTEND_ISLAND" \
  "frontend_island no longer passes clk125 into the capture bank/common block."
require_regex "clock_i[[:space:]]*=>[[:space:]]*clock" "$FRONTEND_ISLAND" \
  "frontend_island no longer passes clock into the capture bank/common block."

require_regex "The three clocks must be frequency locked and have the rising edges aligned\\." "$FEBIT3" \
  "febit3 no longer documents the aligned three-clock frontend contract."
require_regex "CLK[[:space:]]*=>[[:space:]]*clk500" "$FEBIT3" \
  "febit3 no longer drives ISERDESE3 from clk500."
require_regex "CLKDIV[[:space:]]*=>[[:space:]]*clk125" "$FEBIT3" \
  "febit3 no longer drives the byte-rate divider clock from clk125."
require_regex "process\\(clock\\)" "$FEBIT3" \
  "febit3 no longer performs word assembly in the frontend master-clock domain."

require_regex "mmcm1_clk0_inst:[[:space:]]*BUFG port map\\( I => mmcm1_clkout0, O => clk500\\);" "$ENDPOINT_RTL" \
  "endpoint no longer exposes the 500 MHz frontend bit clock from MMCM1 CLKOUT0."
require_regex "mmcm1_clk2_inst[[:space:]]*:[[:space:]]*BUFGCE_DIV" "$ENDPOINT_RTL" \
  "endpoint no longer derives the 125 MHz frontend byte clock through BUFGCE_DIV."
require_regex "port map \\( I => mmcm1_clkout0, O => clk125, CE => '1', CLR => '0'\\);" "$ENDPOINT_RTL" \
  "endpoint no longer feeds clk125 from the 500 MHz MMCM1 output."
require_regex "mmcm1_clk1_inst:[[:space:]]*BUFG port map\\( I => mmcm1_clkout1, O => clock_i\\);" "$ENDPOINT_RTL" \
  "endpoint no longer exposes the 62.5 MHz frontend master clock from MMCM1 CLKOUT1."

echo "INFO: Frontend clock contract matches the live endpoint/frontend RTL: clock, clk500, and clk125 remain aligned and consistently wired."
