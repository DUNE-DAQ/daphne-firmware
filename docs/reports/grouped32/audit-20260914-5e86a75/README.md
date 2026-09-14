# Grouped32 synthesis and checkpoint audit: 5e86a75

Synthesis and the detailed checkpoint audit completed successfully with Vivado
2026.1, both returning exit code 0. **Timing is not closed.** These are
post-synthesis estimates; placement, routing and hardware qualification remain.
The audit completed all 11 requested Vivado reports, plus hierarchy and memory
clock tables, without a failed report.

The build used a fresh, initially clean clone of
`5e86a757d5fad3abe30fb65ce5d3868081a610c9`, with no generated directories reused.
All 349 tracked RTL files matched that commit during and after synthesis.
Generation changed only the two `.core` source manifests to include generated
IP collateral; both diffs are preserved. The generated BD and XCI contain
firmware version `0x5E86A75`. See [manifest.json](manifest.json),
[firmware-version.json](firmware-version.json), and
[source provenance](provenance/synthesis/).

The checkpoint SHA256 is
`e118f222968e9c427b7dba0e481780841a62e2ee289c7c83113e9464b2cca65d`.
The DCP stays in the local path recorded in the manifest and audit provenance;
it is excluded from this Git bundle. Later endpoint, counter and fan CDC changes
are outside this checkpoint's scope.

| Metric | Result |
| --- | ---: |
| LUTs | 106,502 / 117,120 (90.93%) |
| Registers | 89,713 / 234,240 (38.30%) |
| BRAM / URAM / DSP | 91 / 32 / 832 |
| Setup/recovery WNS / TNS | -0.761 ns / -40.925 ns |
| Setup/recovery failing endpoints | 152 |
| Hold/removal WHS / THS | -0.580 ns / -3667.257 ns |
| Hold/removal failing endpoints | 95,003 |
| Pulse-width failing endpoints | 0 |
| Bus-skew checks | 126, no failures; worst slack +3.054 ns |

Both synthesis and audit requested eight threads. The synthesis log confirms
seven helper processes, and timing analysis reports a maximum of eight CPUs.
The build's final log has zero errors, 104 critical warnings and 657 warnings.
Critical warnings include XXV license/locked-IP messages and initial repeated
GT location assignments; the board script subsequently assigns the four links
to X0Y4, X0Y5, X0Y7 and X0Y6. Synthesis success does not qualify those messages
for implementation or bitstream generation.

## Remaining timing groups

| Group | Failing endpoints | Worst slack (ns) | TNS (ns) |
| --- | ---: | ---: | ---: |
| Builder `clock_raw_s_1`, 312.5 MHz | 96 | -0.161 | -6.081 |
| AXI `clk_pl_0` ↔ Ethernet RX/TX clocks, ordinary setup | 16 | -0.438 | -5.532 |
| AXI → Ethernet RX/TX, `**async_default**` recovery | 40 | -0.761 | -29.316 |

Displayed per-group TNS values are rounded and therefore do not sum exactly to
the global TNS. [clock-failure-breakdown.tsv](clock-failure-breakdown.tsv)
contains all 64 groups with setup/recovery or hold/removal failures, including
each Ethernet lane; the same data is available as JSON.

The builder's worst path now runs from sample-ring BRAM to the serializer's
write FIFO data input, through four LUT6 levels: 2.712 ns estimated data delay.
The global worst slack is a reset-recovery path from Hermes `rst_ipb_reg` to
encrypted XXV core logic. These are separate closure tasks. The prior baseline
had 3,464 builder setup failures and -7127.542 ns builder TNS; see
[the baseline evidence](../synth-20260914-8ae5f81/README.md).

Hierarchy confirms four grouped islands, eight serializers, 32 frame sources
and four XXV PHYs. No native `stc3_record_builder` remains in the active netlist.
All 32 URAM primitives use `frontend_clock`.

## CDC, constraints and report limits

The CDC report used a 1,000,000 clock-pair threshold. No truncation warning was
emitted, and all **117,682 detail rows exactly match the report's rule totals**.
The baseline audit used 100,000 and was truncated, so raw count changes are not
a comparable defect trend. [cdc-summary.json](cdc-summary.json) records rule
and clock-pair counts. The current report contains 102,773 critical rows,
14,667 warning rows and 242 informational rows. Most critical rows are on
`clk_pl_0` → `frontend_clock` configuration/reset paths. These are path/bit
counts, not counts of independent defects or evidence that crossings are safe.

Methodology reports 52 critical warnings about clock pairs with no common
primary clock or node. DRC reports 843 warnings and no errors, including 832 DSP
input-pipeline warnings. The post-synthesis bus-skew result needs rechecking
after routing. Timing summaries include Vivado's default worst-path examples
per group, rather than an exhaustive path dump for every failing endpoint;
the tables retain total endpoint counts. Full textual reports are preserved.

[check_timing.rpt](check_timing.rpt) still identifies eight PS EMIO clock pins
without clocks, 54 inputs without delays and 51 outputs without delays.
Forty-five inputs are AFE capture lanes. AFE external min/max timing bounds are
still unset; other interfaces need device/board delay bounds or documented
asynchronous/static treatment. The PS pins are enumerated in the report and
need unused-net review. Zero unconstrained internal endpoints and zero loops
do not resolve these interface-coverage gaps. No delays or timing waivers were
invented for this audit.

All original audit reports are in this directory; `synthesis/` preserves the
original synthesis reports, debug dumps, build/preflight logs and wrapper
metadata. `provenance/` contains both launchers, exit status, exact audit Tcl,
source hashes and generated-manifest diffs. Larger files use lossless gzip;
the manifest records original sizes and uncompressed hashes. To verify/read:

```sh
sha256sum -c SHA256SUMS
gzip -dc cdc.rpt.gz | less
gzip -dc timing_summary.rpt.gz | less
```
