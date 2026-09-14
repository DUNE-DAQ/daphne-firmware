# DAPHNE-14 SPI Pinmux Audit

This note records the mezzanine SPI MIO ownership audit for `daphne-14`, the
runtime checks done on the live board, and the repo-owned DT patch required to
make the PS-side mezzanine SPI GPIO path available by default.

## Why this matters

The `daphne-14` schematics dedicate a large set of PS MIO pins to mezzanine
SPI wiring, but the live KR260 default DT claims many of those pins for:

- `gem1`
- `usb0`
- `usb1`

That conflict must be resolved at boot-time device-tree level, not through a
late userspace service.

## Mezzanine SPI pins from the schematics

| Mezz | CS | SCLK | SDO | SDI |
| --- | --- | --- | --- | --- |
| MEZ0 | MIO38 | MIO39 | MIO40 | MIO50 |
| MEZ1 | MIO41 | MIO42 | MIO43 | MIO61 |
| MEZ2 | MIO62 | MIO63 | MIO73 | MIO74 |
| MEZ3 | MIO69 | MIO68 | MIO67 | MIO57 |
| MEZ4 | MIO65 | MIO64 | MIO46 | MIO45 |

## Live DT owners on daphne-14

The running DT on `daphne-14` showed:

- `ethernet@ff0c0000` (`gem1`) = `status = "okay"`
- `usb@ff9d0000` (`usb0`) = `status = "okay"`
- `usb@ff9e0000` (`usb1`) = `status = "okay"`

Those default pinctrl groups owned the SPI-conflicting MIOs.

## Key runtime findings

- management IP `10.73.137.160/24` is carried on `eth0`
- `eth0` maps to `ff0b0000.ethernet` (`gem0`)
- the conflicting Ethernet block is `gem1`, not the management path
- both USB controller nodes were enabled in DT but their `dwc3-xilinx` probes
  were already failing with `-110`
- the current userspace SPI path `/dev/spidev-daphne` is PL `spidev3.0`, not
  these reclaimed PS MIO pins

## Reference patch vs. live DT

Two different DT shapes have circulated for `daphne-14`:

1. an older board-specific patch sketch that looks roughly like:
   - `ff0b0000` forced to a debug Ethernet role
   - `gem1` kept enabled for SFP/SGMII
   - `i2c0` enabled for SFP EEPROM
   - `sdhci1` enabled
2. the later live decompiled DT from the board after the SPI-safe boot-time
   patch was staged

The later decompiled DT is the stronger source of truth for the booted board.
That live DT showed:

- `ethernet@ff0b0000` (`gem0`) still active as the management path
- `ethernet@ff0c0000` (`gem1`) disabled
- `usb0` disabled
- `usb1` disabled
- `i2c1` still active
- `i2c0` disabled
- `sdhci1` disabled

So the repo should **not** blindly copy the older small patch verbatim. In
particular, re-enabling `gem1` would directly conflict with the SPI-safe MIO
reclaim goal.

For the repo-owned default DAPHNE image, the intended policy is the one proven
by the later live DT:

- keep `gem0`
- disable `gem1`
- disable `usb0`
- disable `usb1`
- keep `i2c1`
- leave `i2c0` and `sdhci1` unchanged unless there is a separate board-level
  reason to restore them
- mux the mezzanine SPI-conflicting MIOs to `gpio0`

## Conclusion from the audit

For the default DAPHNE image:

- keep `gem0`
- do not disable `i2c1`
- do not disable `uart1`
- disable `gem1`
- disable `usb0`
- disable `usb1`
- disable `dwc3_0`
- disable `dwc3_1`
- mux the mezzanine SPI MIOs to `gpio0` at boot time

## Repo-owned patch point

The active DT append point is:

- `petalinux/meta-daphne/recipes-bsp/device-tree/files/system-user.dtsi`

The current repo-owned patch does two things:

1. keeps the earlier `amba_pl` deletion that prevents the base DT from probing
   PL timing peripherals before the overlay loads
2. adds the PS MIO reclaim for mezzanine SPI GPIO ownership

That means this SPI pinmux policy is now part of the default DAPHNE image DT
policy rather than an out-of-band board-local tweak.

## Intended validation after the next DT build

After rebuilding the DTB and deploying it on a board using the DAPHNE image,
the first checks should be:

```bash
ip -br addr
dmesg | egrep 'macb|dwc3|usb'
dtc -I fs -O dts /sys/firmware/devicetree/base 2>/dev/null | \
  rg -n 'ethernet@ff0c0000|usb@ff9d0000|usb@ff9e0000|status = "disabled"'
```

Expected result:

- `eth0` on `gem0` remains the management path
- `gem1`, `usb0`, and `usb1` no longer claim the SPI-conflicting MIOs
- the GPIO pinmux groups for the mezzanine SPI MIO set are selected at boot

## Architectural note

This does **not** create a native Linux SPI controller by itself.

What it does:

- frees the PS MIOs from conflicting default owners
- exposes them under a deterministic GPIO pinmux

That leaves two separate SPI models in the design:

- existing PL-owned SPI paths already used by the analog control plane and
  `/dev/spidev-daphne`
- future PS-side mezzanine SPI software control, which can be implemented as a
  GPIO-backed bit-banged SPI backend if needed

The important rule is:

- boot-time DT owns the pinmux
- Linux exposes GPIO or SPI devices
- services/applications use what the kernel exposes

Do not use a runtime service as the primary mechanism to assign those MIOs.
