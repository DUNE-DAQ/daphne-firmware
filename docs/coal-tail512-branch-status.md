# Coal Tail512 Branch Status

Branch:

- `marroyav/coal-tail512`

## Scope

This branch is the current fixed-record continuation path for the self-trigger
builder:

- `2k` ring per channel
- queue depth `4`
- fixed `512`-sample records
- fixed `120` 72-bit words per record
- no overlap
- chained continuation through `frame_extend_i`

The Ethernet-visible record contract is unchanged.

## Strategy Matrix

### 1. FIFO consolidation / removal

Implemented here as a contract cleanup rather than wholesale FIFO deletion.

Files:

- [stc3_record_builder.vhd](/Users/marroyav/repo/daphne-firmware-bram/rtl/isolated/subsystems/trigger/stc3_record_builder.vhd)
- [two_lane_readout_mux.vhd](/Users/marroyav/repo/daphne-firmware-bram/rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd)

What changed:

- the builder no longer uses FIFO programmable empty/full thresholds as the
  trigger-admission contract
- packet availability is tracked explicitly with `fifo_packet_count_s`
- serializer start now waits for explicit whole-packet FIFO space
- trigger admission is now decoupled from output FIFO fullness and uses the
  local frame queue as the real backpressure boundary
- the per-channel output FIFO was reduced to a small block-RAM staging buffer
  sized for fixed-packet serialization rather than a deep local store
- the mux no longer inserts an extra bubble after `ED`

What did not change:

- the per-channel output FIFO still exists as a per-channel staging buffer
- there is still one FIFO per channel before lane arbitration

### 2. Systematic clock-enable cleanup

Implemented in the current branch where it was low-risk and local.

Files:

- [two_lane_readout_mux.vhd](/Users/marroyav/repo/daphne-firmware-bram/rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd)
- [stc3_record_builder.vhd](/Users/marroyav/repo/daphne-firmware-bram/rtl/isolated/subsystems/trigger/stc3_record_builder.vhd)

What changed:

- mux payload registers update only on valid dumped words
- idle cycles no longer rewrite zero payloads
- detailed reject counters are no longer forced into the hardware instantiations
- the old trigger-count FSM was reduced to a simple edge detector

What did not change:

- there is no repo-wide CE-domain pass yet
- the sample ring still writes continuously while the channel is live

### 3. FuseSoC specialization cleanup

Implemented.

Files:

- [k26c-composable-platform.core](/Users/marroyav/repo/daphne-firmware-bram/cores/platform/k26c-composable-platform.core)
- [board_env.sh](/Users/marroyav/repo/daphne-firmware-bram/scripts/fusesoc/board_env.sh)
- [build_coal_tail512.sh](/Users/marroyav/repo/daphne-firmware-bram/scripts/fusesoc/build_coal_tail512.sh)

What changed:

- dedicated platform target `impl_coal_tail512`
- dedicated wrapper script to build the specialized branch target directly

### 4. Formal-driven logic removal

Implemented for the arithmetic AXI decode path.

Files:

- [selftrigger_register_bank.vhd](/Users/marroyav/repo/daphne-firmware-bram/rtl/isolated/subsystems/control/selftrigger_register_bank.vhd)
- [selftrigger_register_bank_formal.vhd](/Users/marroyav/repo/daphne-firmware-bram/formal/vhdl/selftrigger_register_bank_formal.vhd)
- [selftrigger_register_bank_contract.sby](/Users/marroyav/repo/daphne-firmware-bram/formal/sby/selftrigger_register_bank_contract.sby)
- [run_coal_tail512_checks.sh](/Users/marroyav/repo/daphne-firmware-bram/scripts/formal/run_coal_tail512_checks.sh)

What changed:

- the arithmetic register-bank decode has a dedicated proof entry point
- dead spacing-reject baggage was removed from the coal builder path after the
  branch proved it no longer contributes behavior
- the two-lane mux now has a dedicated contract proof entry point so the
  simplified fixed-record readout seam is formally checked

### 5. RTL-wrapping simulation instead of behavioral mirroring

Implemented in the mezzanine simulation repo.

Files:

- [multichannel_deadtime_tb_ring.vhd](/Users/marroyav/repo/daphne_mezz_xc_sim/hdl/multichannel_deadtime_tb_ring.vhd)
- [run_multichannel_deadtime_tb.py](/Users/marroyav/repo/daphne_mezz_xc_sim/scripts/run_multichannel_deadtime_tb.py)
- [run_coal_tail512_hdl_study.py](/Users/marroyav/repo/daphne_mezz_xc_sim/scripts/run_coal_tail512_hdl_study.py)

What changed:

- the HDL bench wraps the live `stc3_record_builder` plus `two_lane_readout_mux`
- the bench now drives `frame_extend_i`
- the bench enables detailed reject counters only in simulation

### 6. Broad contract cleanup across trigger / descriptor / readout seams

Implemented partially in the current fixed-record architecture.

Files:

- [stc3_record_builder.vhd](/Users/marroyav/repo/daphne-firmware-bram/rtl/isolated/subsystems/trigger/stc3_record_builder.vhd)
- [afe_selftrigger_island.vhd](/Users/marroyav/repo/daphne-firmware-bram/rtl/isolated/subsystems/trigger/afe_selftrigger_island.vhd)
- [stc3.vhd](/Users/marroyav/repo/daphne-firmware-bram/ip_repo/daphne_ip/rtl/selftrig/stc3.vhd)

What changed:

- trigger acceptance is decoupled from FIFO `prog_empty/prog_full`
- continuation requests travel explicitly via `frame_extend_i`
- descriptor alignment travels explicitly via `frame_trigger_offset_o`
- hardware instantiations explicitly disable detailed reject-counter baggage
- the fixed-record serializer only starts when a whole packet fits in the local
  output buffer

What did not change:

- the downstream record size is still fixed
- there is not yet a true interval-merging serializer or variable-length
  transport contract

## Commands

Build the specialized branch target:

```sh
./scripts/fusesoc/build_coal_tail512.sh
```

Synth only:

```sh
export DAPHNE_STOP_AFTER_SYNTH=1
./scripts/fusesoc/build_coal_tail512.sh
```

Run the branch-specific formal checks:

```sh
./scripts/formal/run_coal_tail512_checks.sh
```

## Remaining Work

Not complete on this branch:

- true FIFO removal or merging across channel boundaries
- a repo-wide CE cleanup
- a variable-length coalesced packet assembler
- downstream contract changes for non-overlap interval transport

That is intentional. This branch is the synthable fixed-record continuation
baseline, not the final interval-transport architecture.
