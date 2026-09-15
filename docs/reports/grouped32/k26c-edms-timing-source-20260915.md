# K26C PCB timing source

The board owner identified CERN EDMS navigator document `101959906` as the
source hierarchy for K26C PCB design data:

<https://edms.cern.ch/ui/#!master/navigator/document?D:101959906:101959906:subDocs>

The link is the authoritative starting point for choosing the released
assembly revision and its matching PCB layout or timing report. The EDMS page
loads as a JavaScript application and its subdocuments require CERN account
access.

## Downloaded package review

The board owner downloaded `3434842_1.zip` from that hierarchy on 2026-09-15.
The reviewed archive is at
`/mnt/c/Users/arroyave/Downloads/3434842_1.zip` and has SHA-256
`6579edc9191ed4fcc70989c6a1acb99754f510ac2afa1dcd8a2c8af1dca0174e`.
`unzip -t` validates all 13 entries.

The package identifies the hardware as **DAPHNE Mezz V2**. All 15 schematic
title blocks identify drawing `177020`, revision `0`; the PDF was generated on
2026-05-22 and records design approval on 2026-04-16. The accompanying
`DAPHNE_Mezz2_PCB_Specification.pdf` is dated 2026-06-26 and specifies:

- 14 layers: six signal and eight plane;
- FR408HR material and a nominal 92 mil total thickness, ±10%;
- 100 ohm differential impedance, ±10%, for LVDS;
- a proposed, illustrative stackup that the fabricator may alter to meet
  impedance targets, subject to Fermilab approval.

The PCB specification's Simbeor screenshots give these **nominal** 100-ohm
differential propagation values:

| Routing | Width / gap | Nominal differential impedance | Nominal delay |
| --- | --- | ---: | ---: |
| Top/bottom | 4 mil / 4 mil | 103.74 ohm | 135.531 ps/in |
| Internal | 4 mil / 4 mil | 95.6 ohm | 164.931 ps/in |

These values describe the proposed impedance geometries. They are not a
per-net route report, a final as-fabricated stackup, or propagation-delay
min/max limits.

The archive contains PCB layer prints, stackup and impedance targets,
schematic, BOM, assembly documents, mechanical data, and test/acceptance
documents. It contains no native PCB database, Gerber set, routed-net length
table, signal-integrity timing report, or per-net flight-time export. The layer
prints do not identify numerical lengths for the shared FPGA-to-clock-fanout
input, the five fanout-to-AFE clock outputs, or the 45 AFE-to-FPGA data/FCLK
differential pairs.

The schematic and BOM identify the 62.5 MHz clock fanout as TI
`CDCUN1208LPRHBR` (`U20`), configured for LVDS input and output. The official
[CDCUN1208LP datasheet](https://www.ti.com/lit/ds/symlink/cdcun1208lp.pdf)
specifies 3.8 ns typical LVDS propagation delay at 2.5 V or 3.3 V and 35 ps
typical / 50 ps maximum skew between identically configured, identically
loaded outputs. This characterizes the fanout device under its stated test
conditions; its 50 ps maximum must be combined with the board-route mismatch,
and it does not replace the missing per-net PCB data.

The package resolves the design identity, nominal stackup and nominal
propagation model. AFE timing sign-off still needs the following routed values
or per-net flight times from the released PCB database or its report export:

- FPGA-to-fanout input and fanout-to-AFE sampling-clock trace delay and skew;
- AFE-to-FPGA data-lane trace delays and lane-to-lane skew;
- AFE-to-FPGA FCLK trace delay and its skew relative to each data lane;
- the routing layer for each segment, via contribution, and min/max or
  tolerance basis used by the PCB report;
- confirmation that the fabricated boards use drawing `177020`, revision `0`,
  and the fabricator-approved final stackup matching this package.

Combine those PCB values with the AFE5808A's output timing for the confirmed
16-bit, 62.5 MHz mode before enabling `DAPHNE_AFE_CAPTURE_INPUT_DELAY_ENABLE`.
Until the per-net lengths and final-stackup numerical bounds are available,
the current internal routed timing result does not qualify the external LVDS
interface.
