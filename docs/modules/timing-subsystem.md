# Timing Subsystem

## Scope

Neutral boundary for:

- endpoint control
- timing-derived clock selection
- lock/reset propagation
- timestamp and sync propagation into the rest of the design

## Imported sources currently involved

- `rtl/timing/endpoint.vhd`
- `rtl/timing/pdts_endpoint_wrapper.vhd`
- `rtl/timing/pdts_endpoint.vhd`
- `rtl/timing/ep_axi.vhd`

## Isolation objective

Keep the existing register meanings and timing concepts, but expose status and
control through cleaner typed interfaces instead of ad hoc signal bundles.

## Verification posture

- formal at the control boundary only
- simulation for endpoint integration and clocking behavior
