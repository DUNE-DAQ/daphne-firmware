# Routed checkpoint audit: `f3d84ab`

Vivado 2026.1 independently reopened and audited the pinned `f3d84ab` fully
routed K26C checkpoint. The audit command exited 0 and generated every
requested report. The checkpoint SHA-256 is
`2819a1cdb1392736a1dd736c6941fb27733080610ab3d59b7ce75fac7a88f6b5`;
it remains in the local implementation directory. The exact audit Tcl and
Vivado log are preserved here. The route-status report records all 206,146
routable nets as fully routed, with zero routing errors.

The reopened checkpoint reproduces clean internal timing: setup WNS is
**+0.048 ns** with zero failing endpoints, hold WHS is **+0.010 ns** with zero
failing endpoints, and pulse-width slack is **+0.280 ns** with zero failing
endpoints. All 87 bus-skew checks meet their constraints; the minimum reported
bus-skew slack is **+1.604 ns**. The routed DRC has zero errors and 842
warnings, predominantly the 832 DSP input-pipelining advisories. Methodology
reports eight `TIMING-7` related-clock warnings and no `TIMING-6` warnings.

The CDC report used a 1,000,000 clock-pair threshold. Its rule totals sum to
**117,610 reported paths/bits**, and there is no truncation warning. The
summary is 21,280 `CDC-1`, 250 `CDC-3`, 8 `CDC-6`, 13 `CDC-9`, 35
`CDC-10`, 4 `CDC-11`, 3 `CDC-12`, 81,377 `CDC-13`, 32 `CDC-14`, and 14,608
`CDC-15` rows. These are path/bit counts, largely including false-pathed
frontend IDELAY primitives, vendor IP, and FIFO structures; they are not an
automatic count of independent defects. The detailed CDC and
exception-coverage reports are included for structural review.

`check_timing` finds zero no-clock register pins and zero unconstrained
internal endpoints. It finds **41 input ports and 51 output ports without
external delay constraints**, including all 32 AFE data inputs. The AFE5808A
mode is confirmed as 16-bit LVDS at 62.5 MHz, but its output-delay/phase and
the K26C PCB-skew min/max bounds are still unavailable. All eight queried PS8
EMIO peripheral clock outputs exist and have zero fabric endpoints.

This report set demonstrates routed internal timing closure and preserves the
remaining CDC and external-interface review items. It is not final board
qualification because the AFE external timing model and mandatory XXV IP
licenses are still missing. No FPGA was programmed.

The larger original reports are losslessly compressed. To verify and read:

```sh
sha256sum -c SHA256SUMS
gzip -dc cdc.rpt.gz | less
gzip -dc timing_summary.rpt.gz | less
```
