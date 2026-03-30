# st_xc C++ simulation

Simple C++ model of the self-trigger matched filter in
`ip_repo/daphne3_ip/rtl/selftrig/eia_selftrig/st_xc.vhd`.

It computes a 32-tap cross-correlation (FIR) using the same template coefficients
and produces a trigger when the correlation crosses the threshold with a simple
3-sample peak detector.

## Build

```sh
g++ -O2 -std=c++17 -o st_xc_sim st_xc_sim.cpp
```

## Run

Input file format: one integer sample per line. Lines starting with `#` are ignored.

```sh
./st_xc_sim --input waveform.txt --output xcorr_out.csv --threshold 2000
```

If your input is unsigned 14-bit ADC counts (0..16383), use:

```sh
./st_xc_sim --input waveform.txt --output xcorr_out.csv --threshold 2000 --unsigned14
```

To override the template coefficients (must be 32 integers, one per line):

```sh
./st_xc_sim --input waveform.txt --template my_template.txt
```

## Plot

```sh
python3 plot_st_xc.py xcorr_out.csv
```

## Output

The CSV contains:

```
index,raw,xcorr,trigger
```

- `raw` is the signed 14-bit sample used by the filter.
- `xcorr` is the moving correlation output.
- `trigger` is 1 when the peak detector condition is met.
