# Routed checkpoint audit: `5d83890`

Vivado 2026.1 audited the pinned `5d83890` fully routed K26C checkpoint.
The audit command exited 0 and generated every requested report. The
checkpoint SHA-256 is
`00a67934a884b0d4b13b725ba8a3e3c72ac533fffae31199133b067e41ecda9c`;
it remains in the local implementation directory. The exact audit Tcl and
Vivado log are preserved here. The route-status report records all 206,103
routable nets as fully routed, with zero routing errors.

This audit is **not timing or CDC sign-off**. Setup fails at WNS **-2.192 ns**,
TNS **-82.082 ns**, and **472 endpoints**; 440 are in the 312.5 MHz builder.
Hold and pulse-width have zero failing endpoints. The routed DRC has zero
errors and 842 warnings, mostly DSP input-pipelining advisories. All 87 bus-skew
checks pass. Methodology retains 12 `TIMING-6` and 20 `TIMING-7` critical
clock-relationship warnings, along with unknown CDC logic and missing interface
delays.

The CDC report used a 1,000,000 clock-pair threshold. Its **117,610 detail rows
match the sum of all rule totals**, and there is no truncation warning. There
are 21,284 `CDC-1`, 81,377 `CDC-13`, and 14,608 `CDC-15` rows; most arise on
AXI-to-frontend paths. These are path and bit counts that require structural
classification. The detailed report and exception-coverage report are included
for individual crossing and timing-exception review.

`check_timing` finds zero no-clock register pins and zero unconstrained internal
endpoints, but **41 input ports and 51 output ports lack external delay
constraints**. These include 32 AFE data inputs. The board is confirmed to use
the AFE5808A in 16-bit LVDS mode at 62.5 MHz, or 1 Gb/s per lane; a validated
AFE output-delay and K26C PCB-skew min/max model remains unavailable. All eight
PS8 EMIO peripheral clock outputs queried in `ps_emio_clock_fanout.tsv` exist
and have zero fabric endpoints.

The larger original reports are losslessly compressed. To verify and read:

```sh
sha256sum -c SHA256SUMS
gzip -dc cdc.rpt.gz | less
gzip -dc timing_summary.rpt.gz | less
```
