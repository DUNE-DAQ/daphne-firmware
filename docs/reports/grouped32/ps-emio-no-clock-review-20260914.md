# PS EMIO `no_clock` classification

The complete post-synthesis `check_timing` report for commit `5e86a75`
identifies eight register/latch pins without clocks, all on the Zynq UltraScale+
PS8 hard macro. They are `EMIOENET[0..3]MDIOMDC`, `EMIOSDIO[0..1]CLKOUT`, and
`EMIOSPI[0..1]SCLKO`. No fabric register appears in this `no_clock` list.

The source PS configuration in `xilinx/daphne_bd_gen.tcl` classifies them:

| PS output pin(s) | Peripheral configuration | Expected PL use |
| --- | --- | --- |
| ENET0–3 MDIO MDC | All four PS ENET peripherals disabled | None; Hermes uses four separate XXV Ethernet PL PHY paths |
| SDIO0 CLKOUT | SD0 enabled, routed to MIO 13–22 | None through EMIO |
| SDIO1 CLKOUT | SD1 disabled | None |
| SPI0 SCLKO | SPI0 disabled | None |
| SPI1 SCLKO | SPI1 enabled, routed to MIO 6–11 | None through EMIO |

The BD source contains no connection referring to any of these eight EMIO
outputs. This is a **source-level classification**, not a substitute for the
fresh post-synthesis/placed netlist check: inspect fanout from these eight PS
pins and verify that none drives a fabric sequential clock pin. If they have
no fabric loads, retain the `check_timing` warning with this explanation;
do not create fabricated clocks or waive an active clock path. If a load is
found, trace its actual clock source and add the correct generated-clock or
interface model before timing sign-off.

Evidence: `docs/reports/grouped32/audit-20260914-5e86a75/check_timing.rpt`
lines 32–43, `xilinx/daphne_bd_gen.tcl` PS ENET, SD and SPI configuration
near lines 1053–1056 and 1313–1331, and the BD source
`bd/daphne_selftrigger_bd/daphne_selftrigger_bd.bd`.
