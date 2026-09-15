# Exact-candidate five-mode grouped32 replay: `26bb229`

GHDL 5.0.1 ran the grouped-builder contracts and all five 32-channel replay
modes against source files matching
`26bb2295ac459a2f621abc66e4e4e8f91bcf55f9`. Every source hash is recorded in
`source-manifest.json`; direct comparison with `git show 26bb229:<path>` passed
for every listed input.

All reset synchronizer, serializer, continuation, edge, overload, packet, and
independent-oracle checks passed. Across the five modes, the oracle checked
**15,956 grouped packets**, **15,682 reference packets**, **16,198,656 ADC
samples**, and **379,656 descriptor words**. All **13,180 common packets** were
byte-identical. Modes 0 and 1 had zero loss. Mode 2 deliberately blocked all
lanes and reported 1,168 whole-fragment losses; mode 3 applied dense forced
triggers and reported 1,242. Both overload tests drained and recovered without
partial packets.

Every mode's packet count, common/unique split, maximum latency, and packet CSV
SHA-256 is identical to the earlier `5d83890` replay. This closes the functional
regression gap introduced by the later descriptor-write pipeline change in
`e70df6a`. The large packet CSV files remain in the local build directories and
are represented by their hashes in `summary-phase0.json`.

The inputs are deterministic synthetic ADC data, not an AFE analog/LVDS or
detector-distribution model. See the
[approval report](../approval-review-20260915.md) for the five mode definitions,
assumptions, proof boundary, dead-time interpretation, and release conditions.

Reproduce from the exact candidate with:

```sh
git checkout 26bb2295ac459a2f621abc66e4e4e8f91bcf55f9
python3 scripts/verification/run_grouped32_tests.py \
  --output-dir build/grouped32-approval
```

Verify the compact evidence with `sha256sum -c SHA256SUMS`.
