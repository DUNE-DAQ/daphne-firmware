#!/usr/bin/env bash
# Supply this helper externally so both runs can use the same immutable source.
# Run sequentially after the production build; never benchmark a busy host.
set -euo pipefail
source_root="$(realpath "${1:?fresh immutable source clone}")"
run_root="${2:?new evidence directory}"
directive="${3:?PerformanceOptimized or RuntimeOptimized}"
case "$directive" in
  PerformanceOptimized|RuntimeOptimized) ;;
  *) echo "Unsupported synthesis benchmark directive: $directive" >&2; exit 2 ;;
esac
export PATH="/tools/2026.1/Vivado/bin:/tools/2026.1/Vitis/bin:/tools/bin:/home/arroyave/.local/bin:/usr/local/bin:/usr/bin:/bin:/tools/petalinux/sysroots/x86_64-petalinux-linux/usr/bin"
unset LD_LIBRARY_PATH LD_PRELOAD PYTHONHOME PYTHONPATH
test -z "$(git -C "$source_root" status --porcelain=v1 --untracked-files=no)"
for generated in build .Xil xilinx/.Xil; do
  if [[ -e "$source_root/$generated" ]]; then
    echo "Use a fresh clone; found $source_root/$generated" >&2; exit 2
  fi
done
if pgrep -f '/unwrapped/lnx64.o/(vivado|xelab|xsim)' >/dev/null; then
  echo "Host has an active vendor job; benchmark not started." >&2; exit 2
fi
mkdir "$run_root"
run_root="$(realpath "$run_root")"
date -u +%FT%TZ > "$run_root/started.txt"
trap 'code=$?; printf "%s\n" "$code" > "$run_root/exit-code.txt"; date -u +%FT%TZ > "$run_root/finished.txt"' EXIT
export XILINX_VIVADO=/tools/2026.1/Vivado
export XILINX_VITIS=/tools/2026.1/Vitis
export DAPHNE_BOARD=k26c DAPHNE_ETH_MODE=create_ip DAPHNE_MAX_THREADS=4
export DAPHNE_SYNTH_DIRECTIVE="$directive"
export DAPHNE_STOP_AFTER_SYNTH=1 DAPHNE_REMOTE_PACKAGE_DTBO=0
export DAPHNE_SKIP_POST_SYNTH_REPORTS=0 DAPHNE_SKIP_POST_SYNTH_CHECKPOINT=0
export DAPHNE_REMOTE_LOG_DIR="$run_root/flow" DAPHNE_REMOTE_RUN_ID=synthesis
DAPHNE_GIT_SHA="$(git -C "$source_root" rev-parse --short=7 HEAD)"
export DAPHNE_GIT_SHA
export DAPHNE_OUTPUT_DIR="./output-$DAPHNE_GIT_SHA"
{
  hostname
  git -C "$source_root" rev-parse HEAD
  printf 'directive=%s\nthreads=4\n' "$directive"
  env | sort | sed -n '/^DAPHNE_/p'
  free -h
} > "$run_root/environment.txt"
git -C "$source_root" archive HEAD | sha256sum > "$run_root/source-archive.sha256"
sha256sum "$(realpath "$0")" > "$run_root/helper.sha256"
vivado -version > "$run_root/vivado-version.txt"
cd "$source_root"
bash scripts/remote/run_remote_vivado_chain.sh > "$run_root/build.log" 2>&1
output_root="$source_root/xilinx/output-$DAPHNE_GIT_SHA"
test -s "$output_root/build-phase-times.tsv"
test -s "$output_root/post_synth_util.rpt"
test -s "$output_root/post_synth_timing_summary.rpt"
cp "$output_root/build-phase-times.tsv" "$output_root/post_synth_util.rpt" \
  "$output_root/post_synth_timing_summary.rpt" "$run_root/"
printf 'Synthesis comparison only; routed timing is not qualified.\n' > "$run_root/result.txt"
