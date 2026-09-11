# Fixed 512-sample continuation

This branch starts at the deployed-format 512-sample reference `7d5d3a6`.
It captures a triggered waveform as adjacent, independently readable 960-byte
packets. Each packet contains eight 64-bit header/descriptor words and 112
64-bit waveform words holding exactly 512 original 14-bit ADC samples.
The first packet starts 64 samples before its trigger timestamp. Every
continuation starts exactly 512 samples after the preceding grid start;
the final packet also contains 512 real samples. Calibration bits remain
in header word 1 bits 47:46. No extra transport word or variable length is used.

## Acquisition and admission

Each channel continuously records 2048 samples in two interleaved BRAM banks,
which provide two consecutive samples per read even for an odd start address.
A four-entry descriptor queue feeds a serializer with a 393-clock service
interval, below the 512-clock fragment interval. The existing 4096-by-72-bit
UltraRAM capacity is organized into 32 reserved slots of 128 words each.
The serializer writes the 112 payload words before the eight header words,
then publishes the slot as complete. Readout sees the original header-first
120-word order. A reader can never start an incomplete packet.

Continuation uses a baseline and polarity frozen at the chain's first trigger.
The existing `invert_enable` selects positive raw pulses; the inverted filter
baseline is converted back into raw ADC coordinates. Residual amplitude at or
above the configured threshold activates the chain; at or below half that
threshold it becomes inactive. At a boundary, another packet is requested if
the consecutive quiet-sample count has not reached its configured limit.
The final sample participates in that decision.

A coalesced trigger also requests coverage through trigger timestamp +447.
If its timestamp or its 64-sample pretrigger start intersects either of the
last two accepted grid windows, it joins that chain. A delayed trigger can
reopen a quiet-closed chain using retained ring samples. Thus a trigger at
previous packet end +64 still merges (one sample intersects); end +65 may
seed a fresh packet. The merged-trigger counter measures coalescing decisions,
not guaranteed complete coverage under output overload.

Admission reserves a complete output slot and checks queue space and a
conservative ring-retention budget before accepting the fragment. Rejection
drops the whole requested fragment; it never emits a partial packet or shifts
the chain grid. A rejected continuation is observable through counters and a
512-multiple timestamp gap. A later accepted fragment retains its continuation
flag. Disabling acquisition stops new requests and drains accepted packets.
Counter reset leaves acquisition and packet ownership intact.

The trigger, ADC sample and timestamp now traverse the same 64-clock delay
pipeline, so close trigger arrivals cannot overwrite an earlier trigger's
metadata. A 64-clock valid flush after reset prevents stale events without
resetting the shift-register data storage.

## Runtime registers

Offsets below are relative to the existing self-trigger AXI register bank.
Channel indices are 0 through 39. Existing registers keep their addresses.

| Address | Field | Meaning |
| --- | --- | --- |
| `channel*0x20 + 0x1C` | bit 31 | Enable continuation |
| same | bits 24:16 | Consecutive quiet samples, 0 treated as 1 |
| same | bits 13:0 | Raw residual threshold, 0 treated as 1 |
| same | other bits | Read as zero; writes ignored |

The reset value is `0x80200040`: continuation enabled, 32 quiet samples,
threshold 64 ADC counts. These are engineering defaults requiring detector
data tuning. Writes follow the bank's existing full-word WSTRB policy.
Disabling continuation keeps fixed 512-sample packets and allows the legacy
signal-delay overlap setting; it does not restore the old serializer.

| Read-only address | Counter |
| --- | --- |
| `0x800 + channel*0x20 + 0x00` / `+0x04` | Accepted continuation fragments, low/high |
| same base `+0x08` / `+0x0C` | Rejected continuation requests, low/high |
| same base `+0x10` / `+0x14` | Merged trigger decisions, low/high |
| same base `+0x18` / `+0x1C` | Completed packets with descriptor overflow, low/high |

Acquisition counters are modulo 32 bits, zero extended to their existing
64-bit interfaces. Software must sample often enough to unwrap them. At
122070 packets/s a packet counter wraps after approximately 9.8 hours.
Legacy trigger count measures rising edges; adjacent high valid clocks can
carry distinct trigger tuples while contributing one rising edge.

## Fragment descriptors and format compatibility

Header word 1 uses previously reserved bit 51 for continuation, bit 50 for
the new fragment descriptor algorithm, and bit 49 for descriptor overflow.
Bit 48 remains reserved. Packet length, field positions, raw ADC packing,
channel/version fields, and calibration fields remain unchanged. Consumers
must recognize bit 50 before interpreting descriptor values as the new
algorithm; these are not the legacy filtered wavelet descriptors.

The descriptor engine examines the actual 512 samples belonging to this
packet. It records the first five contiguous excursions strictly above the
raw residual threshold. Each slot stores residual sum, duration, largest
residual, first maximum's position within the excursion, and start position
within the packet. Number_Peaks is one per contiguous excursion. A 512-sample
duration saturates to 511 in the existing nine-bit duration field. Unused
slots retain the legacy invalid sentinels. Further excursions set overflow;
their ADC samples remain present. An excursion crossing a packet boundary is
described separately in each fragment. There is no shared trailer timer or
ownership ambiguity between overlapping captures.

## Capacity and validation

At 62.5 MHz one packet represents 8.192 microseconds. The two readout lanes
each scan 20 channels and consume at least 122 clocks per packet (120 words,
pause and scan). Aggregate ideal packet payload capacity is therefore about
7.87 Gbit/s before downstream limitations. Forty channels continuously
producing packets would require 37.5 Gbit/s. Continuation removes capture
gaps at sustainable offered load; it cannot remove output bandwidth limits.

Run the focused executable HDL contracts from a fresh temporary directory:

```bash
python3 scripts/verification/run_continuation_tests.py
```

They cover descriptor ownership, register integration, complete packet
readiness, all 512 decoded ADC samples, odd/even start addresses, long chains,
quiet termination, timestamp wrap, delayed triggers, admission edges,
disable/counter reset, and trigger tuple alignment. The local XPM fixture is
a common-clock, equal-width, one-cycle memory model; it is not a substitute
for vendor simulation or implemented timing/resource reports.

The independent `daphne_mezz_xc_sim` continuation branch generates coherent
candidate/ADC traces and paired reference/new-model coverage and bandwidth
data. `stc3_trace_replay_tb` replays those traces through the actual builder
and 40-channel two-lane mux. Distinguish candidate-window coverage, physical
pulse/charge capture, and output drops when interpreting deadtime improvement.
Reference baseline, new RTL, simulation source, waveform seeds and tool
versions must be pinned in the final evidence.

Cooper's Vivado 2026.1 vendor XPM simulation passed for RTL `355376f`: two
30-packet chains with even/odd starts, every ADC sample checked, plus the
timestamp/admission/disable/reset boundary bench. The local evidence archive
is `artifacts/continuation512/cooper-355376f/vendor-memory-sim.tar.gz` under
the workspace firmware directory, accompanied by SHA256. The vendor memory
source SHA256 is
`2ffcfc104eae061b7fefc3bda9d123d466c12df6363748284c1ca349b00cf75a`.

See [the Cooper build procedure](cooper-continuation-build.md). Resource fit,
routed timing and DRC remain qualification steps until their reports are
recorded. Input
spy buffers are still present in this candidate and may be removed if actual
implementation results show that their resources are needed.
