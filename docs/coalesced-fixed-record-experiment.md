# Coalesced Fixed-Record Experiment

Branch: `marroyav/coal`

## Goal

Reduce dead time without changing the Ethernet-visible record size.

This branch keeps the current downstream packet contract:

- one emitted record is still `512` samples
- one emitted record is still `120` 72-bit words
- the mux/readout path still sees fixed-size records terminated by the normal `ED` marker

## HDL Strategy

The builder no longer treats "new trigger" as equivalent to "allocate a new overlapping record".

Instead:

- if a trigger is already covered by the most recently accepted waveform interval, no new record is emitted
- if a trigger would naturally open a record that overlaps the previous accepted coverage window, the new record start is clipped to `previous_end + 1`
- the trigger position inside the emitted record is carried explicitly as a `10`-bit `trigger_offset`

That preserves fixed-size records while enforcing non-overlap.

## Metadata Change

Header word 1 is repacked to carry:

- channel id
- version
- `trigger_offset`
- baseline
- threshold LSB
- trigger sample

This uses the old padding bits rather than growing the record.

The peak-descriptor path now uses the explicit trigger offset instead of the old hardcoded `+64` assumption when computing `Time_Start`.

## Current Limitation

This is still a fixed-record experiment, not a full interval-merging serializer.

So:

- waveform coverage is coalesced at acceptance time
- covered triggers do not allocate new records
- per-record peak-descriptor metadata still corresponds only to emitted records, not to every covered trigger

That is intentional for the first HDL step. It lets us test the dead-time benefit of non-overlap while preserving the downstream transport contract.
