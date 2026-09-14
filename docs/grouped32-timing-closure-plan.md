# Grouped32 implementation goal and plan

Make the 32-channel grouped-four fixed512 DAPHNE design produce a K26C firmware
bundle that passes routed timing, DRC and functional regression in Vivado 2026.1.
Keep eight shared builders, four physical Hermes links, 512-sample/960-byte
records, continuation, descriptor ownership and whole-fragment loss accounting.
The firmware branch is `codex/selftrigger-512-32ch-grouped4`. Hardware programming
is outside this goal.

## Starting evidence

The RTL fixes in `8ae5f81` pass synthesis and the byte-order regression. The
[synthesis evidence](reports/grouped32/synth-20260914-8ae5f81/README.md) records the
working-tree build's provenance and limitations. Total LUT use is 90.72%; setup
WNS is -2.764 ns. The grouped builder domain contributes -7127.542 ns of the
design's -7301.498 ns TNS, approximately 97.6%.

The demonstrated critical path is sample-ring BRAM -> channel selection ->
baseline/polarity arithmetic -> descriptor integral DSP input. It has nine logic
levels and 5.193 ns data delay against the 312.5 MHz period of 3.200 ns. This is
the first RTL optimization target. Synthesis-only hold violations and high
fanout must also be examined after placement and routing.

## Milestones

1. **Complete the baseline audit.** From the existing synthesis checkpoint,
   collect hierarchical utilization, detailed timing checks, clock interactions,
   CDC and methodology reports. Confirm four AFE islands, eight serializers,
   32 frame sources and four PHY paths, with no active native
   `stc3_record_builder`. Verify common-clock URAM operation and the XPM mailbox
   and FIFO constraints. Classify all eight no-clock pins, 54 inputs without
   delays and 51 outputs without delays by their actual interface behavior.
   The checkpoint can be reused for diagnosis; final qualification requires a
   fresh build.

2. **Shorten the fast descriptor path.** Register selected samples and/or
   amplitude calculation in `fragment_peak_descriptors_banked`, breaking the
   BRAM-to-DSP chain while retaining one sample accepted per fast clock. Carry
   sample index, valid, start, baseline, polarity and threshold through aligned
   stages. Check the resulting DSP inference and resource cost. The serializer
   currently ignores `done_o` and enters header emission immediately after
   sample 511; explicitly accommodate pipeline drain before descriptor reads,
   header publication and FIFO commit. Preserve bank ownership throughout.

3. **Prove behavior and capacity before a full build.** Run the grouped32 and
   continuation suites, real vendor XPM tests, Hermes admission/reset tests and
   the byte-order regression. Add focused checks for any new pipeline boundary:
   simultaneous start/sample0, configuration changes, final-sample excursion
   closure, descriptor overflow, reset, stalls and completed-bank reuse. Check
   all emitted samples and descriptors against the independent oracle, including
   full 960-byte packets. Measure the new service interval: each four-channel
   group requires 488,281.25 records/s at continuous input. The current engine
   costs 522 fast cycles/record; 640 is the ideal capacity ceiling at 312.5 MHz,
   before accounting for observed arbitration/CDC effects. Validate sustained
   service with simulation rather than relying only on arithmetic.

4. **Resolve real CDC and constraint gaps.** Review Ethernet status/control and
   reset paths to the PS/IPbus domain. The baseline includes crossings timed at
   0.400 ns edge separation; determine whether each is a true synchronous path,
   an already safe asynchronous crossing, or missing a synchronizer/handshake.
   Add the appropriate RTL or narrowly justified constraint. Give active
   synchronous interfaces real delay requirements and document intentionally
   asynchronous/static interfaces. Do not mask functional crossings with
   blanket false paths or change clock periods to conceal a failure.

5. **Measure placement and routing.** Re-synthesize after the targeted fixes,
   then run opt/place/route in one detached job. Keep per-stage utilization,
   setup/hold, pulse-width, DRC, methodology and clock reports. Use hierarchical
   area and congestion evidence to reduce unnecessary replication or large
   muxes if required; retain channel count and descriptor semantics. Examine
   reset distribution with its actual fanout and preserve asynchronous assertion
   and synchronous release. Compare synthesis directives only as controlled
   experiments, after the logic/constraint defects are understood.

6. **Qualify and publish a pinned candidate.** Commit the selected RTL and
   constraints, create a fresh source/build directory, regenerate all IP and
   run the final implementation with the correct revision stamp. Re-run affected
   regressions against that commit. Package bit/bin/XSA/DTBO and the overlay zip
   with source/tool hashes, commands, logs, reports and checksums. Commit and push
   reviewable changes and evidence; store large binaries outside normal Git
   history with durable references.

## Completion criteria

- Functional and vendor-model tests pass for all 32 channels; accepted records
  preserve sample order, timestamps, descriptors and packet length. Reset and
  overload cannot publish partial or stale records.
- Measured sustained builder/readout service supports the current throughput
  contract, with updated latency and capacity measurements.
- The final routed design fits the part and has WNS >= 0, WHS >= 0, TNS = 0,
  THS = 0 and no failing pulse-width endpoints for the required clocks/corners.
- Clock/CDC and interface coverage are reviewed, every remaining exception is
  justified, and there are no blocking DRC errors or unexplained critical
  methodology findings.
- A fresh build from the pinned revision produces the firmware bundle and
  traceable evidence. Any IP-license limitations affecting the generated
  firmware are resolved and documented before delivery.

## Fallback decision

If staged arithmetic still cannot sustain 312.5 MHz after placement/routing,
evaluate a separately identified two-sample-per-cycle engine at 156.25 MHz.
Demonstrate equal sustained service and packet correctness before adopting it.
Halving the existing engine's clock alone would halve capacity and does not
satisfy this goal.

## Progress on 2026-09-14

The [baseline checkpoint audit](reports/grouped32/audit-20260914-8ae5f81/README.md)
confirms the intended hierarchy and shared URAM clocks. DRC has no errors at
synthesis, but CDC/methodology and interface coverage require more work. The
original CDC report truncated one large clock pair; the audit runner now raises
the reporting threshold. No truncated report is accepted as CDC sign-off.

The [first repair candidate](reports/grouped32/pipeline-cdc-20260914/README.md)
adds two descriptor input stages, waits for pipeline drain in the serializer,
and selects fabric addition for the fast grouped accumulator. Descriptor-only
estimated setup WNS improves from -0.874 ns to +0.836 ns. Its measured 525-cycle
service interval retains the required throughput. Real-XPM sustained 32-channel
mode 0 replay passes with zero loss and byte-identical reference packets;
selected-source focused tests also pass. GHDL modes 0 and 1 pass with zero loss.
Overload and dense-trigger modes 2 and 3 independently verify every emitted
packet and account for whole-fragment drops; differing admissions under
overload are expected. The reset/counter-reset/acquisition-disable mode 4 also
passes: all 3,272 common packets match across 960 bytes, and every emitted
packet passes the independent oracle. The completed
[five-mode replay evidence](reports/grouped32/replay-five-mode-20260914/README.md)
records 16,199,168 checked samples and 379,668 descriptor words, with logs,
source provenance and CSV checksums. Mode 4 resets its counters during the run;
its final zero loss count does not describe losses across the hard reset.

This candidate also repairs Hermes header/status crossings and reset during a
network configuration exchange, synchronizes PDTS completion flags, and removes
the corresponding unsafe state-machine exceptions. Negative-control tests
reproduce both mailbox reset and mid-packet header-ID failures in the old RTL.
Build wrappers now preserve failed-stage exit codes and correctly accept a
successful synthesis-only run without requiring a bitstream.

The first repair candidate was committed as `5e86a75` and synthesized from a
fresh pinned checkout with Vivado 2026.1. The synthesis-only run exited zero,
but the post-synthesis setup report still fails: WNS -0.761 ns, TNS -40.925 ns,
152 failing endpoints. This is a large reduction from the baseline's -2.764 ns,
-7301.498 ns and 3711 endpoints. Of the remaining endpoints, 96 are in the
312.5 MHz grouped builder/serializer domain, with the worst internal path from
the sample ring BRAM output to the grouped FIFO input at -0.161 ns. The overall
worst path at -0.761 ns is a reset-recovery check from the PS-clock domain into
the Ethernet IP, not the grouped sample-data path. The other Ethernet clock
crossings need classification against the vendor IP's CDC/reset contract.
The unplaced hold failures are diagnostic only; placement/routing must determine
whether hold actually closes. The [full checkpoint audit](reports/grouped32/audit-20260914-5e86a75/README.md)
completed with no report errors or CDC truncation at the increased clock-pair
threshold. It records 117,682 CDC detail paths, 52 clock methodology critical
warnings, zero synthesis DRC errors, and the still-missing external timing
bounds.

A second candidate repairs atomically sampled self-trigger counters across AXI
and acquisition clocks, coherent endpoint address/status transfers and
stopped-clock reset recovery, packet-boundary PDTS address matching, and fan
tachometer first-stage synchronization. Focused GHDL and real-XPM tests pass,
including 32/40-channel counter readout and endpoint clock stop/reset cases.
These edits are not yet represented by a successful full-board build. The next gate is to
review and commit them, synthesize from a fresh pinned revision, audit CDC and
constraints, and route that revision. Use eight Vivado threads and only one full
build at a time. Local out-of-context timing is not board timing closure.

The first full implementation attempt from committed `14e5192` stopped during
RTL elaboration: a legacy `selftrig_core` instance lacked the new counter-clock
port actual. The [failure report](reports/grouped32/impl-14e5192-elaboration-20260914/README.md)
retains the exact log. The instance now maps its acquisition `clock`; a new
pinned build is required to measure any synthesis or routed timing result.

Remaining audit work includes frontend/selftrigger configuration, external
trigger pulse capture, and the eight PS EMIO no-clock pins. The AFE
capture min/max input-delay bounds are unset and require a validated timing XDC
or device/board timing model from the hardware owner. The
[AFE5808A datasheet review](reports/grouped32/afe5808a-timing-review-20260914.md)
finds that the current 16-bit, 62.5 MHz setting implies 1.000 Gb/s per LVDS
lane, above TI's approximately 910 Mb/s maximum characterized output-rate
example; neither 16-bit timing at that rate nor K26C trace skew is supplied.
Other SPI/I2C/static
interfaces need their corresponding timing contracts. Continue internal timing
and CDC work while that information is pending; do not invent interface bounds
or blanket exceptions.

The new `d1d07ac` pinned implementation passed packaging and entered
`synth_design`. Its XXV Ethernet IP is reported locked because mandatory
feature keys are unlicensed, although the Vivado Synthesis feature checks out.
The [license review](reports/grouped32/xxv-license-review-20260914.md) records
the server query and delivery implication. Preserve all four Hermes PHY paths;
do not treat a successful synthesis report as evidence of a usable bitstream
until that licensing gate is resolved.

The eight baseline PS EMIO `no_clock` pins have a
[source-level classification](reports/grouped32/ps-emio-no-clock-review-20260914.md):
the corresponding peripherals are disabled or routed through PS MIO rather
than PL EMIO. Confirm zero fabric clock loads in the fresh netlist before
signing off these warnings; no fabricated clocks or exceptions were added.

The external `trig_IN` input was found feeding multiple AXI-clocked stretcher
registers directly. A [focused CDC repair](reports/grouped32/external-trigger-cdc-20260914.md)
adds a two-register synchronizer and a first-stage-only constraint; the GHDL
trigger smoke test passes. It is not in the running `d1d07ac` build and needs
a fresh pinned build before sign-off.

The branch's two composable formal CI matrices failed at VHDL import because
their harnesses omitted a required calibration-tag port. The
[formal repair](reports/grouped32/formal-ci-repair-20260914.md) adds a symbolic
tag input to the harnesses; all five CI matrices now pass on `a6728f2`.

The pinned `d1d07ac` implementation later completed bit/bin/XSA/DTBO packaging
despite the XXV license warnings, but routed setup timing failed. A first FIFO
write pipeline and a narrowly scoped Hermes source-reset PRE exception were
implemented in `5f00fb5`. Its [fresh full implementation](reports/grouped32/impl-20260914-5f00fb5/README.md)
exited 0 and improved routed builder timing from -1.011 ns / 5,328 failing
endpoints to -0.235 ns / 1,350, while overall setup remained -1.715 ns / 1,383
endpoints. Hold and pulse-width passed. The [routed checkpoint audit](reports/grouped32/audit-routed-5f00fb5-20260914/README.md)
completed all reports, found zero route/DRC errors, verified all eight PS EMIO
clock outputs have zero fabric fanout, and produced a complete 117,610-row CDC
report. Its clock-relationship warnings, CDC structures, exception coverage,
and missing external I/O delays still need review.

Revision `5d83890` adds a packer-input register to split the remaining
ring-BRAM-to-FIFO-write path. All five GHDL replay modes pass with packet CSV
hashes identical to `5f00fb5`, and all five Formal CI matrices pass. A clean
pinned full implementation and real-AMD-XPM mode-0 replay have been launched;
neither has a final result at this update. The Ethernet CDC/reset failures are
separate from the builder path and require object-level review before any new
timing exception. The AFE 1.000 Gb/s lane timing and K26C skew limits remain
external qualification blockers.
