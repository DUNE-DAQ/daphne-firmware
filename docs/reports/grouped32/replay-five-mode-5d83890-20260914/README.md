# Five-mode grouped32 replay: `5d83890`

The added packer-input register was tested against a frozen source snapshot
matching all 23 replay inputs in committed revision
`5d83890f73a9de6c9cfcef9417c5082b0a8979fe`. GHDL passed the serializer,
reset synchronizer, odd-start continuation, edge, and overload contracts in
`contracts.log`, then passed all five 32-channel packet replay modes at zero
phase offset.

Across the five modes, the independent oracle checked **15,956 grouped and
15,682 reference packets**, **16,198,656 samples**, and **379,656 descriptor
words**. All **13,180** packets common to the grouped and reference outputs
were byte-identical. Modes 0 and 1 had zero loss and continuous 512-sample
chains; overload modes checked every emitted packet and accounted for
whole-fragment drops. Mode 4 exercised reset and counter-control behavior.

Every mode's packet CSV SHA-256 is **identical** to the already published
[`5f00fb5` replay](../replay-five-mode-5f00fb5-20260914/README.md). The
second stage therefore preserved every tested output byte and the recorded
maximum packet latencies. `summary-phase0.json` has per-mode counts, latency,
and CSV hashes; `source-manifest.json` has exact input hashes. The large CSVs
remain in the local build directories and are not committed. This replay
checks RTL behavior, not placed/routed timing or AFE board capture margins.

Verify the committed evidence with `sha256sum -c SHA256SUMS`.
