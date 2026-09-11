# Four-SFP fixed-512 self-trigger readout

The K26 board target enables four 10 Gb/s Hermes links. Each channel retains its
independent 2048-sample history ring, four-entry frame queue and 32-slot packet
store. The on-wire DAPHNE record remains 960 bytes: 512 14-bit ADC samples and the
existing eight 64-bit header/descriptor words. Continuation timestamps and sample
boundaries are unchanged.

| SFP | Physical channels | Readout lanes | GT site | Default source IP | Default source MAC |
|---|---|---|---|---|---|
|0|0–9|0,1|GTHE4_CHANNEL_X0Y4|192.168.0.100|DE:AD:BE:EF:CA:FE|
|1|10–19|2,3|GTHE4_CHANNEL_X0Y5|192.168.0.101|DE:AD:BE:EF:CA:FF|
|2|20–29|4,5|GTHE4_CHANNEL_X0Y7|192.168.0.102|DE:AD:BE:EF:CB:00|
|3|30–39|6,7|GTHE4_CHANNEL_X0Y6|192.168.0.103|DE:AD:BE:EF:CB:01|

Every lane serves five consecutive channels, one complete packet per channel in
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
can lower the realized rate. One continuously active channel produces 0.9375 Gbit/s;
four continuously active channels per lane are sustainable at this boundary.
Five exceed its service rate, so all 40 continuously active channels still
produce more data (37.5 Gbit/s) than this readout can drain. A hot ten-channel group
cannot borrow an idle neighboring SFP's bandwidth.

These rates exclude Hermes envelopes, UDP/Ethernet overhead and network outages.
Four physical 10 Gb/s links do not establish lossless 40-channel continuous capture.

## Control and commissioning

The existing single AXI/IPbus transport window is retained. Hermes already has
selectors for its per-link transmit mux and UDP register banks; software must
configure and enable each of links 0–3. In the **IPbus word-address space**, write
the link number to 0x1842 to select its transmit-mux bank, and to 0x1844 to select
its UDP bank. Their adjacent status words 0x1843 and 0x1845 report four links.
These are IPbus protocol addresses, not direct AXI byte offsets. Existing link 0
settings and identity remain the default. Source 0/1 within a selected mux bank
correspond to that link's lower/upper five-channel group. Destination addressing
and transmit enables still require the existing Hermes configuration procedure.

Global QPLL reset is shared across the quad. Resetting that common clock can
interrupt all four links. No deployed hardware has been programmed by this work.

## Qualification

- Eight-lane concurrent packet integrity, round-robin order and admission gating:
  `python3 scripts/verification/run_multilane_readout_tests.py`.
- Board wrapper interfaces:
  `python3 scripts/verification/run_board_readout_elaboration.py`.
- Actual AMD asynchronous FIFO models, first-packet retention, blocked output,
  complete-packet credits and drain recovery:
  `scripts/remote/cooper_hermes_admission_sim.sh SOURCE NEW_SIM_DIRECTORY`.
- The simulator's `results/four_sfp512` study compares the two- and eight-lane
  service schedules on identical ADC/candidate traces. It measures the internal
  packet readout boundary with available transport credits.

Full-device resource fit, routed timing/DRC and packaged programming artifacts
remain required before hardware qualification. Simulation success alone does not
establish those results.
