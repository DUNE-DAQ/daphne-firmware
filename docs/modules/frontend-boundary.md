# Frontend Boundary

## Scope

Neutral boundary for:

- AFE alignment control
- deserialize and bit-order assumptions
- IDELAY and bitslip programming
- explicit promotion of frontend data from "electrically present" to
  "contract-valid for downstream logic"

## Imported sources currently involved

- `rtl/frontend/front_end.vhd`
- `rtl/frontend/fe_axi.vhd`
- `rtl/frontend/febit3.vhd`

## Preconditions that must be explicit

These are already present in the imported RTL comments and behavior and should
become first-class contract items:

- The AFE stream must be configured for `16-bit` transmission mode.
- The serialized word order must be `LSb first`.
- IDELAY tap values are only valid to load while `idelay_en_vtc = 0`.
- Alignment should not be considered valid until `idelayctrl_ready = 1`.
- Bitslip calibration is targeting the frontend training pattern `0x00FF` on
  the 16-bit FCLK word.

## Boundary clarification

- The frontend deserializer boundary is `16-bit` wide.
- Downstream trigger or physics semantics may only consume `14 meaningful bits`
  later, but that is a different boundary and should not be conflated with the
  deserialize/alignment contract.

## Isolation objective

Make control-plane preconditions explicit before any trigger or downstream
logic relies on aligned AFE words.
