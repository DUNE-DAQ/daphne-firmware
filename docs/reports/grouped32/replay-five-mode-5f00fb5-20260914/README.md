# Five-mode grouped32 replay for `5f00fb5`

The pinned serializer pipeline in `5f00fb5` passed the local GHDL grouped32
replay in modes 0–4 at phase 0 ps. The runs analyzed identical source hashes
(`source-manifest.json`) and used the independent packet, waveform, and peak
descriptor oracle in `scripts/verification/run_grouped32_tests.py`.

Across all modes, the oracle checked **16,198,656 samples** and **379,656
descriptor words** in **15,956 grouped** and **15,682 reference** packets.
All **13,180 common packets** were byte-identical. Modes 0 and 1 were
sustainable with no lost fragments; modes 2 and 3 exercised overload and
legacy overlap; mode 4 exercised the final replay condition. The grouped
serializer's focused bench also passed 480 addressed writes and four complete
commits. The exact per-mode counts, latencies, and packet-CSV SHA-256 hashes
are in `summary-phase0.json`.

This is behavioral evidence, not placed/routed timing qualification or board
testing. The CSV waveforms are retained in local ignored build directories,
with their hashes in the committed JSON. One first attempt at mode 4 was
deliberately stopped to preserve memory during parallel Vivado synthesis;
the complete rerun above passed.
