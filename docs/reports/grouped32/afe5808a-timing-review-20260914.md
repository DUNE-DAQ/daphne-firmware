# AFE5808A timing review for K26C grouped32

Source: TI [AFE5808A datasheet, SLOS729D, revision D, §§7.7–7.9 and
8.6.2.9](https://www.ti.com/lit/ds/symlink/afe5808a.pdf). TI's
[serial LVDS capture application note, SBAA205](https://www.ti.com/lit/an/sbaa205/sbaa205.pdf)
explains the receiver clock and PCB-skew considerations. This review uses the
device specification supplied by the hardware owner; it is **not** a validated
K26C timing model.

The hardware owner confirmed on 2026-09-14 that the board runs the AFE5808A in
16-bit LVDS mode at 62.5 MHz. The live RTL (`febit3.vhd`,
`frontend_common.vhd`) requires 16-bit, LSB-first serialization and uses a
62.5 MHz AFE word/forwarded clock, a 500 MHz FPGA
serial capture clock and a 125 MHz byte clock. This implies an 8× AFE DCLK and
`16 × 62.5 MHz = 1.000 Gb/s` per LVDS data lane. The input port for each AFE
contains eight data lanes plus FCLK; the current capture RTL has no incoming
AFE DCLK port. The board manifest's optional virtual launch clock is 2.000 ns,
but its input-delay min/max fields are empty and the feature is disabled.

The TI table gives the following *minimum* timing at characterized 14-bit
rates, measured between data/FCLK and the AFE output DCLK zero crossing:

| ADC clock and output mode | Serial rate | `tSU,min` | `tH,min` | `tPROG,min..max` |
| --- | ---: | ---: | ---: | ---: |
| 65 MHz, 14 bit | 910 Mb/s | 0.24 ns | 0.24 ns | 11–12.5 ns |
| 50 MHz, 14 bit | 700 Mb/s | 0.41 ns | 0.46 ns | 13–14.4 ns |

TI says the timing data can also apply at corresponding 12- or 16-bit LVDS
rates. It describes 65 MHz × 14 bits = 910 Mb/s as its maximum example,
approximately equivalent to 56 MHz × 16 bits. The firmware's 1.000 Gb/s is
about 9.9% above 910 Mb/s. The datasheet supplies **no min/max output-interface
timing row for 16-bit operation at 62.5 MHz**. This does not prove the board
cannot work, but it prevents claiming datasheet-guaranteed PVT timing for the
present mode. The current Vivado implementation run remains useful for
internal timing and placement; it cannot close this external device contract.

Even for a supported serial rate, `tSU` and `tH` are eye margins relative to
the AFE output DCLK. They are not Vivado `set_input_delay -min/-max` values
relative to the FPGA's internally generated 500 MHz clock. The latter need a
clock-to-output/phase model for the actual serialization mode, the FPGA→AFE
forwarded-clock trace, AFE→FPGA data and FCLK trace delays, inter-lane skew,
voltage/temperature margin, and the intended capture phase and IDELAY range.
The TI timing values assume perfectly matched receiver data/clock paths;
additional mismatch reduces margin. The current optional virtual clock is
free-running and has no explicit phase relationship to the forwarded-clock
output, so simply filling two numeric board-manifest fields would not establish
that model.

Before enabling AFE input delays for qualification:

1. Record the fitted AFE part and SPI register readback for the confirmed
   16-bit, 62.5 MHz setting. Obtain TI/hardware-owner validation for 1.000 Gb/s
   operation across the required conditions, or change the system mode/clock
   and requalify packet rate and capture logic.
2. Obtain PCB propagation min/max (or routed length and stackup tolerance) for
   FPGA forwarded clock to each AFE and all eight data plus FCLK returns,
   including connector/interposer variation. Record the board revision.
3. Build a source-related launch/capture clock model and per-lane min/max
   delays, then run placed/routed setup, hold and pulse-width analysis with
   IDELAY settings/ranges and repeat the FCLK training sweep on hardware.

No AFE input-delay value or timing exception was changed by this review.
