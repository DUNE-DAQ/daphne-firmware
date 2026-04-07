# AFE Timing Architecture

## Scope

This note captures the current timing ownership for the AFE DDR receive path and
the intended cleanup steps during the FuseSoC/composable migration.

The main goal is stable readout across boards of the same hardware/model/version
without pretending that static timing alone can replace runtime alignment.

## Current Receive Path

The live AFE capture path still lands in the legacy frontend implementation:

- `ip_repo/daphne_ip/rtl/daphne_selftrigger_top.vhd`
- `ip_repo/daphne_ip/rtl/frontend/front_end.vhd`
- `ip_repo/daphne_ip/rtl/frontend/febit3.vhd`

For each LVDS bit lane, `febit3` performs:

1. `IBUFDS`
2. `IDELAYE3`
3. `ISERDESE3`
4. fabric bitslip / word assembly

The lane depends on three aligned clocks:

- `clock` at the AFE word rate
- `clk500` at the serial bit rate
- `clk125` as the divided byte clock

`frontend_common.vhd` now captures the shared clocking/control ownership that
was previously buried inside the legacy frontend:

- forwarded AFE output clock generation
- shared `IDELAYCTRL`
- pulse/resync glue for trigger and IDELAY load controls

## Static Timing vs Runtime Alignment

The repo needs both:

### Static timing

Static timing should guarantee that the FPGA-side source-synchronous capture
path is well constrained and that Vivado is not making unsafe assumptions.

This means:

- correct generated clocks
- correct source relationships for the AFE receive clocks
- clear async groups only where domains are truly unrelated
- no stale clock references in the XDC

### Runtime alignment

Runtime alignment is still required even on nominally identical boards.

This is owned by the FE alignment/control path:

- IDELAY tap programming
- IDELAY load pulses
- ISERDES/fabric bitslip state
- FCLK-based training/alignment policy

Today that ownership remains software-visible through `fe_axi.vhd`, with the
per-AFE state now factored into `frontend_register_bank.vhd`.

## Current Problems

The timing side is still weaker than it should be:

- `xilinx/daphne_selftrigger_pin_map.xdc` still carries stale commented timing
  baggage from older hierarchy names and experiments, even though the active
  AFE receive-clock model has been split out already.
- The legacy async clock-group section now uses guarded `get_clocks -quiet`
  lookups so stale names stop producing avoidable warnings, but that is only a
  containment step, not the final receive-path timing model.
- The static constraints for the AFE capture path are not yet isolated into a
  dedicated, reviewable timing block.
- Some frontend ownership is split between the legacy `front_end` and the newer
  isolated/frontend helper blocks, which makes it harder to reason about what
  changed in a given implementation.

## Near-Term Cleanup Plan

1. Keep the live capture datapath stable while board debugging is active.
   Do not rewrite `febit3` or the legacy `front_end` path just to clean up
   naming.

2. Keep the AFE capture timing intent in a dedicated XDC file.
   The content should cover:
   - receive/generated clocks for the frontend path
   - source-synchronous relationships around `clock`, `clk500`, and `clk125`
   - the real async boundaries only
   - the repo now carries `xilinx/afe_capture_timing_scaffold.xdc` as the
     design note and `xilinx/afe_capture_timing.xdc` as the active, required
     split constraint file wired through the board manifest
   - active hierarchy roots such as the timing endpoint path should come from
     the board manifest/build defaults instead of being hardcoded inside the
     XDC

3. Remove or quarantine stale/generated-clock lines that no longer match the
   synthesized hierarchy from the board pinmap XDC so the split file is the
   sole active owner of the AFE receive-clock family.

4. Keep runtime alignment explicit.
   Static constraints should not try to encode away the need for IDELAY/bitslip
   training.

5. Once the composable frontend shell becomes the real synth path, move timing
   ownership alongside it so `frontend_common` becomes the natural home for the
   shared capture timing contract.

## Migration Guidance

For now, the safest architecture split is:

- legacy `front_end` remains the live capture datapath
- refactored frontend register ownership remains live through `fe_axi`
- composable/frontend shells remain the target architecture for eventual
  replacement

That means the next AFE timing work should be constraint cleanup and explicit
ownership documentation, not another large RTL rewrite.

## Acceptance Criteria

For a board-family-stable AFE timing architecture, we should eventually have:

- one reproducible static timing story for the receive path
- no stale XDC references/warnings in the frontend clocking section
- runtime alignment that still converges board-to-board
- a clear split between static timing responsibility and software-driven deskew
- the composable frontend shell ready to inherit the same timing contract when
  it becomes the real synth top
