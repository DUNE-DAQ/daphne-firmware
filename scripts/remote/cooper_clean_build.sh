#!/usr/bin/env bash
# Run on Cooper in a fresh clone created from a local git bundle.
set -euo pipefail

source_root="${1:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
source_root="$(CDPATH= cd -- "$source_root" && pwd)"
evidence_root="${2:-$(dirname -- "$source_root")/evidence}"

if [[ -e "$source_root/build" || -e "$source_root/.Xil" || -e "$source_root/xilinx/.Xil" ]]; then
  echo "ERROR: use a new clone; generated build state already exists." >&2
  exit 2
fi
if [[ -n "$(git -C "$source_root" status --porcelain=v1 --untracked-files=no)" ]]; then
  echo "ERROR: tracked source differs from the commit to be built." >&2
  exit 2
fi
mkdir -p "$evidence_root"
evidence_root="$(CDPATH= cd -- "$evidence_root" && pwd)"
if [[ -e "$evidence_root/build.started" ]]; then
  echo "ERROR: this evidence directory already records a build attempt." >&2
  exit 2
fi
date -u +%FT%TZ > "$evidence_root/build.started"
trap 'result=$?; printf "%s\n" "$result" > "$evidence_root/build.exit-code"; date -u +%FT%TZ > "$evidence_root/build.finished"' EXIT

# Prefer system Python/shell tools. Cooper supplies Git and Make only through
# the SDK, so retain its usr/bin as a fallback after the normal system paths.
export PATH="/tools/2026.1/Vivado/bin:/tools/2026.1/Vitis/bin:/tools/bin:/home/arroyave/.local/bin:/usr/local/bin:/usr/bin:/bin:/tools/petalinux/sysroots/x86_64-petalinux-linux/usr/bin"
unset LD_LIBRARY_PATH LD_PRELOAD PYTHONHOME PYTHONPATH
export XILINX_VIVADO=/tools/2026.1/Vivado
export XILINX_VITIS=/tools/2026.1/Vitis
for command_name in git bash sed date sha256sum hostname uname vivado sdtgen dtc python3 fusesoc make zip unzip tclsh; do
  command -v "$command_name" >> "$evidence_root/tool-paths.txt" || {
    echo "ERROR: required build tool is unavailable: $command_name" >&2
    exit 2
  }
done
export DAPHNE_BOARD=k26c
export DAPHNE_ETH_MODE=create_ip
export DAPHNE_MAX_THREADS="${DAPHNE_MAX_THREADS:-4}"
DAPHNE_GIT_SHA="$(git -C "$source_root" rev-parse --short=7 HEAD)"
export DAPHNE_GIT_SHA
export DAPHNE_OUTPUT_DIR="./output-$DAPHNE_GIT_SHA"
export DAPHNE_REMOTE_PACKAGE_DTBO=1
export DAPHNE_REMOTE_LOG_DIR="$evidence_root/remote-vivado"
export DAPHNE_REMOTE_RUN_ID=clean-build
unset DAPHNE_STOP_AFTER_SYNTH DAPHNE_SKIP_POST_SYNTH_REPORTS DAPHNE_SKIP_POST_SYNTH_CHECKPOINT

{
  printf 'host=%s\nsource_root=%s\n' "$(hostname)" "$source_root"
  printf 'commit=%s\nbranch=%s\n' "$(git -C "$source_root" rev-parse HEAD)" "$(git -C "$source_root" branch --show-current)"
  printf 'board=%s\neth_mode=%s\nthreads=%s\n' "$DAPHNE_BOARD" "$DAPHNE_ETH_MODE" "$DAPHNE_MAX_THREADS"
  printf 'vivado=%s\nvitis=%s\npath=%s\n' "$XILINX_VIVADO" "$XILINX_VITIS" "$PATH"
  uname -a
} > "$evidence_root/source-and-environment.txt"
git -C "$source_root" archive --format=tar HEAD | sha256sum > "$evidence_root/source-archive.sha256"
git -C "$source_root" status --porcelain=v1 > "$evidence_root/source-status.before.txt"
vivado -version > "$evidence_root/vivado-version.txt" 2>&1
sha256sum "$XILINX_VIVADO/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" > "$evidence_root/xpm-memory.sha256"
sed -n '616,640p' "$XILINX_VIVADO/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" > "$evidence_root/xpm-memory-uram-constraints.txt"

cd "$source_root"
# The legacy wrapper uses tee; explicitly enable pipefail so a failed tool
# does not look successful merely because its log was written successfully.
bash -o pipefail ./scripts/remote/run_remote_vivado_chain.sh 2>&1 | tee "$evidence_root/build.log"

output_root="$source_root/xilinx/output-$DAPHNE_GIT_SHA"
for extension in bit bin xsa dtbo; do
  test -s "$output_root/daphne_selftrigger_${DAPHNE_GIT_SHA}.$extension"
done
test -s "$output_root/daphne_selftrigger_ol_${DAPHNE_GIT_SHA}.zip"
for report in post_route_timing_summary.rpt post_route_util.rpt post_imp_drc.rpt; do
  test -s "$output_root/$report"
done
(cd "$output_root" && sha256sum --check SHA256SUMS) | tee "$evidence_root/package-checksums.check.txt"
git status --porcelain=v1 > "$evidence_root/source-status.after.txt"
printf 'Artifacts produced; review timing, DRC and methodology before qualification.\n' > "$evidence_root/artifact-status.txt"
