#!/usr/bin/env bash
# One immutable candidate, vendor gates first, then the qualified build flow.
set -euo pipefail
source_root="$(realpath "${1:?immutable source clone}")"
run_root="$(realpath "${2:?existing unique campaign directory}")"
test ! -e "$run_root/campaign.started"
export PATH="/tools/2026.1/Vivado/bin:/tools/2026.1/Vitis/bin:/tools/bin:/home/arroyave/.local/bin:/usr/local/bin:/usr/bin:/bin:/tools/petalinux/sysroots/x86_64-petalinux-linux/usr/bin"
unset LD_LIBRARY_PATH LD_PRELOAD PYTHONHOME PYTHONPATH
export XILINX_VIVADO=/tools/2026.1/Vivado
export XILINX_VITIS=/tools/2026.1/Vitis
export DAPHNE_MAX_THREADS="${DAPHNE_MAX_THREADS:-4}"
test -z "$(git -C "$source_root" status --porcelain=v1 --untracked-files=no)"
date -u +%FT%TZ > "$run_root/campaign.started"
trap 'code=$?; printf "%s\n" "$code" > "$run_root/campaign.exit-code"; date -u +%FT%TZ > "$run_root/campaign.finished"' EXIT
git -C "$source_root" rev-parse HEAD > "$run_root/source-commit.txt"
printf 'vendor-hermes\n' > "$run_root/campaign.stage"
bash "$source_root/scripts/remote/cooper_hermes_admission_sim.sh" "$source_root" "$run_root/vendor-hermes" > "$run_root/vendor-hermes.log" 2>&1
printf 'vendor-grouped\n' > "$run_root/campaign.stage"
python3 "$source_root/scripts/verification/run_grouped32_vendor_tests.py" --output-dir "$run_root/vendor-grouped" --mode 0 > "$run_root/vendor-grouped.log" 2>&1
printf 'implementation\n' > "$run_root/campaign.stage"
bash "$source_root/scripts/remote/cooper_clean_build.sh" "$source_root" "$run_root/evidence" > "$run_root/implementation.log" 2>&1
printf 'artifacts-awaiting-qualification\n' > "$run_root/campaign.stage"
