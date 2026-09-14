# Pinned K26C implementation evidence: `5f00fb5`

Vivado 2026.1 implemented source revision
`5f00fb55f1d6fb22497c06cae1e3c020ece48599` on 2026-09-14 with
`DAPHNE_BOARD=k26c`, four Hermes PHY paths, eight Vivado threads, and
`LM_LICENSE_FILE=2100@xilinx-lic`. The full remote chain exited 0. Routing,
post-route physical optimization, bit/bin generation, XSA export, and DTBO
packaging completed. The pre-bitstream DRC had zero errors and 842 warnings:
832 DSP input-pipelining advisories, eight RAM collision advisories, one
vendor I/O placement warning, and one no-routable-load warning.

**This revision does not meet routed setup timing and is not board qualified.**
The final timing report has WNS **-1.715 ns**, TNS **-187.241 ns**, and
**1,383 failing setup endpoints**. The 312.5 MHz grouped builder accounts for
1,350 endpoints (WNS **-0.235 ns**, TNS **-142.172 ns**). Its worst routed paths
still run from a sample-ring BRAM to the serializer's registered FIFO write
input. The other 33 failing endpoints are Ethernet CDC/reset paths plus one
minor asynchronous clock-path check. Hold and pulse-width have zero failing
endpoints. The report has 12 `TIMING-6` and 20 `TIMING-7` critical clock
methodology warnings. A second packer-input stage, under separate replay and
implementation review, is not in this pinned checkpoint.

Post-route utilization is 97,030/117,120 CLB LUTs (82.85%), 82,745/234,240
CLB registers (35.32%), 91 BRAM tiles, 32 URAMs, and 832 DSPs. External AFE
input min/max delays remain unset pending a validated 16-bit, 62.5 MHz AFE
output timing model and K26C PCB skew bounds. The XXV Ethernet IP still reports
unlicensed mandatory features during IP generation, although this build
produced all artifacts. Artifact existence does not establish licensed runtime
operation. No FPGA was programmed.

The generated artifacts remain under
`/home/marroyav/work/daphne-grouped32-5f00fb5-impl-20260914/xilinx/output-5f00fb5/`.
Their SHA-256 hashes are:

| Artifact | SHA-256 |
| --- | --- |
| `daphne_selftrigger_5f00fb5.bit` | `e529405c9a3c886574c1eee328975eafb9055c033df5a52c66b9ab98d8a25bc4` |
| `daphne_selftrigger_5f00fb5.bin` | `10d0b485affe9115b3a0371d1b5320d534f263c399ed857e2173b650f3b8476b` |
| `daphne_selftrigger_5f00fb5.xsa` | `fd349655e141abb32fc5a2f1a4c8185f53f04457883647ad36f6c75e780fb252` |
| `daphne_selftrigger_5f00fb5.dtbo` | `9000fe42d9e62d991f868304b5028aeed350e290b63e3fb5a78f18906d25dec5` |

The XSA passed `unzip -t`; the DTBO parses as a version-17 Device Tree Blob.
The routed DCP, binaries, and full Vivado build directory are local, not in
this Git report. This directory preserves the key original timing,
utilization, methodology, and DRC reports for remote review. `SHA256SUMS`
checks the committed report files.
