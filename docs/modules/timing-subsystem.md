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

## Constraints that must be explicit

The rest of the design depends on more than "timing block exists". The
contract needs to say when timing-derived outputs are actually trustworthy.

- `CLOCK_SOURCE` selects between local and endpoint-derived timing.
- `MMCM0_LOCKED` and `MMCM1_LOCKED` are prerequisites for trusting the derived
  frontend clocks.
- The endpoint-ready path is not equivalent to clock lock alone.
- `TIMESTAMP_OK` and endpoint FSM state are required before treating endpoint
  timestamp/sync outputs as valid.

In other words, downstream logic should not treat "received clock present" as
the same thing as "timing subsystem ready".

The frontend alignment path depends on this distinction. Alignment should only
start once the selected timing path is stable enough to trust the frontend
clocks derived from it.

## Readiness model

When endpoint timing is selected, the safe conceptual readiness condition is:

- endpoint clock selected;
- clock-generation path locked;
- endpoint state machine in ready state;
- timestamp path valid.

When local timing is selected:

- the design may still run from local clocks;
- fake timestamp behavior is expected;
- downstream logic must not infer full endpoint readiness from local operation.

## Control-plane implication

The control/status wrapper should eventually expose a single neutral
software-visible concept for:

- clock source selected
- clock path locked
- endpoint ready
- timestamp valid

without changing the existing register ABI.

This readiness concept is also the timing-side prerequisite for
`frontend-boundary` to assert alignment validity.

## Verification posture

- formal at the control boundary only
- simulation for endpoint integration and clocking behavior
