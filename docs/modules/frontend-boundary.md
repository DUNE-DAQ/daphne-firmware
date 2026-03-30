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

## daphne-server alignment with this contract

The current `daphne-server` frontend contract matches this boundary at the
register and calibration level:

- the frontend control/status register map matches the RTL register ABI;
- the server drives delay, bitslip, trigger, and `DELAY_EN_VTC` through the
  expected frontend registers;
- the server's bitslip scan explicitly searches for `0x00FF00FF`, which is the
  32-bit software-visible form of the RTL's `0x00FF` 16-bit FCLK expectation.

What is still not explicit enough in software:

- the lightweight/default client configuration path does not document the exact
  semantic mapping of the `sb_first` boolean to the AFE's `LSB_MSB_FIRST` bit;
- therefore the software-side boolean naming should not yet be treated as the
  authoritative source for frontend bit-order semantics.

For now, the RTL remains the authoritative source for the required deserialize
assumption: `16-bit`, `LSb-first`.

## Boundary clarification

- The frontend deserializer boundary is `16-bit` wide.
- Downstream trigger or physics semantics may only consume `14 meaningful bits`
  later, but that is a different boundary and should not be conflated with the
  deserialize/alignment contract.

## Isolation objective

Make control-plane preconditions explicit before any trigger or downstream
logic relies on aligned AFE words.
