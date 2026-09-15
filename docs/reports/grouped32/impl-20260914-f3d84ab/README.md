# Pinned K26C implementation evidence: `f3d84ab`

Vivado 2026.1 implemented source revision
`f3d84abff7d4a448fc3de13d9ae9490f80417b18` on 2026-09-14 with
`DAPHNE_BOARD=k26c`, all four Hermes PHY paths, a maximum of eight Vivado
threads, and the `2100@xilinx-lic` floating license server. The remote build
chain exited 0. Synthesis, placement, routing, post-route physical
optimization, bit/bin generation, XSA export, and DTBO packaging completed.
Vivado explicitly used up to eight CPUs for timing, DRC, placement, physical
optimization, routing, and bitstream generation.

The fully routed design meets every reported internal setup, hold, and pulse
width constraint:

| Check | Worst slack | Total negative slack | Failing endpoints |
| --- | ---: | ---: | ---: |
| Setup | +0.048 ns | 0.000 ns | 0 / 374,088 |
| Hold | +0.010 ns | 0.000 ns | 0 / 368,160 |
| Pulse width | +0.280 ns | 0.000 ns | 0 / 94,705 |

Routing finished with no failed, unrouted, or partially routed nets and no
remaining overlaps. The pre-bitstream DRC has zero errors and 842 warnings:
832 DSP input-pipelining advisories, eight RAM collision advisories, one vendor
I/O placement warning, and one no-routable-load warning. Post-route utilization
is 96,389/117,120 CLB LUTs (82.30%), 83,387/234,240 CLB registers (35.60%),
91 BRAM tiles, 32 URAMs, and 832 DSPs. CLB placement uses 14,620/14,640 CLBs
(99.86%).

The four Hermes channels use `GTHE4_CHANNEL_X0Y4`, `X0Y5`, `X0Y7`, and
`X0Y6`, and share `GTHE4_COMMON_X0Y1`. The routed methodology report contains
eight `TIMING-7` critical warnings for related XXV TX/RX clocks with no common
node. The previous twelve `TIMING-6` warnings are absent. It also reports 60
ports without input or output delay constraints. The AFE5808A mode is confirmed
as 16-bit LVDS at 62.5 MHz (1 Gb/s per serial lane), but a validated AFE
output-delay/phase and K26C PCB-skew min/max model is still unavailable, so the
external AFE interface is not timing-qualified.

Local formal verification passed 4/4 composable properties and 30/30 all-local
properties. The GitHub Formal workflow passed all five executed matrix jobs.
Board elaboration passed for all four tops, the Hermes four-clock/reset test
passed, continuation tests passed, reset-wrapper lint passed in Yosys and
Verilator, and the complete five-mode grouped32 replay regression passed.

The XXV Ethernet IP generation continues to report unlicensed mandatory keys
`xxv_eth_mac_pcs@2026.06`, `xxv_eth_basekr@2026.06`, and
`xxv_tsn_802d1cm@2026.06`. Successful artifact generation does not establish
licensed Ethernet operation. No FPGA was programmed.

The generated artifacts remain under
`/home/marroyav/work/daphne-grouped32-f3d84ab-impl-20260914/xilinx/output-f3d84ab/`.
Their SHA-256 hashes are:

| Artifact | SHA-256 |
| --- | --- |
| `daphne_selftrigger_f3d84ab.bit` | `db82ad2bbf7d8d11c65bb85029dc5b9094e5d0f1b3473bd876276bd981996872` |
| `daphne_selftrigger_f3d84ab.bin` | `cffd8e446c935fb4527328fb0fb27030486eb606784f72b816ea7738d39a861e` |
| `daphne_selftrigger_f3d84ab.xsa` | `d64f7a5e9b764b1d9ff9925d1d0049ffceb2e3bf41fd1d27a7ffe22f347bf7d6` |
| `daphne_selftrigger_f3d84ab.dtbo` | `7b37e23b8dc55bd3425eda4ab8e544337a4db409cba093a6558c07259da1af47` |
| `daphne_selftrigger_ol_f3d84ab.zip` | `e515c7a5f9093966847a7e43e85c0b356c9adfb41affaa49316aaa6761e51705` |

Both ZIP containers passed `unzip -t`; the DTBO parses as a version-17 Device
Tree Blob. The routed DCP, binaries, and complete Vivado logs remain local.
This directory preserves the primary timing, utilization, methodology, DRC,
clock, I/O, environment, and artifact reports for remote review.
