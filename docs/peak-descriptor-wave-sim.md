# Peak Descriptor Wave Simulation

This repo now has a local single-channel descriptor bench that reads a waveform
text file, drives the RTL peak-descriptor path, and emits both an event CSV and
a VCD.

## Scope

This bench is intentionally narrow:

- It drives the real RTL in [peak_descriptor_channel.vhd](../rtl/isolated/subsystems/trigger/peak_descriptor_channel.vhd).
- It uses the imported CIEMAT descriptor blocks underneath that wrapper.
- It does **not** run the full `st_xc` cross-correlation trigger chain.
- It generates the external trigger pulse in the testbench with a simple
  threshold crossing over the raw waveform plus a configurable holdoff.

That split is deliberate. The full matched-filter path still depends on the
vendor-heavy `st_xc` / `DSP48E2` side, whereas this bench is pure VHDL and runs
locally with GHDL.

## Runner

Use [run_peak_descriptor_wave.sh](../scripts/logic/run_peak_descriptor_wave.sh):

```sh
./scripts/logic/run_peak_descriptor_wave.sh \
  /Users/marroyav/repo/daphne_mezz_xc_sim/data/input/run039344_ch35.txt
```

Defaults:

- `BASELINE` is inferred as the mean of the first `BASELINE_SAMPLES` samples
  (`512` by default).
- `TRIGGER_DELTA=64`
- `TRIGGER_HOLDOFF=1024`
- `MAX_SAMPLES=4096`
- `FLUSH_SAMPLES=2048`
- `DESCRIPTOR_CONFIG=14029` (`0x36CD`)

Useful overrides:

```sh
BASELINE=2799 \
TRIGGER_DELTA=128 \
MAX_SAMPLES=20000 \
OUTPUT_CSV=/tmp/peak.csv \
OUTPUT_VCD=/tmp/peak.vcd \
./scripts/logic/run_peak_descriptor_wave.sh \
  /Users/marroyav/repo/daphne_mezz_xc_sim/data/input/run039344_ch35.txt
```

## Outputs

The CSV reports only interesting cycles:

- bench trigger pulse
- descriptor self-trigger
- peak-current pulse
- descriptor metadata availability
- trailer availability

Columns include:

- `sample_idx`
- `timestamp`
- `raw_sample`
- `baseline`
- `trigger_pulse`
- `self_trigger`
- `data_available`
- `trailer_available`
- `time_peak`
- `time_over_baseline`
- `time_start`
- `adc_peak`
- `adc_integral`
- `number_peaks`
- `amplitude`
- `peak_current`
- `slope_current`
- `slope_threshold`
- `detection`
- `sending`
- `info_previous`
- `trailer0`
- `trailer1`

The VCD is useful when the CSV shows an event but the exact timing still needs
inspection in a waveform viewer.

## Current limitation

If you need the descriptor timing to match the firmware trigger path exactly,
the next step is a second bench around `self_trigger_xcorr_channel` or `stc3`
under XSim. This local bench is intended to answer the narrower question:
"given a real single-channel waveform, what does the RTL descriptor logic do?"
