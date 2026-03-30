# Control Plane

## Scope

Neutral name for the PS-visible control and status plane:

- register decode
- AXI-Lite leaf adapters
- safe response policy for missing or disabled features
- aggregation of subsystem status into a stable software contract

## Imported sources currently involved

- `rtl/config/`
- `rtl/frontend/fe_axi.vhd`
- `rtl/selftrig/thresholds.vhd`
- timing AXI adapter in `rtl/timing/ep_axi.vhd`

## Isolation objective

Keep the external register map unchanged while making the internal control API
typed, explicit, and proof-friendly.

## Later formal targets

- reset defaults
- readback consistency
- rejection or defined handling of partial writes
- safe response for unmapped or disabled regions
