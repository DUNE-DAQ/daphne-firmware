# Two-link 256/5 self-trigger candidate

Derived from production candidate e49c4aae. This branch implements 32 active
channels on two DAQ SFPs, preserving 256 samples and five descriptors in each
63-word (504-byte) frame. It is a separate build configuration, not a runtime
link-count switch or a qualified hardware release.

| SFP | Channels | Readout lanes | Channels per lane | GT site |
|---|---|---|---|---|
| 0 | 0–15 | 0, 1 | 8 | GTHE4_CHANNEL_X0Y4 |
| 1 | 16–31 | 2, 3 | 8 | GTHE4_CHANNEL_X0Y5 |

SFP2 and SFP3 have no instantiated PHY or RX/TX data ports. Their physical
TX_DISABLE controls are retained and driven high. One GT common and the
existing 156.25-MHz reference serve the two active PHYs. The timing SFP is
unchanged. Internal eight-lane wrapper buses retain their widths; unused
lanes are tied idle and cannot acquire admission credits.

## Invariants

- Acquisition/readout stays at 62.5 MHz; grouped builder clocks and their CDC
  are unchanged. Hermes uses the existing asynchronous 512-word source FIFOs
  to its TX domain. No new clock domain or payload CDC is introduced.
- Each lane admits a complete 63-word frame only with packet_ready. Once
  admitted, all words drain without mid-frame stalls. GAPLESS_G stays true.
- The grouped ring, packet stores, descriptors and continuation policy are
  unchanged. Pending frames remain owned by the channel until admission.
- Public channel/register interfaces retain their original widths and maps;
  channels 32–39 remain inactive. Hermes exposes two physical link instances.
- The frame/descriptor byte layout remains compatible. Channel-to-SFP mapping
  changes and must be reflected in DAQ configuration before deployment.

## Capacity and loss

Two sources per link provide at most 8 Gbit/s of DAPHNE frame words, or
16 Gbit/s across the board, before transport overhead/stalls. Continuous
32-channel coverage requires 31.5 Gbit/s. This variant therefore intentionally
trades output capacity for fewer links; it cannot promise lossless continuous
capture. Packet-ready backpressure eventually exhausts channel packet credits;
existing whole-frame rejection counters then report acquisition loss.

Tests cover 32-channel routing with four lanes, round-robin service, admission
withdrawal, contiguous admitted frames, actual package staging and board
elaboration. Vendor XPM admission simulation uses eight channels per lane,
including a stalled sink, reset during a frame and recovery. Local portable
models, vendor simulation, routed timing and hardware transport are distinct
qualification steps; consult the task handoff for completed evidence.
