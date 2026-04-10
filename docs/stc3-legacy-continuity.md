# STC3 Legacy Continuity

## What We Can Claim

The current self-trigger channel path is not a documentation-only rewrite of a
private STC3 core.

- The legacy trigger algorithm is still imported through
  [self_trigger_xcorr_channel.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/subsystems/trigger/self_trigger_xcorr_channel.vhd),
  which instantiates the legacy `trig_xc`.
- The legacy peak-descriptor algorithm is still imported through
  [peak_descriptor_channel.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/subsystems/trigger/peak_descriptor_channel.vhd),
  which instantiates the legacy `Peak_Descriptor_Calculation`.
- The old STC3 packer/FIFO behavior from
  `/Users/marroyav/repo/Daphne_MEZZ/ip_repo/daphne3_ip/rtl/selftrig/stc3.vhd`
  was not discarded. It was split into the current
  [stc3_record_builder.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/subsystems/trigger/stc3_record_builder.vhd)
  while preserving the observable record contract:
  - `sample0` timestamp offset of `64`
  - fixed delayed waveform path of `288` cycles
  - first/last markers `0xBE` and `0xED`
  - 72-bit FWFT FIFO with depth `4096`
  - `prog_empty=220`, `prog_full=200`
  - same dense-pack word cadence (`d0`, `d5`, `d9`, `d14`, `d18`, `d23`, `d27`)

The repo now includes a static continuity check:

- [check_stc3_legacy_contract.sh](/Users/marroyav/repo/daphne-firmware/scripts/fusesoc/check_stc3_legacy_contract.sh)

That check verifies:

- the legacy stimulus file is still identical:
  - [stc3_testbench.txt](/Users/marroyav/repo/daphne-firmware/ip_repo/daphne_ip/sim/selftrig/stc3_testbench.txt)
- the current legacy testbench body still matches the old one except for the
  banner comment:
  - [stc3_testbench.vhd](/Users/marroyav/repo/daphne-firmware/ip_repo/daphne_ip/sim/selftrig/stc3_testbench.vhd)
- the current wrappers still import the same legacy trigger and descriptor
  algorithms
- the current record builder still matches the old STC3 packing/FIFO contract

## What Changed

The composition changed.

- The current
  [stc3.vhd](/Users/marroyav/repo/daphne-firmware/ip_repo/daphne_ip/rtl/selftrig/stc3.vhd)
  is no longer monolithic.
- It now delegates to:
  - [self_trigger_xcorr_channel.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/subsystems/trigger/self_trigger_xcorr_channel.vhd)
  - [peak_descriptor_channel.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/subsystems/trigger/peak_descriptor_channel.vhd)
  - [stc3_record_builder.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/subsystems/trigger/stc3_record_builder.vhd)
- The old `selftrig_core` composition was also refactored into the current
  [selftrig_core.vhd](/Users/marroyav/repo/daphne-firmware/ip_repo/daphne_ip/rtl/selftrig/selftrig_core.vhd),
  which now owns the former bridge logic directly

So the correct claim is:

- the core imported trigger and descriptor algorithms are preserved
- the outer STC3/self-trigger composition was refactored

## What We Still Cannot Claim

We still do not have a completed cycle-accurate A/B proof that the current and
legacy STC3 implementations produce identical output traces for all samples.

The missing proof is dynamic, not static:

- run the same `stc3_testbench.txt` stimulus against both repos
- record `ready`, `dout`, `record_count`, `full_count`, `busy_count`, `TCount`,
  `PCount`, and `trigger_output`
- compare traces cycle-by-cycle

That comparison needs a Vivado host with XSIM (or an equivalent simulator setup)
because both the old and current STC3 paths still depend on Xilinx `xpm` FIFO
models.
