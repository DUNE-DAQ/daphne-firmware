# Grouped Hermes Transport Plan

This branch is the first clean draft of a replacement data architecture for the
self-trigger export path between the AFEs and the 10Gb transport.

It starts from the only qualified hardware line we have:

- routed-clean baseline: `a389fcd`
- current `main` tip carrying that line plus packaging fixes: `eb5f971`

The branch does **not** modify the qualified build path yet. It captures the
architecture, the resource budget assumptions, and the first reusable wrapper
needed to measure the transport-side delta before touching the live top level.

## Problem Restatement

The current repo work established three facts:

1. `40` per-channel packet producers are too expensive.
2. `5` per-AFE packet producers are better for area, but too coarse for dead
   time because channels block behind a shared serializer.
3. Trigger acceptance must not be tied directly to transport FIFO watermarks.

That means the right design axis is:

- keep capture local
- move packetization downstream
- arbitrate compact descriptors, not packet payloads

## Target Architecture

The target architecture is:

- `40` channel-local sample rings
- `40` channel-local compact descriptor queues
- grouped packet sources feeding Hermes directly
- fixed Ethernet-visible packet format kept stable initially

The first serious grouping target is:

- `4` channels per grouped source
- `10` real grouped sources into Hermes
- `1` physical 10Gb link initially

This avoids both bad extremes:

- not `40` fully replicated packet producers
- not `5` overly contended AFE serializers

## Dominant Data Structures

Per channel:

- circular sample ring
- peak-descriptor side storage
- compact frame descriptor queue

Per grouped source:

- scheduler over a small set of channel descriptor queues
- late packet assembler

At Hermes:

- source input FIFOs owned by the existing Deimos transport
- no extra fake `40`-slot shim

## Descriptor Contract

The design intent is that the queued object is a descriptor, not a packet.

Minimal descriptor fields:

- `channel_id`
- `source_group_id`
- `start_ptr`
- `sample0_ts`
- `trigger_offset`
- `frame_block_count`
- `baseline`
- `threshold_lsb`
- `trigger_sample`
- `continuation`
- `peak_desc_first`
- `peak_desc_count`

This keeps scheduling metadata compact and avoids moving waveform payload
through intermediate packet FIFOs.

## What Must Stay Stable Initially

The first architecture pass should preserve:

- one physical Hermes/10Gb path
- fixed `512`-sample waveform records
- fixed Ethernet-visible packet size
- existing software-visible MAC/IP ownership

That gives a meaningful hardware/resource comparison without simultaneously
changing downstream packet semantics.

## Resource Budget From The Current Repo

The repo-owned successful line is still anchored on `main` at the routed-clean
`a389fcd` baseline.

Useful budget reference from the study repo:

- `a389fcd` baseline:
  - `84,532` CLB LUTs
  - `99` BRAM tiles
  - `40` URAM
  - `1240` DSPs
- `27a4ca9` ring2k comparison point:
  - `105,404` CLB LUTs
  - `139` BRAM tiles
  - `40` URAM
  - `1200` DSPs

The important transport-side observation is:

- Hermes `N_SRC` is already generic internally
- but each Hermes source instantiates its own `tx_mux_ibuf`
- each `tx_mux_ibuf` contains a `2048 x 64` async block-RAM FIFO

So increasing Hermes from `2` to `5` sources is not a cheap mux-only change.
It is approximately:

- `+3` extra Hermes source buffers
- about `+12` BRAM tiles from those FIFOs alone
- modest extra LUT/FF for arbitration and control
- essentially no DSP/URAM delta

That still looks feasible against the `main` baseline. It is **not** in the
same risk class as the failed `coal-tail512` architecture.

## Implementation Order

Phase 0:

- keep the qualified top untouched
- add a generic grouped-Hermes wrapper
- allow out-of-context measurement of `N_SRC = 5` and later `N_SRC = 10`

Phase 1:

- generalize the Hermes wrapper from the current fixed `2` sources
- feed Hermes with real grouped sources
- no fake `40`-slot shim

Phase 2:

- replace per-channel packet builders with channel-local rings plus descriptor
  queues
- move packet assembly into grouped sources

Phase 3:

- sweep grouping factors in RTL and synth:
  - `8` channels/source
  - `4` channels/source
  - `2` channels/source

Decision rule:

- choose the smallest grouping factor that materially reduces area without
  recreating the `40`-producer replication problem

## What This Branch Adds

This branch adds:

- this plan
- a generic grouped-Hermes readout wrapper draft
- shared transport-side draft types for grouped-source work

It intentionally does **not** yet:

- modify the qualified `main` build path
- widen the live K26 wrapper to more Hermes sources
- replace the live self-trigger datapath

That is deliberate. The first technical question is resource viability of the
Hermes-side `N_SRC` widening, and this branch provides the clean seam for that
measurement.
