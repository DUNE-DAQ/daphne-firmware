# Pinned K26C implementation evidence: `26bb229`

Vivado 2026.1 implemented source revision
`26bb2295ac459a2f621abc66e4e4e8f91bcf55f9` on 2026-09-15 with
`DAPHNE_BOARD=k26c`, all four Hermes PHY paths, a maximum of eight Vivado
threads, and the `2100@xilinx-lic` floating license server. The remote build
chain exited 0. Synthesis, placement, routing, post-route physical
optimization, bit/bin generation, XSA export and DTBO packaging completed.

The fully routed design meets every reported internal setup, hold and pulse-
width constraint:

| Check | Worst slack | Total negative slack | Failing endpoints |
| --- | ---: | ---: | ---: |
| Setup | +0.073 ns | 0.000 ns | 0 / 374,087 |
| Hold | +0.009 ns | 0.000 ns | 0 / 368,159 |
| Pulse width | +0.280 ns | 0.000 ns | 0 / 94,713 |

Routing finished with no failed, unrouted or partially routed nets and no
remaining overlaps. The pre-bitstream DRC has zero errors and 842 warnings:
832 DSP input-pipelining advisories, eight RAM collision advisories, one vendor
I/O placement warning and one no-routable-load warning. Post-route utilization
is 96,343/117,120 CLB LUTs (82.26%), 83,395/234,240 CLB registers (35.60%),
91 BRAM tiles, 32 URAMs and 832 DSPs. CLB placement uses 14,623/14,640 CLBs
(99.88%).

The four Hermes channels use `GTHE4_CHANNEL_X0Y4`, `X0Y5`, `X0Y7` and
`X0Y6`, and share `GTHE4_COMMON_X0Y1`. The routed methodology report contains
eight `TIMING-7` warnings for related XXV TX/RX clock pairs without a common
node. The independent CDC audit records the intended synchronizers rather than
timing these crossings as synchronous logic. No exception was added for the
new RX-status register crossing.

The AFE5808A operating mode is confirmed as 16-bit LVDS at 62.5 MHz, implying
1.000 Gb/s per serial lane. A validated AFE output-delay/phase and K26C PCB-
skew min/max model has not yet been extracted from the board-owner's
[CERN EDMS source](../k26c-edms-timing-source-20260915.md), so the external AFE
interface is not timing-qualified. Software must update trigger polarity,
thresholds and channel enables only while acquisition is stopped, allow
settling, then keep them stable throughout acquisition. The AXI register bank
does not enforce that software protocol.

The focused Hermes four-clock/reset test and all four board-top elaborations
pass at this revision. GitHub Formal run `34932598031` passed all five executed
matrix jobs, and the exact-revision local formal inventory passes 30/30. The
exact-revision FuseSoC/GHDL `all-local` suite also passes all seven targets:
configuration control, self-trigger, frontend control, K26C board spy/trigger
plane, composable core top, composable frontend shell and composable top. The
packet datapath is unchanged from the candidate whose continuation,
reset-wrapper, vendor-XPM and full five-mode 32-channel replay evidence is
linked from the parent grouped32 report set.

The XXV Ethernet IP generation continues to report unavailable mandatory keys
`xxv_eth_mac_pcs@2026.06`, `xxv_eth_basekr@2026.06` and
`xxv_tsn_802d1cm@2026.06`. Successful artifact generation does not establish
licensed Ethernet operation. No FPGA was programmed.

Generated artifacts remain under
`/home/marroyav/work/daphne-grouped32-26bb229-impl-20260915/xilinx/output-26bb229/`.
Their SHA-256 hashes are:

| Artifact | SHA-256 |
| --- | --- |
| `daphne_selftrigger_26bb229.bit` | `ce6f3bf479b549c4b32c8396284a3e1ea46e91d0f63b0fa0e7148f66b03de866` |
| `daphne_selftrigger_26bb229.bin` | `51b185e15abd488487bcbf2569a57c95a52130c3cfbdec10182ec978b7406af8` |
| `daphne_selftrigger_26bb229.xsa` | `da6381642ceea715d78728b6f47e824532d78fe3ca5f617e582ab706dd2c6f9b` |
| `daphne_selftrigger_26bb229.dtbo` | `c2679107bee665a22773e7594347928fd22d9c237ba16f7a05d4e2145706bfb8` |
| `daphne_selftrigger_ol_26bb229.zip` | `1d772574b5d54bfc963cb0b7db30867e2c9badb2be96e91f2cbd1426c8d2f60b` |

Both ZIP containers open successfully, the overlay ZIP passes `unzip -t`, and
the DTBO parses as a version-17 Device Tree Blob. The routed DCP, binaries and
complete Vivado logs remain local. This directory preserves the primary timing,
utilization, methodology, DRC, clock, I/O, environment and artifact reports for
remote review.

The exact-revision formal and logic-suite logs are preserved as
`formal-all-local.log.gz` and `logic-all-local.log.gz`. Verify the evidence and
read either log with:

```sh
sha256sum -c SHA256SUMS
gzip -dc formal-all-local.log.gz | less
gzip -dc logic-all-local.log.gz | less
```
