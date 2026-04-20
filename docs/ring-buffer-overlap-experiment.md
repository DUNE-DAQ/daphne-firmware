# Ring Buffer Overlap Experiment

This branch replaces the per-channel live delayed-stream frame builder with a
per-channel sample ring buffer and a small pending-frame queue.

Current scope:

- fixed frame length: `512` samples
- fixed pretrigger: `64` samples
- per-channel sample storage: `4096 x 14` ring buffer
- pending-frame queue depth: `4`
- frame serialization happens after the waveform window is fully mature

## Overlap Control

This first experimental implementation reuses the existing `signal_delay`
register path as a waveform-overlap control.

- configured overlap = `16 * signal_delay`
- overlap is clamped to `frame_length - 1`
- minimum accepted trigger spacing = `frame_length - overlap`

Examples:

- `signal_delay = 0` -> no overlap, minimum spacing `512`
- `signal_delay = 4` -> `64` samples overlap, minimum spacing `448`
- `signal_delay = 16` -> `256` samples overlap, minimum spacing `256`

This reuse is deliberate for hardware testing on the existing control ABI. It
is not the final user-facing programming model.

## Descriptor Metadata Caveat

Waveform capture is the priority of this branch.

The peak-descriptor calculator still has a single active metadata context per
channel. Therefore:

- waveform windows are expected to remain correct
- frame timestamps and sample-start headers remain frame-local
- trailer metadata is only fully trustworthy in the non-overlap case

When overlap is enabled, the waveform frames can still be used to study DAQ
behavior and overlap tolerance, but the per-frame trailer descriptors should be
treated as experimental until the descriptor path is redesigned for multiple
simultaneous frame contexts.
