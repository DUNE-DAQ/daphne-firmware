# Frontend CDC Follow-Up

The current K26C post-route timing failure is concentrated in the frontend
`idelay_load` control crossing from `clk_pl_0` into `clk125_1`. The failing
endpoints are the explicit first-stage synchronizer flops in
`frontend_common`, for example:

- `frontend_register_bank_inst/.../idelay_load2_reg_reg/Q`
- `frontend_common_inst/idelay_load_clk125_meta_reg[*]/D`

That crossing is already implemented as a two-stage synchronizer with
`ASYNC_REG` on both stages in
[`rtl/isolated/subsystems/frontend/frontend_common.vhd`](../rtl/isolated/subsystems/frontend/frontend_common.vhd).

## Why The Constraint Change Is Narrow

The installed Vivado 2024.1 documentation on this machine recommends:

- `ASYNC_REG` on the synchronizer flops for safe asynchronous CDCs.
- `set_clock_groups` or clock-to-clock `set_false_path` only when all paths
  between the asynchronous clock pair are safely ignorable.
- point-to-point false-path exceptions when only selected synchronized CDC
  paths still need to be cut.

Local Xilinx references:

- `/mnt/c/Xilinx/Vivado/2024.1/doc/tcw/top.html`
- `/mnt/c/Xilinx/Vivado/2024.1/doc/tcw/clock_domain_crossings.html`
- `/mnt/c/Xilinx/Vivado/2024.1/doc/eng/man/report_cdc`
- `/mnt/c/Xilinx/Vivado/2024.1/doc/eng/man/set_clock_groups`

The key guidance in `clock_domain_crossings.html` is that if asynchronous
clock pairs are still being timed and the synchronized CDC paths need to be
cut selectively, the next step is to add point-to-point false-path exceptions
on those synchronized CDC paths.

## Repo Decision

For the frontend controls, the repo should follow the same style already used
by `xilinx/timing_endpoint_cdc.tcl`:

- cut the explicit first-stage synchronizer `D` pins with `set_false_path -to`
- keep the wider `-through` exceptions only for the truly asynchronous control
  nets that are not ordinary register-to-register CDC synchronizers

This is preferred over introducing a broad `set_clock_groups` between
`clk_pl_0` and `clk125_1`, because the repo only needs to exempt a small,
known set of synchronizer destinations.
