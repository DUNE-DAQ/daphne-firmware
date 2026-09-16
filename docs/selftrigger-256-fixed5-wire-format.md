# 256-sample fixed-five fragment format

The grouped builder emits format nibble **4**, independently of the control
register ABI version. Each fragment is exactly63 little-endian64-bit words
(504bytes): two common metadata words, five fixed descriptor slots, and56
waveform words. The waveform is256 consecutive unsigned14-bit ADC samples,
sample0 in payload bits13:0. No descriptor count changes the record length.

Word0 is the64-bit timestamp of sample0, in ADC sample-clock ticks, modulo2^64.
The initial fragment starts64 samples before its trigger timestamp. Subsequent
fragments advance sample0 by256 with no repeated pretrigger region.

Word1 retains the common header layout:

| Bits | Meaning |
| --- | --- |
| 63:56 | Channel identifier |
| 55:52 | Packet format4 |
| 51 | Continuation fragment |
| 50 | Fragment-local descriptor semantics, always1 |
| 49 | More than five excursions; earliest five retained |
| 48 | Reserved, zero |
| 47:46 | Calibration tag, unchanged |
| 45:32 | Trigger baseline in the existing polarity-normalized representation |
| 31:30 | Reserved, zero |
| 29:16 | Low14 bits of correlation threshold |
| 15:14 | Reserved, zero |
| 13:0 | Trigger sample metadata |

Words2 through6 contain the earliest five excursions in sample order. Each
valid slot is one64-bit word:

| Bits | Meaning |
| --- | --- |
| 63:61 | Reserved, zero |
| 60 | Valid excursion |
| 59:52 | Start sample index0..255 |
| 51:44 | Earliest maximum offset relative to excursion start,0..255 |
| 43:36 | Duration minus one, representing1..256 samples |
| 35:22 | Baseline-subtracted positive height,0..16383 |
| 21:0 | Sum of baseline-subtracted amplitudes over the excursion |

An absent slot is all zero and has validity0. Excursions contain consecutive
amplitudes strictly greater than the activity threshold. Tied maxima retain
their earliest index. An excursion crossing a fragment boundary closes at255
and is independently described in the next fragment. The maximum possible
integral is256*16383=4194048, fitting22 bits without saturation. No separate
offset word or sentinel-valued offset field is present.

Internally, the first word carries markerBE and the last payload word carries
markerED in the extra8-bit memory sideband; those markers are not wire bytes.
The source publishes a packet only on the returned write to header word6,
after all56 payload words and seven metadata words have been written.

The ring remains2048 samples; packet RAM retains32 slots with128-word address
stride. Sample acquisition uses the ADC clock and the shared four-channel
builder uses312.5MHz with the existing handshake and asynchronous write FIFO.
The conservative512-ADC-clock service bound and64-sample retention margin are
retained. These are admission bounds, not the fragment length.

The447-sample posttrigger requirement remains independent of fragment size:
an accepted initial trigger requires coverage through trigger+447 inclusive.
With continuation enabled, even an immediately quiet event therefore normally
uses two256-sample fragments. Covered triggers extend that deadline.
The admission history retains the current and two preceding fragment starts,
so a447-clock delayed trigger is still recognized as covered on the256 grid.
Quiet qualification observes live ADC samples after admission; a tuple delivered
late can produce an additional fragment while its quiet interval is measured.
Continuation-disabled mode intentionally captures one fragment. Its overlap
request remains in16-sample units and saturates at240samples (minimum spacing16)
when a legacy delay setting requests overlap greater than or equal to256.

The native reference builder and descriptor calculator retain their default
512-sample format for historical regression. The grouped production serializer
explicitly selects256 samples and the compact codec; replay instantiates the
reference builder with its256-sample generic for independent comparison.
