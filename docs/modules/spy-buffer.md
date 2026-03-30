# Spy Buffer

## Scope

Neutral boundary for:

- capture enable
- spy memory path
- software-visible debug observation

## Imported sources currently involved

- `rtl/spy/spybuff.vhd`
- `rtl/spy/spybuffers.vhd`
- `rtl/spy/spyram.vhd`
- `rtl/misc/outspybuff.vhd`

## Isolation objective

Keep spy capture as a separate module while making its readiness dependencies
explicit instead of implicit.

## Readiness dependency

Spy capture should only be considered meaningful when:

- the required analog configuration has been applied;
- the timing subsystem is ready enough for frontend clocks to be trusted;
- frontend alignment has promoted the input stream to valid.

The neutral enable rule for this module should be:

- `spy_enable = config_ready and timing_ready and alignment_ready`
