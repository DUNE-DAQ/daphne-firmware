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

Current phase: baseline evidence published; detailed checkpoint audit and the
descriptor-pipeline experiment are next. No new implementation run was launched
while preparing this plan.
