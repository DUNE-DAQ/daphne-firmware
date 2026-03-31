# PL I2C Linux Binding Blocker

## Priority

This is the highest-priority firmware integration issue observed after the
March 31, 2026 board validation of `origin/marroyav/formal_verification` at
commit `7f032ac`.

The overlay loads successfully through `xmutil`, but the Linux-visible PL I2C
path needed for clock-chip control does not come back on the target.

## Observed behavior on target

Board:

- `NP04-DAPHNE-014`

Firmware under test:

- branch: `origin/marroyav/formal_verification`
- commit: `7f032ac`
- app payload: `daphne_selftrigger_ol_7f032ac`

Runtime facts observed on the board after `xmutil loadapp`:

- the PL app loads successfully and reaches FPGA manager state `operating`
- only `/dev/i2c-1` is present in Linux
- `/dev/i2c-2` is absent
- `i2cdetect -y 1` does not show the clock generator at `0x70`
- the service-chain clock configuration step fails immediately because
  `clk_conf.sh` expects bus `2`, chip `0x70`
- direct endpoint probing through `devmem` can hang the board once the external
  timing clock path is not configured

## Why this points to firmware / DT integration

The hardware design still instantiates the PL AXI IIC controller:

- `axi_iic_0` is created in
  [daphne_bd_gen.tcl](./../xilinx/daphne_bd_gen.tcl)
- its AXI-Lite register window is still assigned at `0x9C000000`
- its interrupt is routed through `axi_intc_0`

So the problem is not that the I2C block disappeared from the design.

The failure is at the Linux integration boundary:

- the generated overlay and runtime bind path are not restoring a Linux-usable
  PL I2C device for this firmware build
- `daphne-server` currently depends on that Linux path through `/dev/i2c-2`
  for the clock generator and other mezzanine I2C devices

## Working hypothesis

The most likely root cause is that the generated PL device-tree overlay is not
describing or binding the AXI IIC path correctly on target, even though the
underlying hardware exists.

Supporting evidence:

- the packaging flow still emits `dtc` warnings around PL interrupt-provider
  formatting
- both `axi_iic_0` and `axi_quad_spi_0` depend on the PL AXI interrupt
  controller path
- the board loses the expected Linux-visible PL I2C bus after loading the new
  overlay

This should be treated as a DT overlay / Linux probe failure until proven
otherwise.

## Required fix

The immediate requirement is:

1. load the firmware overlay on target
2. verify that the PL AXI IIC controller appears as a Linux device
3. verify that the expected PL I2C bus node is created
4. verify that the clock generator at `0x70` is reachable through that path

This is the acceptance bar, not just:

- `.bit` generated
- `.dtbo` generated
- `xmutil loadapp` returned success

## Short-term fallback

If restoring the Linux I2C binding takes longer, a temporary workaround is
possible:

- access the AXI IIC controller directly over AXI-Lite at `0x9C000000` through
  `/dev/mem`
- use polling instead of relying on the Linux `xiic-i2c` driver path

That would remove the dependency on `/dev/i2c-2`, but it is still a workaround.
The primary fix remains: restore the Linux-visible PL I2C contract.

## Next validation commands on target

After the next firmware/overlay fix, the target validation should start with:

```bash
ls -l /dev/i2c-*
sudo i2cdetect -y 1
dmesg -T | egrep -i 'xiic|i2c|9c000000|9c010000|irq|amba_pl'
find /sys/devices/platform/amba_pl -maxdepth 2 | sort
find /sys/bus/platform/devices -maxdepth 1 | egrep '9c000000|i2c|xiic'
```

The service-chain validation should only continue after the expected PL I2C
device is present again.
