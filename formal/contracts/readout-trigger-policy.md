# Ethernet trigger selection

The frontend selector at physical address `0x88000034` is synchronized into
62.5 MHz acquisition clock domain before Ethernet readout uses it. The new
selector is `{bit 3, bits 1:0}`. Bit 2 remains global inhibit. Full 32-bit AXI
writes with all byte strobes set are required, as for the existing register.

| Mode | Register value, uninhibited | Ethernet sources |
| --- | --- | --- |
| 0 | 0x0 | Software only |
| 1 | 0x1 | BNC hardware only |
| 2 | 0x2 | Self-trigger/xcorr only |
| 3 | 0x3 | Software, BNC, xcorr and timing combined |
| 4 | 0x8 | Timing command only |
| 5–7 | 0x9–0xB | Reserved; all admission disabled |

OR the value with `0x4` to inhibit. Reset value `0x3` preserves combined
operation. The separate spy path retains its legacy two-bit mapping, where
mode 2 means timing; bit 3 extends only the Ethernet selector. No existing
register address, low selector bit or inhibit bit moves.

Software includes the frontend command at `0x88000008` and legacy
`FORCE_TRIG`; neither bypasses selection/inhibit. In the K26C block design,
`FORCE_TRIG` is tied low: BNC connects only to the frontend synchronizer,
so it cannot enter the software path. Accepted software carries
tag 3, BNC tag 1, timing tag 2, and xcorr retains normal metadata. Software
wins simultaneous accepted software/BNC pulses; either forced source wins over
a coincident xcorr/timing tuple. Timing commands match the configured ad-hoc
code and retain their existing trigger/filter latency and timestamp metadata.
The selector does not generate edges or redesign the timing endpoint.

Timing strobes are blocked upstream of the trigger bank when timing is not
selected. At frame admission, xcorr and timing tuples are gated separately
using the delayed calibration tag. In combined mode the existing shared
xcorr/timing OR retains its timing tag priority for coincident commands.
Disabled admission keeps the filter and baseline estimator running. Channel
enable remains required for every source. Continuation remains independently
programmable: accepted software, BNC and timing events may continue.

Changing source creates a one-cycle admission gap that cancels the old chain
and its coalescing metadata. Inhibit stops continuation too. Queued frames,
sample-ring contents and serializer ownership remain intact and drain normally.
For deliberate changes use inhibit, wait at least five acquisition clocks,
write the new selector inhibited, wait another five clocks, then release inhibit.
Linux MMIO operations normally exceed those waits. Rejected triggers are not
queued for later replay.

`readout_trigger_policy_contract` proves source acceptance/rejection, tags,
inhibit, invalid modes and transitions for arbitrary binary inputs. Its cover
job reaches every supported mode, inhibit, a transition and a reserved mode.
The frontend AXI proof checks arbitrary four-bit full writes, rejection of
partial writes, reserved readback bits and reset defaults. The admission
simulation checks all eight selector values against 16 source combinations,
inhibit, tags and retained baseline; timing's upstream strobe rejection is
modeled explicitly. Board elaboration checks real interface connectivity.

These leaf proofs do not establish frontend CDC correctness, xcorr mathematics,
ring-buffer correctness or end-to-end timing/Ethernet behavior. The local
simulation uses behavioral XPM models. Vendor synthesis and board qualification
remain separate requirements. The current 662c3fe bitstream does not support
this extended Ethernet selector; load a qualified new image before using it.
