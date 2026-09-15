# Pinned K26C implementation evidence: `5d83890`

Vivado 2026.1 implemented source revision
`5d83890f73a9de6c9cfcef9417c5082b0a8979fe` on 2026-09-14 with
`DAPHNE_BOARD=k26c`, four Hermes PHY paths, a maximum of eight Vivado threads,
and the `2100@xilinx-lic` floating license server. The full implementation
chain exited 0. Routing, post-route physical optimization, bit/bin generation,
XSA export, and DTBO packaging completed. The pre-bitstream DRC had zero errors
and 842 warnings: 832 DSP input-pipelining advisories, eight RAM collision
advisories, one vendor I/O placement warning, and one no-routable-load warning.

**This revision does not meet routed setup timing and is not board qualified.**
The final timing report has WNS **-2.192 ns**, TNS **-82.082 ns**, and **472
failing setup endpoints**. The 312.5 MHz grouped builder accounts for 440 of
those endpoints (WNS **-0.160 ns**, TNS **-30.099 ns**). The builder improved
from 1,350 failing endpoints and -142.172 ns TNS in `5f00fb5`; its remaining
critical paths are mostly sparse descriptor RAM write enables and descriptor
offset metadata. The worst overall paths are Ethernet clock-domain and reset
crossings. Hold and pulse-width have zero failing endpoints. The report retains
12 `TIMING-6` and 20 `TIMING-7` critical clock methodology warnings.

Post-route utilization is 96,852/117,120 CLB LUTs (82.69%), 82,942/234,240 CLB
registers (35.41%), 91 BRAM tiles, 32 URAMs, and 832 DSPs. The board mode is now
confirmed as AFE5808A 16-bit LVDS at 62.5 MHz. This is 1 Gb/s per lane, while a
validated AFE output-delay and K26C PCB-skew min/max model is still unavailable,
so external AFE timing is not qualified. The XXV Ethernet IP still reports
unlicensed mandatory features during IP generation, although this build
produced all artifacts. Artifact existence does not establish licensed runtime
operation. No FPGA was programmed.

The generated artifacts remain under
`/home/marroyav/work/daphne-grouped32-5d83890-impl-20260914/xilinx/output-5d83890/`.
Their SHA-256 hashes are:

| Artifact | SHA-256 |
| --- | --- |
| `daphne_selftrigger_5d83890.bit` | `d64d1af9c53d4fb8629599c4de7ea6ab41c3a80b9b8db742437ab47392ccd397` |
| `daphne_selftrigger_5d83890.bin` | `500b3230737fa57db678fad20db66cf13b2d1ebb3aef686576959a418985c470` |
| `daphne_selftrigger_5d83890.xsa` | `f67828c1b73fca55cdd68d513802fb58bdaa18f65573679f747e7c34f615499c` |
| `daphne_selftrigger_5d83890.dtbo` | `ee9287740efc6cd4506c9971ceb4fff4d811c92aed2affdfd924354b6fc829ff` |

The XSA passed `unzip -t`; the DTBO parses as a version-17 Device Tree Blob.
The routed DCP, binaries, and full Vivado build directory are local. This
directory preserves the key original timing, utilization, methodology, and DRC
reports for remote review. `SHA256SUMS` checks the committed report files.
