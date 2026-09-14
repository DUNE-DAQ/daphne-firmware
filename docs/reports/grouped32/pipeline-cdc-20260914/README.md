# Descriptor pipeline and control CDC candidate

This evidence supports the first timing-repair candidate on top of `d3bfb66`.
The selected RTL is identified by the source hashes in `ooc-selected/` and
`focused-source-manifest.json`. These are pre-commit working-tree experiments;
the next full-board build must use a fresh checkout of the resulting commit.
No routed timing result or firmware qualification is claimed here.

## Descriptor path

The grouped serializer now registers the selected sample and then the
baseline/polarity amplitude, with aligned start, valid, index and configuration.
It waits for descriptor completion before publishing headers and committing.
The grouped accumulator uses fabric addition; the native reference retains DSP
mapping and its original latency.

| Descriptor-only synthesis at 3.2 ns | LUT | FF | DSP | Setup WNS (ns) |
| --- | ---: | ---: | ---: | ---: |
| Original `8ae5f81` | 534 | 204 | 1 | -0.874 |
| Two-stage input, forced DSP experiment | 486 | 300 | 1 | +0.003 |
| Selected grouped implementation | 506 | 300 | 0 | +0.836 |

These out-of-context estimates constrain internal register paths only. They do
not include the board's BRAM source, clock network, congestion or input timing
budgets. Native default mapping was separately synthesized and retains one DSP.
Use `ooc-selected/` for the actual selected source; the earlier experiment
reports are retained for comparison.

The serializer takes 525 fast-clock cycles per record, measured over four
consecutive records. That provides 595,238 records/s per group against the
required 488,281 records/s, or 82.03% ideal engine utilization.

## Functional evidence

- Selected-source descriptor/serializer/reset and native continuation tests
  pass. Checks cover simultaneous start/sample 0, separate start, configuration
  changes, bubbles, final-sample closure, bank ownership, overflow and reset.
- Real Vivado XPM memory/FIFO/CDC models pass eight contract cases and sustained
  32-channel mode 0 replay with a 700 ps clock offset: 3,392 grouped packets
  exactly match 3,392 reference packets, with zero loss. The oracle checked
  3,473,408 samples and 81,408 descriptor words; maximum latency is 1,128 ADC
  ticks. `vendor-replay/summary.json` records commands, source/vendor hashes and
  CSV checksums; the archive contains logs and repository source snapshots.
- That long vendor replay used the forced-DSP pipeline source. Its only RTL
  difference from the selected implementation is the static `use_dsp`
  attribute selection, which does not change RTL simulation behavior. Selected
  source focused tests and synthesis were rerun. The runner's later local-test
  orchestration edit did not change the packet oracle.
- GHDL modes 0 and 1 also passed with zero loss. Mode 1 checked 3,372
  byte-identical packets under staggered activity and short stalls. Modes 2–4
  were still running when this evidence was
  prepared; their success is not implied by the completed mode 0 case.

## Control and reset crossings

Hermes transfers the 20-bit header ID and encoded status through coherent XPM
mailboxes. Independent PHY/status flags use three-stage level synchronizers.
Header ID publication waits for an actual accepted packet end, including when
transmit-enable drops during a stalled packet. The focused regression detects
the old mixed-ID behavior; both the local and actual-XPM positive results are
retained in the control-boundary evidence directories.

The existing 186-bit network configuration mailbox now drains an active exchange
through register-bank reset, then refreshes the reset/current configuration.
The actual UDP top passes a real-XPM test covering stopped destination clocks,
six reset phases and all mapped header fields. The identical bench fails the
old `8ae5f81` UDP top with an XPM handshake violation. This test observes the
actual TX configuration boundary; it does not construct Ethernet wire packets.

PDTS address/deskew completion levels now pass through explicit synchronizers
before the state machine. Broad exceptions into that state machine were removed.
The diagnostic frequency-counter synchronizer is marked `ASYNC_REG`, with a
post-synthesis exception only to its first-stage D pin. The other paths remain
timed. The endpoint test and board constraint contracts pass.

Full-board synthesis, placement/routing and review of remaining interface/CDC
findings are outstanding. See [the plan](../../../grouped32-timing-closure-plan.md)
and [baseline audit](../audit-20260914-8ae5f81/README.md).
