# Grouped256 implementation campaign

Candidate: 32 channels, eight four-channel builders/readout lanes, four links.
256 samples,64 pretrigger,five descriptors,fixed63-word/504-byte protocol4.
Control ABI2.0 is independent of the packet version. Continuation is enabled
for the preserved447-sample posttrigger requirement. See the wire-format note.

The gapless scheduler reserves at a packet boundary, then drains the entire
packet even if downstream credit drops. End markers are registered with data.
Adjacent ready channels need no empty cycles; sparse channels retain round-robin
search. Hermes must reserve63 words plus its existing four-word pipeline guard.
With continuous ready channels, theoretical lane load is4*63/256=98.4375%.
That is a throughput bound, not a claim of losslessness under all traffic.

Validation retains historical512 tests and all existing formal jobs. A new
inductive readout contract checks admission,one-hot consumption,ordering,
aligned final markers,continuous packet drain and gapless admitted boundaries.
The vendor integration test includes a mid-packet reset, stalled sink, repeated
backpressure and recovery through the real AMD asynchronous FIFO model.
Descriptor directed tests cover both polarities,pipeline modes,maximal fields,
five/six peaks and reset. Full 32-channel replay checks every emitted waveform
and compact descriptor against an independent oracle.

Builds use committed bundles in distinct Cooper scratch directories, four
threads initially, and one heavy Vivado process. The runner
`scripts/remote/cooper_grouped256_campaign.sh` runs vendor gates before the
existing clean implementation/DTBO flow. Preserve its status and evidence files.

Build turnaround is measured in `build-phase-times.tsv` for project preparation,
IP generation,synthesis,implementation,bitstream/XSA and device-tree packaging.
The initial build retains PerformanceOptimized synthesis. Runtime/directive
comparisons must use the same host,tool,source and thread count; retain reports
and qualify timing/resource changes. Clearer names alone do not accelerate
synthesis. Existing XPM memory inference and pipeline registers stay explicit;
memory downsizing requires separate evidence of equivalent buffer tolerance.

No candidate is a release until routed setup/hold,CDC,DRC,clock coverage,resource
use,package checksums and dual-profile validation have been reviewed. Board
programming is outside this campaign. Old synthesis cleanup must preserve
release/rollback binaries and architecture reports and list removed paths.
