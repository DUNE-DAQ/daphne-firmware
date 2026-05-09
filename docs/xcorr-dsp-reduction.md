# XCorr DSP Reduction

## Problem

The baseline K26 implementation used almost all available DSP slices:

- `1240 / 1248 DSP48E2 = 99.36%`
- the self-trigger xcorr path accounts for the dominant share
- `1240 DSP / 40 channels = 31 DSP/channel`

The split is visible in the RTL:

- `26 DSP/channel` came from `st_xc.vhd`, one DSP48E2 per nonzero matched-filter coefficient.
- `5 DSP/channel` remains in `IIRFilter_afe_integrator_optimized.v`, the AFE compensation IIR.

The xcorr coefficients are small constants in `[-7, 1]`, so a full DSP48E2 per
coefficient is unnecessary.

## Change

`ip_repo/daphne_ip/rtl/selftrig/eia_selftrig/st_xc.vhd` now keeps the same entity,
ports, 28-bit threshold input, 28-bit `xcorr_calc` output, and trigger condition,
but replaces the per-coefficient DSP chain with a 21-bit shift/add implementation.

The transposed FIR pipeline shape is preserved:

- same 32 coefficient positions
- same two-stage tap pipeline model
- same threshold crossing logic
- same external `xcorr_calc` width, via sign extension from the compact internal result

`dsp_xc.vhd` is no longer listed in the FuseSoC self-trigger file sets.

## Precision Result

The C++ xcorr simulator now supports:

```sh
--xcorr-limit-bits N
```

The sweep command used was:

```sh
python3 scripts/sweep_xcorr_precision.py \
  --threshold 500 --threshold 1000 --threshold 2000 --threshold 5000 \
  --bits 21 20 18 16 14 13 12
```

Summary artifact:

```text
../daphne_mezz_xc_sim/data/output/analysis/xcorr_precision/summary.csv
```

Result:

- `21` signed bits preserved trigger sequence, frame starts, and descriptor-valid sequence on the tested inputs.
- `20` signed bits already changed CFD timing on large-pulse inputs.
- Therefore the RTL keeps `21` internal signed bits for this first buildable cut.

## Expected Resource Effect

Expected DSP reduction:

- old xcorr: `26 DSP/channel x 40 channels = 1040 DSP`
- new xcorr: expected `0 DSP` for xcorr if Vivado keeps the shift/add implementation in CLB/carry logic
- remaining AFE IIR: `5 DSP/channel x 40 channels = 200 DSP`

This is the correct next synthesis experiment. It trades some CLB/carry logic for
a very large DSP reduction. If CLB growth is too high, the next cut should move
from this exact transposed replacement to a grouped direct-form adder tree that
shares coefficient groups before weighting.

## Verification Performed

- `ghdl -a --std=08 ip_repo/daphne_ip/rtl/selftrig/eia_selftrig/st_xc.vhd`
- `make st_xc_sim` in `../daphne_mezz_xc_sim`
- precision sweep summary generated in `../daphne_mezz_xc_sim/data/output/analysis/xcorr_precision/summary.csv`
