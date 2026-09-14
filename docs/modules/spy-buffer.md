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

That gating rule should live at the neutral spy-buffer boundary rather than in
the imported memory implementation itself.

## Runtime trigger control

The K26C board path exposes a software-controlled trigger selector and inhibit
at `FRONT_END_S_AXI + 0x34` (`0x8800_0034`):

- bits `[1:0] = 00`: software trigger writes at `0x8800_0008`
- bits `[1:0] = 01`: external trigger input
- bits `[1:0] = 10`: timing trigger whose code matches the configured ad-hoc code
- bits `[1:0] = 11`: legacy OR of all three sources
- bit `[2] = 1`: inhibit every trigger before it reaches the spy buffers

The reset value is `0x3`, preserving the legacy OR behavior with inhibit
disabled. Selector and inhibit are transferred together into the acquisition
clock domain and applied at the board-local spy-trigger boundary.

For a source change that must not capture an intermediate waveform:

1. set bit 2 while retaining the current selector;
2. wait at least five 62.5 MHz acquisition clocks (80 ns);
3. write the desired selector with bit 2 still set;
4. wait another five acquisition clocks, then clear bit 2.

Normal Linux MMIO operations will generally exceed these propagation delays,
but the explicit waits matter for tightly timed bare-metal sequences.
