# Self-trigger 2026.08.24 release candidate

This is a source candidate for K26C DAPHNE self-trigger firmware. It is not a
released or production-qualified image.

Current status:

- all local GHDL smoke targets pass;
- all 30 checked-in formal proof/cover jobs pass;
- generated source manifests and documentation checks pass;
- the exact Cooper implementation and packaging run has **not run**;
- no candidate firmware ZIP, release checksum manifest, tag, or GitHub release
  exists yet.

## Build and check on Cooper

Use a clean detached checkout of the approved commit:

```bash
source /tools/2026.1/Vitis/settings64.sh

BUILD_SHA=$(git rev-parse --short=7 HEAD)
export DAPHNE_BOARD=k26c
export DAPHNE_ETH_MODE=create_ip
export DAPHNE_GIT_SHA="$BUILD_SHA"
export DAPHNE_MAX_THREADS=8
export DAPHNE_OUTPUT_DIR="$PWD/xilinx/output-$BUILD_SHA"

./scripts/fusesoc/refresh_cores.sh
git diff --exit-code -- daphne-ip.core daphne-ip-export.core
python3 scripts/check_documentation.py
python3 scripts/check_register_map.py
./scripts/fusesoc/preflight_vivado_build.sh
./scripts/fusesoc/build_platform.sh
./scripts/fusesoc/check_build_outputs.sh \
  "$DAPHNE_OUTPUT_DIR" "$BUILD_SHA"
```

The Linux build packages the overlay and writes `SHA256SUMS`. The final
checker line must start with `RESULT: PASS`.

## What the checker gates

- required bitstream, binary, XSA, DTBO, overlay, and checksum files exist;
- the XSA and overlay ZIP are readable and the DTBO parses;
- packaged-file checksums match;
- all user timing constraints are met;
- no error-level DRC result or violated bus-skew constraint is present;
- routed-net status reports zero routing errors;
- CDC and methodology critical classifications are printed as explicit review
  limitations rather than hidden.

These checks validate a build, not a board.

## Board gate

Before promotion, test one isolated board at a time:

1. Load the exact checked overlay and record its commit/checksum.
2. Configure all 40 channels and read every exposed setting back.
3. Capture waveforms and RMS statistics in standalone mode.
4. Connect the timing master, verify endpoint readiness/timestamps, and record
   timing-command behavior.
5. Take self-trigger data with the approved timing-command sequence.
6. Verify Hermes/DAQ receiver connectivity and error counters.
7. Measure power in the agreed idle and acquisition configurations.
8. Demonstrate recovery to the qualified `06306ed` image.

Keep the board asset, SOM identity, firmware SHA, profiles, commands, logs,
waveforms, counters, power readings, and failures in one evidence directory.

## Easy recovery notes

- Missing `RESULT: PASS`: do not package, tag, or load the candidate.
- Timing or routing failure: retain the output directory and inspect the named
  report before rebuilding.
- Overlay packaging failed after Vivado finished: keep the `.bit`, `.bin`, and
  `.xsa`, then rerun `scripts/package/complete_dtbo_bundle.sh` on that output
  directory.
- Board behavior regressed: stop the test and return to the checked `06306ed`
  recovery kit.
