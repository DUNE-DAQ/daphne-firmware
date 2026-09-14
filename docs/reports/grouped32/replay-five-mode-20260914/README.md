# Grouped32 five-mode functional replay

All five behavioral GHDL replay modes pass for the descriptor-pipeline logic
included in candidate `5e86a75`, with the source qualification below. The
independent oracle checked all 31,639 emitted packets: 16,199,168 samples and
379,668 descriptor words. All 13,181 packets admitted by both implementations
match across their complete 960 bytes.

| Mode | Scenario | Grouped packets | Reference packets | Byte-identical common packets | Reported full + busy count |
| --- | --- | ---: | ---: | ---: | ---: |
| 0 | Simultaneous sustained activity | 3,392 | 3,392 | 3,392 | 0 |
| 1 | Staggered activity, short link stalls | 3,372 | 3,372 | 3,372 | 0 |
| 2 | Long link stall, overload | 2,224 | 2,200 | 2,200 | 1,168 |
| 3 | Dense overlapping forced triggers, continuation disabled | 3,673 | 3,446 | 945 | 1,241 |
| 4 | Hard reset, counter reset, acquisition disable | 3,296 | 3,272 | 3,272 | 0 |

Modes 0 and 1 explicitly require zero full/busy/continuation loss, identical
admissions and complete draining. Modes 2 and 3 exercise overload: different
admission decisions are allowed, while every emitted packet is checked against
the input waveform and descriptor oracle. Mode 4's counters are deliberately
reset during the replay, so its final zero counter value is not a no-loss claim
across the hard reset. All modes check packet length, uninterrupted readout,
lane/channel mapping and drained packet stores.

The engine retains its measured 525-fast-clock service interval. See the
[service measurement](../pipeline-cdc-20260914/service-measurement.json) and
[selected-source focused/OOC evidence](../pipeline-cdc-20260914/README.md).

## Sources and logs

The frozen source manifest for modes 1–4 was compared with the full candidate
commit recorded in [provenance.json](provenance.json). Every analyzed source
matches except the descriptor's synthesis-only `use_dsp` selection:
[replay-to-candidate.diff](replay-to-candidate.diff) changes forced DSP mapping
to fabric mapping for the fast pipeline, retaining native DSP mapping. It
does not change arithmetic, registers, control, latency or RTL simulation
behavior. Selected-source focused tests and synthesis were rerun separately.

Mode 0 completed in the earlier working-tree invocation, before the runner
froze its analyzed sources. That invocation then stopped before mode 1 while
workspace sources were changing; the old runner did not print the captured
GHDL failure output, so that failure's precise cause was not recorded. Its
successful mode 0 result is retained in
[the original log](mode0-and-initial-run.txt). The frozen rerun completed modes
1–4 successfully; [its full log](modes1-4.txt) ends with the suite PASS marker.

[summary.json](summary.json) preserves per-mode counts, latency measurements
and CSV SHA-256 hashes. Those hashes were rechecked when this report was
created. Large CSVs remain in the build directories listed in the provenance;
they are not included in this report directory. These runs use behavioral XPM
models and a zero phase offset. The separate
[actual-XPM sustained replay](../pipeline-cdc-20260914/vendor-replay/summary.json)
uses the installed Vivado models and a 700 ps clock offset.

These functional results do not establish board timing or CDC closure.
