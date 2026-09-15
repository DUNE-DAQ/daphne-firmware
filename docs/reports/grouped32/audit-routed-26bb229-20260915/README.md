# Routed checkpoint audit: `26bb229`

Vivado 2026.1 independently reopened and audited the pinned `26bb229` fully
routed K26C checkpoint. The audit command exited 0 and generated every
requested report. The checkpoint SHA-256 is
`b008f723e2f0a2fa3d0c8973c046b35a386e5f9fe5d2bbd7495d51e3ed994e3d`;
it remains in the local implementation directory. The exact audit Tcl and
Vivado log are preserved here. The route-status report records all 206,131
routable nets as fully routed, with zero routing errors.

The reopened checkpoint reproduces clean internal timing: setup WNS is
**+0.073 ns** with zero failing endpoints, hold WHS is **+0.009 ns** with zero
failing endpoints, and pulse-width slack is **+0.280 ns** with zero failing
endpoints. All 87 bus-skew checks meet their constraints; the minimum reported
bus-skew slack is **+1.379 ns**. The routed DRC has zero errors and 842
warnings, predominantly the 832 DSP input-pipelining advisories.

`check_timing` finds zero no-clock register pins, zero constant-clock register
pins, zero multiple-clock register pins and zero unconstrained internal
endpoints. It finds 41 input ports and 51 output ports without external delay
constraints. All eight queried PS8 EMIO peripheral clock outputs exist and have
zero fabric endpoints.

The CDC report used a 1,000,000 clock-pair threshold. Its rule totals sum to
**117,618 reported paths/bits**, and there is no truncation warning. The
summary is 21,280 `CDC-1`, 250 `CDC-3`, 8 `CDC-6`, 13 `CDC-9`, 35
`CDC-10`, 12 `CDC-11`, 3 `CDC-12`, 81,377 `CDC-13`, 32 `CDC-14` and
14,608 `CDC-15` rows. These are path/bit counts, largely including false-
pathed frontend IDELAY primitives, vendor IP and FIFO structures; they are not
an automatic count of independent defects.

The four formerly unexcepted Hermes `stat_rx_status_0` combinational crossings
are absent. Each replacement path from `rx_status_rx_s_reg` to
`rx_ready_tx_sync_s_reg[0]` is classified `CDC-3`, has depth two, carries the
`ASYNC_REG` property and has no exception. All 35 remaining `CDC-10` rows are
covered by existing false paths. Eight `CDC-11` rows have no exception: in each
of four XXV reset wrappers, one reset level registered on `gt_txusrclk2` feeds
two independent three-stage `ASYNC_REG` synchronizers, one on `gt_rxusrclk2`
and one on `rx_core_clk`. This is an intentional registered fanout into two
separately synchronized destination domains, not unsynchronized data logic; no
exception was added to suppress the diagnostic.

The acquisition control bits reported across the AXI/frontend clock boundary
are governed by a software protocol. Trigger polarity, thresholds and channel
enables may be written only while acquisition is stopped; software must allow
the values to settle and hold them stable while acquisition runs. The current
AXI register bank does not enforce this lockout in hardware, so a live write
would violate the qualified operating contract.

Methodology reports eight `TIMING-7` warnings for the separately generated XXV
RX/TX clock pairs and no `TIMING-6` warning. The two `TIMING-24` warnings note
that broad asynchronous clock grouping supersedes vendor-XPM max-delay
constraints; the associated bus-skew constraints were evaluated separately and
all pass. The missing external-delay findings remain visible rather than being
hidden with invented constraints.

The AFE5808A mode is confirmed as 16-bit LVDS at 62.5 MHz, or 1.000 Gb/s per
lane. CERN EDMS navigator document `101959906` is now identified as the board-
owner PCB source, but its authenticated subdocuments have not yet yielded the
released assembly revision or routed trace-delay bounds needed for XDC. The
mandatory XXV feature licenses also remain unavailable. This report set
demonstrates routed internal timing closure and preserves those external
qualification blockers. No FPGA was programmed.

The larger original reports are losslessly compressed. To verify and read:

```sh
sha256sum -c SHA256SUMS
gzip -dc cdc.rpt.gz | less
gzip -dc timing_summary.rpt.gz | less
gzip -dc bus_skew.rpt.gz | less
```
