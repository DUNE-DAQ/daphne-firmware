# Second candidate control CDC evidence (2026-09-14)

This evidence accompanies the changes after `5e86a75`; it does not establish
full-board timing or CDC closure. The individual JSON summaries record frozen
source hashes, tool commands, clocks, and pass/fail outcomes. The matching
logs are copied here; working directories under `build/` also retain the
frozen source files and simulator output.

| Check | Result | Evidence |
| --- | --- | --- |
| Self-trigger counter read, GHDL 32 and 40 channels | PASS | [local summary](counter-local/summary.json), [log](counter-local/test.log) |
| Same counter read with Vivado 2026.1 real XPM | PASS | [vendor summary](counter-vendor/summary.json), [log](counter-vendor/test.log) |
| PDTS endpoint CDC and core with real XPM | PASS | [endpoint summary](endpoint-vendor/summary.json), [log](endpoint-vendor/test.log) |
| Original packet parser negative control | Fails at live-address change as expected | [negative summary](endpoint-negative/summary.json), [log](endpoint-negative/test.log) |
| 40-channel counter register bank out-of-context synthesis | PASS, 0 critical warnings, 7199 LUT, 2505 FF, setup WNS +1.700 ns | [configuration](counter-ooc/run-configuration.txt), [utilization](counter-ooc/utilization.rpt), [timing](counter-ooc/timing_summary.rpt), [log](counter-ooc/vivado.log) |

The counter tests exercise all nine counter types at the first and final
channel, coherent 64-bit low/high pairs across a carry, read-response
backpressure, queued addresses, stopped acquisition clock with AXI timeout,
late-response isolation, and AXI reset during a transfer. The endpoint tests
exercise unrelated and stopped clocks, reset while the recovered clock is
stopped, AXI address/status transfers, packet-address changes, and admission
after address validity. The endpoint core uses the actual encoded idle
transmitter; MMCM/CDR lock and optical recovery are represented by clock and
LOCKED stimuli, not a physical optical model.

The main endpoint regression is reproducible with:

```sh
python scripts/verification/run_pdts_control_cdc_test.py --output build/pdts-control-cdc-review
```

The counter regression is reproducible with:

```sh
python scripts/verification/run_selftrigger_counter_cdc_test.py \
  --output build/selftrigger-counter-cdc-review --vendor "${XILINX_VIVADO:?}"
```

Each AXI counter read snapshots one selected 64-bit value in the acquisition
domain; a low/high pair shares that snapshot. Different counters can be read
at different epochs. Cross-counter accounting at one epoch would require
acquisition quiescence or an explicit aggregate snapshot interface.

The out-of-context counter result uses 10 ns AXI and 16 ns acquisition clocks
but has no board placement or real clock insertion delay. It checks synthesis
feasibility and area only; the next full-board build must validate integration
and timing. The first OOC attempt used an unsupported Tcl `if` in XDC, so its
timing report was discarded and the script was corrected before this run.
