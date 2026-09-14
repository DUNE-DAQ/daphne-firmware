# External trigger input CDC repair

The baseline `check_timing` report lists `trig_IN` among nine non-AFE inputs
without input delays. It is an asynchronous board trigger, not a source-synchronous
data input. In the prior `fe_axi.vhd`, the raw pin fed six AXI-clocked pulse
stretcher D expressions. Different registers could therefore observe different
values around an edge; no two-stage synchronizer isolated metastability from
the trigger logic.

`fe_axi.vhd` now samples the pin in an `ASYNC_REG` two-register chain. Only the
second stage drives the existing six-cycle stretcher. The board constraint
`xilinx/external_trigger_cdc.tcl` cuts the asynchronous arrival only at the
first-stage D pin and requires exactly one matched pin; the second stage and
stretcher remain timed. This adds two AXI-clock cycles of trigger latency while
keeping the sampled pulse width and source separation unchanged. As before, a
pulse must overlap at least one AXI rising edge to be guaranteed captured; a
board-level minimum pulse-width requirement has not been supplied.

The focused `fe_axi_smoke_tb` covers a one-edge external pulse, confirms the
raw input cannot assert the output before the synchronizer, checks that the
external and legacy OR outputs agree for six cycles, checks that the software
source stays low, and verifies self-clear. It passed with GHDL after this edit:

```sh
ulimit -v 1000000
mkdir -p build/external-trigger-cdc-smoke
cd build/external-trigger-cdc-smoke
ghdl -a --std=08 ../../ip_repo/daphne_ip/rtl/daphne_package.vhd \
  ../../rtl/isolated/subsystems/frontend/frontend_register_slice.vhd \
  ../../rtl/isolated/subsystems/frontend/frontend_register_bank.vhd \
  ../../ip_repo/daphne_ip/rtl/frontend/fe_axi.vhd \
  ../../tests/logic/fe_axi_smoke_tb.vhd
ghdl -e --std=08 fe_axi_smoke_tb
ghdl -r --std=08 fe_axi_smoke_tb --assert-level=error
```

The active `d1d07ac` Vivado implementation is pinned before this edit. This
repair requires a new pinned full-board build and a post-synthesis check of the
first-stage pin match, CDC report and `check_timing` classification. It must not
be counted as qualified by the running build.
