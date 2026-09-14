# Pinned K26C implementation evidence: `d1d07ac`

Vivado 2026.1 implemented detached source revision
`d1d07ac26deaa0b5ea445137035a07e8b9c434f9` on 2026-09-14 with
`DAPHNE_BOARD=k26c`, four Hermes PHY paths, eight Vivado threads, and
`LM_LICENSE_FILE=2100@xilinx-lic`. The remote chain exited 0. Routing,
post-route physical optimization, bitstream generation, XSA export, and
device-tree overlay packaging completed. The pre-bitgen DRC reported zero
errors. The XSA ZIP passed `unzip -t`, the DTBO parsed with `dtc`, and the
packaged `SHA256SUMS` verified.

This is **not a timing-qualified or hardware-validated image**. The routed
timing summary reports WNS **-2.441 ns**, TNS **-1872.148 ns**, and **5,376
failing setup endpoints**. Of those, **5,328** are on the grouped 312.5 MHz
`clock_raw_s_1` domain (WNS -1.011 ns, TNS -1778.986 ns). Hold and pulse-width
have zero failing endpoints. The worst async recovery checks are the four
Hermes TX source-reset synchronizers; a narrow PRE-pin exception and a FIFO
write pipeline were added in later revision `5f00fb5`, so this report does
not measure those fixes. The 16 `TIMING-6` and 24 `TIMING-7` critical clock
methodology warnings still need a clock-relationship review. External AFE
input delays remain unset pending board skew and device-output bounds.

Vivado reported the XXV Ethernet IP licenses as unavailable during IP output
generation, yet generated bit/bin/XSA/DTBO files from this build. The files'
existence does not establish licensed runtime behavior; see the sibling XXV
license review. No FPGA was programmed.

The generated artifacts remain under
`/home/marroyav/work/daphne-grouped32-d1d07ac-impl-20260914/xilinx/output-d1d07ac/`.
Their SHA-256 hashes are:

| Artifact | SHA-256 |
| --- | --- |
| `daphne_selftrigger_d1d07ac.bit` | `2782f8ba46c88cd15555222fbe785f5e7428bda41bd4d02fdb7f7906e5d0dfd1` |
| `daphne_selftrigger_d1d07ac.bin` | `1e7aaeb0438a50b88086777e79dd400d12cb7b7fa038c23b4fea85e2face1501` |
| `daphne_selftrigger_d1d07ac.xsa` | `8b1f3e6359e241f255610fd0f7d3276dd4e0ca0927b16cc3c61ffb2eca94f8db` |
| `daphne_selftrigger_d1d07ac.dtbo` | `47d518f3d0bebba8fdb70f73fa9fccc26f135a42c9031672c56b070a9a3171bf` |

This directory contains the synthesis and routed timing, utilization,
methodology, and post-implementation DRC reports for remote review. The
210 MB routed checkpoint and binary artifacts are not committed here.
