# AMD XPM vendor-model replay: `5d83890`

Vivado 2026.1 XSIM ran the installed AMD XPM memory, CDC, and FIFO models
against a clean, pinned
`5d83890f73a9de6c9cfcef9417c5082b0a8979fe` source checkout. Eight
reset, serializer, and continuation contract cases passed, followed by the
32-channel mode-0 replay at a 700 ps clock phase offset. Its independent
packet oracle checked **3,392 grouped and 3,392 reference packets**, all
byte-identical, including **3,473,408 samples** and **81,408 descriptor
words**. The real-XPM simulation reported zero loss.

`summary.json` records the exact commands, analyzed source and vendor-model
hashes, clean source status, case metrics, and packet CSV SHA-256. The
individual simulation logs are preserved here; the 13 MB packet CSV remains
in the local pinned build directory. This validates the tested packet behavior
with AMD's models, not routed timing or hardware capture margins.

Verify the committed files with `sha256sum -c SHA256SUMS`.
