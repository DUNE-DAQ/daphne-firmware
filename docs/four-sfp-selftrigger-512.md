# Four-SFP fixed-512 self-trigger readout

The K26 board target enables four 10 Gb/s Hermes links and 32 active self-trigger
channels. Each active channel retains its
independent 2048-sample history ring, four-entry frame queue and 32-slot packet
store. The on-wire DAPHNE record remains 960 bytes: 512 14-bit ADC samples and the
existing eight 64-bit header/descriptor words. Continuation timestamps and sample
boundaries are unchanged.

| SFP | Physical channels | Readout lanes | GT site | Default source IP | Default source MAC |
|---|---|---|---|---|---|
|0|0–7|0,1|GTHE4_CHANNEL_X0Y4|192.168.0.100|DE:AD:BE:EF:CA:FE|
|1|8–15|2,3|GTHE4_CHANNEL_X0Y5|192.168.0.101|DE:AD:BE:EF:CA:FF|
|2|16–23|4,5|GTHE4_CHANNEL_X0Y7|192.168.0.102|DE:AD:BE:EF:CB:00|
|3|24–31|6,7|GTHE4_CHANNEL_X0Y6|192.168.0.103|DE:AD:BE:EF:CB:01|

Every lane serves four consecutive channels, one complete packet per channel in
round-robin order. All links use source UDP port 0x1234. The documented carrier
wiring crosses the GT channel order of SFP2 and SFP3. One shared GT common block
and 156.25 MHz reference serve the quad; the timing SFP uses its existing separate
fabric interface.

## Congestion and memory

A lane starts a packet only when its Hermes input FIFO advertises enough room
for the complete 120-word record. It then sends the entire record without pausing.
Hermes input data FIFOs are 512 words per source; programmable-full thresholds
reserve 120 words plus four pipeline words, and the length FIFO reserves spare
entries. Until admission, ownership stays in the channel packet store. A blocked
lane does not block any other lane. Once a channel's packet credits run out, new
fragments are rejected whole and existing acquisition loss counters advance.

The fixed-packet mode waits for an idle source boundary after a FIFO reset and
accepts the first subsequent complete packet. Historical generic streaming users
retain the previous default behavior. Link or software resets can flush packets
already transferred to Hermes; acquisition counters describe the packet builder,
not a guarantee of end-to-end delivery during link resets.

At 62.5 MHz, 120 data clocks plus scan/pause give a maximum 3.9344 Gbit/s of DAPHNE
record words per lane, 31.4754 Gbit/s across eight lanes. Scanning inactive channels
can lower the realized rate. One continuously active channel produces 0.9375 Gbit/s.
The four active channels assigned to each lane request 3.75 Gbit/s, below the
3.9344 Gbit/s lane boundary. All 32 continuously active channels request
30.0 Gbit/s before network overhead. Traffic on one SFP cannot borrow an idle
neighboring SFP's bandwidth.

These rates exclude Hermes envelopes, UDP/Ethernet overhead and network outages.
Actual routed timing and four-link transport qualification remain necessary before
claiming lossless continuous capture.

## Measured resource baseline

The latest completed full-device measurement is the one-link `0403d97`
post-synthesis checkpoint produced by Vivado 2026.1 build 6511674. It is a
reference for the shared acquisition logic and one Hermes link; it is not the
four-link utilization result.

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| Total CLB LUTs | 109136 | 117120 | 93.18% |
| LUTs as logic | 99349 | 117120 | 84.83% |
| LUTs as memory | 9787 | 57600 | 16.99% |
| CLB registers | 83450 | 234240 | 35.63% |
| BRAM tiles | 83.5 | 144 | 57.99% |
| URAM | 40 | 64 | 62.50% |
| DSP blocks | 1080 | 1248 | 86.54% |

The measured hierarchy attributes 70206 LUTs to the forty packet builders
(including 12940 LUTs in their descriptor children), 15076 LUTs to the five
trigger banks, 7226 LUTs to the self-trigger register bank, and 8663 LUTs to
the one-link Hermes transport including shared IPbus control. Parent and child
rows overlap and must not be added together. The complete design has 7984 LUTs
of synthesis headroom before adding the remaining links.

The `9ba0bd0` clean build measures the superseded 40-channel/four-link design.
The next clean build with 32 active channels is the authoritative fit test and
must replace projections based on either earlier hierarchy before claiming fit.

## Control and commissioning

The existing single AXI/IPbus transport window is retained. Hermes already has
selectors for its per-link transmit mux and UDP register banks; software must
configure and enable each of links 0–3. In the **IPbus word-address space**, write
the link number to 0x1842 to select its transmit-mux bank, and to 0x1844 to select
its UDP bank. Their adjacent status words 0x1843 and 0x1845 report four links.
These are IPbus protocol addresses, not direct AXI byte offsets. Existing link 0
settings and identity remain the default. Source 0/1 within a selected mux bank
correspond to that link's lower/upper four-channel group. Destination addressing
and transmit enables still require the existing Hermes configuration procedure.

Global QPLL reset is shared across the quad. Resetting that common clock can
interrupt all four links. No deployed hardware has been programmed by this work.

## Qualification

- Eight-lane concurrent packet integrity, round-robin order and admission gating:
  `python3 scripts/verification/run_multilane_readout_tests.py`.
- Board wrapper interfaces:
  `python3 scripts/verification/run_board_readout_elaboration.py`.
- Per-link TX/RX clocks, reset release and link-status isolation, with vendor
  transceivers replaced by controllable boundary models:
  `python3 scripts/verification/run_hermes_phy_clock_reset_test.py`.
- Actual AMD asynchronous FIFO models, first-packet retention, blocked output,
  complete-packet credits and drain recovery:
  `scripts/remote/cooper_hermes_admission_sim.sh SOURCE NEW_SIM_DIRECTORY`.
- The simulator's `results/four_sfp512` study compares the two- and eight-lane
  service schedules on identical ADC/candidate traces. It measures the internal
  packet readout boundary with available transport credits.

Full-device resource fit, routed timing/DRC and packaged programming artifacts
remain required before hardware qualification. Simulation success alone does not
establish those results.

### Clock coverage evidence and final audit

The shared Ethernet reference requires a primary `eth_refclk` constraint of
6.400 ns. In Vivado 2026.1 build 6511674, applying this constraint to the earlier
single-link `355376f` synthesis checkpoint reduced `check_timing` clockless pins
from 9506 to eight and unconstrained internal endpoints from 21528 to 97.
This establishes propagation of the reference clock in that checkpoint; it does
not establish timing closure for the four-link candidate.

The eight remaining clockless pins are unused PS8 EMIO outputs:
`EMIOENET[0-3]MDIOMDC`, `EMIOSDIO[0-1]CLKOUT` and `EMIOSPI[0-1]SCLKO`.
The other 97 endpoints belong to the old `gen_udp_clk_fifos.udp_out_fifo_inst`
read-side logic, whose clock was tied low. The four-link source disables that
redundant FIFO generate and supplies each link's RX clock to the receive interface.
These findings explain the old checkpoint; the final implementation must confirm
that the obsolete FIFO endpoints are absent and inspect any remaining warnings.

After routing, collect the actual candidate's reports with:

```sh
vivado -mode batch -source scripts/verification/audit_routed_checkpoint.tcl \
  -tclargs ROUTED_CHECKPOINT NEW_REPORT_DIRECTORY
```

Review route status, setup/hold timing, bus skew, clock coverage, CDC, exception
coverage, methodology and DRC reports against the implemented interfaces. The collector's
completion marker means reports were generated, not that qualification passed.
