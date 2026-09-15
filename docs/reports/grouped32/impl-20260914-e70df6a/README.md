# Pinned K26C implementation evidence: `e70df6a`

Vivado 2026.1 implemented source revision
`e70df6a29e24cd98e534acec702a88084602cae8` on 2026-09-14 with
`DAPHNE_BOARD=k26c`, four Hermes PHY paths, a maximum of eight Vivado threads,
and the `2100@xilinx-lic` floating license server. The remote build chain exited
0. Routing, post-route physical optimization, bit/bin generation, XSA export,
and DTBO packaging completed. The pre-bitstream DRC had zero errors and 842
warnings: 832 DSP input-pipelining advisories, eight RAM collision advisories,
one vendor I/O placement warning, and one no-routable-load warning.

**This revision does not meet routed setup timing and is not board qualified.**
The final timing report has WNS **-1.976 ns**, TNS **-57.644 ns**, and **106
failing setup endpoints**. Hold and pulse-width timing have zero failing
endpoints. The failures divide into 69 grouped descriptor endpoints at 312.5
MHz (WNS **-0.089 ns**, TNS **-2.775 ns**), four PDTS endpoint paths (WNS
**-0.221 ns**), twelve XXV Ethernet status/reset-data crossings, twenty
asynchronous recovery paths, and one IDELAYCTRL recovery path. All ordinary
same-clock TX and RX Ethernet paths meet timing. The routed methodology report
retains 12 `TIMING-6` and 20 `TIMING-7` critical clock warnings.

Post-route utilization is 96,582/117,120 CLB LUTs (82.46%), 83,496/234,240 CLB
registers (35.65%), 91 BRAM tiles, 32 URAMs, and 832 DSPs. The AFE5808A board
mode is confirmed as 16-bit LVDS at 62.5 MHz, or 1 Gb/s per serial lane. A
validated AFE output-delay/phase and K26C PCB-skew min/max model is still
unavailable, so external AFE timing remains unqualified. The XXV Ethernet IP
still reports unlicensed mandatory features during IP generation. Artifact
generation alone does not establish licensed runtime operation. No FPGA was
programmed.

The generated artifacts remain under
`/home/marroyav/work/daphne-grouped32-e70df6a-impl-20260914/xilinx/output-e70df6a/`.
Their SHA-256 hashes are:

| Artifact | SHA-256 |
| --- | --- |
| `daphne_selftrigger_e70df6a.bit` | `649345a56bd3fbe3ddea96b211fde2278c7a2598ea9f546512a9995b4047a453` |
| `daphne_selftrigger_e70df6a.bin` | `64289e7588ec452d45bd49fa5d859286be62fec6069ae079eed93f8067b7bb66` |
| `daphne_selftrigger_e70df6a.xsa` | `14b99749b18c2c1fa82b676afe41807ec5214018a7dbb24b36af10da5c8c990d` |
| `daphne_selftrigger_e70df6a.dtbo` | `9496dabd1a4225712db8a71edb6c6f872c61f2ed7c7dbdb2e92cb3ae5a01c03a` |
| `daphne_selftrigger_ol_e70df6a.zip` | `27a5a00841f20ce38323cb33aae1f53995d500e66cdcae49720bfee1484ab61e` |

The XSA passed `unzip -t`; the DTBO parses as a version-17 Device Tree Blob.
The routed DCP, binaries, and full Vivado build directory are retained locally.
This directory preserves the key original timing, utilization, methodology,
and DRC reports for remote review. `SHA256SUMS` verifies the committed files.
