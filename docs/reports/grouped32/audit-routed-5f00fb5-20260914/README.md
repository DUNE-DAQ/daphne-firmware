# Routed checkpoint audit: `5f00fb5`

Vivado 2026.1 audited the pinned `5f00fb5` fully routed K26C checkpoint.
The audit command exited 0 and generated every requested report. The
checkpoint SHA-256 is
`2f487a873ca8f77036d2a8d5056a89118e8f78aae8b46508077fe44f69a19046`;
it remains in the local implementation directory. The exact audit Tcl and
Vivado log are preserved here. The route-status report records all 206,169
routable nets as fully routed, with zero routing errors.

This audit is **not timing or CDC sign-off**. Setup still fails at WNS
**-1.715 ns**, TNS **-187.241 ns**, and **1,383 endpoints**; 1,350 are in the
312.5 MHz builder. Hold and pulse-width have zero failing endpoints. The
routed DRC has zero errors and 842 warnings, mostly DSP input-pipelining
advisories. Bus-skew checks have no negative slack. Methodology still reports
12 `TIMING-6` and 20 `TIMING-7` critical clock-relationship warnings, along
with `TIMING-9` unknown CDC logic and missing interface delays.

The CDC report used a 1,000,000 clock-pair threshold. Its **117,610 detail
rows match the sum of all rule totals**, and there is no truncation warning.
There are 21,284 `CDC-1`, 81,377 `CDC-13`, and 14,608 `CDC-15` rows; most
arise on AXI-to-frontend paths. These are path/bit counts and need structural
classification, not an automatic count of independent defects. The detailed
report and exception-coverage report are included so individual crossings
and timing exceptions can be reviewed.

`check_timing` finds zero no-clock register pins and zero unconstrained
internal endpoints, but **41 input ports and 51 output ports lack external
delay constraints**. These include 32 AFE data inputs; a validated 16-bit,
62.5 MHz AFE output/board-skew model remains unavailable. All eight PS8 EMIO
peripheral clock outputs queried in `ps_emio_clock_fanout.tsv` exist and have
zero fabric endpoints; they are not active fabric clocks in this checkpoint.

The larger original reports are losslessly compressed. To verify and read:

```sh
sha256sum -c SHA256SUMS
gzip -dc cdc.rpt.gz | less
gzip -dc timing_summary.rpt.gz | less
```
