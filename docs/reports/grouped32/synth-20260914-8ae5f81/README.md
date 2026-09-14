# Grouped32 synthesis evidence, 2026-09-14

Vivado 2026.1 completed synthesis and wrote a checkpoint for the grouped32
design with the RTL fixes committed in `8ae5f8150a05e3e79ccc9f21b118142431d3de5d`.
Timing is not closed. Placement, routing and hardware testing have not been
performed for this candidate.

The run started from `1bae1c8` plus working-tree fixes, before those fixes were
committed. Consequently, report paths, `run.env` and the firmware Git generic
retain `1bae1c8`. This was a retry in the existing workspace; it is not evidence
of a fresh build from a clean clone of `8ae5f81`. The four source files named in
[manifest.json](manifest.json) were verified byte-for-byte against both that
commit and Vivado's staged `ipshared` sources. The manifest records their hashes
and the local checkpoint hash. The final qualification build must use a fresh,
pinned source tree with the correct revision stamp.

## Results

| Metric | Post-synthesis result |
| --- | ---: |
| LUTs | 106,249 / 117,120 (90.72%) |
| Registers | 88,200 / 234,240 (37.65%) |
| BRAM tiles | 91 / 144 (63.19%) |
| URAM | 32 / 64 (50.00%) |
| DSPs | 840 / 1,248 (67.31%) |
| Setup WNS / TNS | -2.764 ns / -7301.498 ns |
| Setup failing endpoints | 3,711 |
| Hold WHS / THS | -0.580 ns / -3650.446 ns |
| Hold failing endpoints | 94,354 |
| Pulse-width failing endpoints | 0 |

The 312.5 MHz builder domain contributes 3,464 setup failures and -7127.542 ns
TNS. Its worst reported path runs from sample-ring BRAM through sample selection
and amplitude arithmetic to the descriptor integral DSP input: 5.193 ns data
delay across nine logic levels against a 3.200 ns period. These delays use
estimated routing. See the `clock_raw_s_1` section of the timing report.

The timing summary also reports eight pins without clocks, 54 input ports
without input delays and 51 output ports without output delays. These require
object-level review; zero unconstrained internal endpoints does not establish
complete timing coverage. Dedicated CDC, clock-interaction, hierarchical
utilization and methodology reports are still needed.

## Files

- [post_synth_timing_summary.rpt](post_synth_timing_summary.rpt): complete timing
  summary and per-clock path details, including failures.
- [post_synth_util.rpt](post_synth_util.rpt): total device utilization.
- [clocks.rpt](clocks.rpt): generated clocks after constraint application.
- [post_synth_power.rpt](post_synth_power.rpt): preliminary power estimate.
- [debug/](debug/): original clock/object dumps before post-synthesis constraints.
- [build-log.txt](build-log.txt): unmodified build log, including XXV license
  warnings and successful checkpoint/completion messages.
- [run.env](run.env), [preflight-log.txt](preflight-log.txt),
  [artifacts.txt](artifacts.txt): original wrapper metadata and output listing.
- [manifest.json](manifest.json): provenance, metrics and source/checkpoint hashes.
- [SHA256SUMS](SHA256SUMS): checksums for the committed evidence files.

The 149 MiB checkpoint remains in the local output directory recorded in the
manifest. Verify this evidence directory with `sha256sum -c SHA256SUMS`.

The staged qualification plan is in
[grouped32-timing-closure-plan.md](../../../grouped32-timing-closure-plan.md).
