# Goal prompt: fixed-packet waveform continuation

Implement and qualify a DAPHNE self-trigger firmware variant based on the
512-sample branch. Follow the intent of `waveform_extended.png`: when waveform
activity continues at the end of a frame, capture adjacent fixed-size frames
until the waveform has remained quiet long enough. Every emitted packet must
retain the existing 512-sample, 120-by-64-bit, 960-byte transport structure.
Make all required changes, run the validations, and produce the comparison
evidence rather than stopping at a proposal or synthesis-only result.

Use a new dedicated `daphne-firmware` branch and an isolated clean worktree.
Preserve unrelated changes and existing build directories. Pin the original
512-sample source revision, the new firmware revision, and the matching
`daphne_mezz_xc_sim` revisions. Use independent agents for RTL, local waveform
simulation and performance analysis, and Cooper build/resource validation.

Implement explicit ownership of every accepted packet, descriptor and sample
interval. Continue sampling throughout packet assembly. Preserve the first
frame's pretrigger region, exact +512 sample/timestamp progression for adjacent
fragments, raw ADC sample order, and calibration fields. Give each accepted
fragment descriptors computed from that fragment's samples. Document any use
of reserved bits or changed descriptor semantics while preserving transport
field positions and length. Reserve enough output space before admitting a
fragment and make it visible to readout only when complete. Under overload,
drop and count whole fragments; expose loss through counters and timestamp
gaps. Handle delayed triggers, pulse pileup, quiet termination, reset, disable,
timestamp wrap and memory wrap without stale metadata or partial packets.

Choose continuation logic that fits the K26 programmable logic and achieves
an initiation interval no longer than 512 ADC clocks. Evaluate paired memory
reads, packet storage organization, descriptor computation and buffering.
Input/output spy buffers may be removed if the implemented resource or timing
results justify doing so. Preserve the data path and identify output bandwidth
limits separately from acquisition deadtime. Make reasonable implementation
choices autonomously and record the assumptions.

Compile on Cooper through the authorized connection:

```bash
ssh -J dunegpvm01 -K arroyave@cooper.dhcp.fnal.gov
```

For each build candidate, create a fresh source/build directory from a pinned
commit and no reused generated IP or checkpoints. Record source/archive hashes,
tool versions, environment, commands, logs and exit status. Run builds in
detached sessions so an SSH disconnect does not stop them. Obtain synthesis,
placement, routing, timing, DRC and utilization reports and package the final
bitstream and associated overlay artifacts with checksums. Diagnose and fix
failures within the authorized scope. Do not program deployed hardware.

Update and run `xc_sim` locally on this workstation in parallel. Model the
final RTL admission, queue, serializer, ring, packet reservation, continuation
and readout behavior. Use the same waveform samples and coherent trigger
candidates for paired old/new comparisons. Include short pulses, long tails,
boundary activity, delayed candidates, pileup, realistic cross-correlation
trigger candidates, sustained activity and offered loads above link capacity.
Replay model traces through real HDL and compare packet timestamps, every ADC
sample, descriptor ownership and output cycles. Validate vendor memory
behavior independently of simplified local fixtures.

Compute reproducible improvements with raw results, plots and trial variation.
Report trigger rejection, requested-window coverage, physical pulse/charge
retention, whole-fragment loss, latency and bandwidth as distinct metrics.
Do not describe better tail/charge coverage alone as reduced trigger deadtime.
State synthetic-waveform and trigger-model limitations, threshold assumptions,
and measured output bottlenecks. Distinguish historical implementation reports
from newly measured resource/timing evidence.

Completion requires committed reviewable firmware and simulation changes,
successful final implementation and packaged artifacts, matched HDL/model
checks, and a concise evidence-backed report of improvements and remaining
physical limits. The active implementation contract is described in
[selftrigger-512-continuation.md](selftrigger-512-continuation.md).
