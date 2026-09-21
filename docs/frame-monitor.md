# AFE alignment readback

K26C frontend base: `0x88000000`. Existing offsets are unchanged.

| Offset | Access | Meaning |
| --- | --- | --- |
| `0x38` | W | `0x100 \| afe` requests a snapshot; AFE 0..4 |
| `0x38` | R | upper 16 bits `0xAFE1`; bits 4:2 selected AFE, bit 1 valid, bit 0 busy |
| `0x3c` | R | two consecutive 16-bit lane-8 samples; earliest sample in low half |

Writes require all byte strobes. Invalid AFE and writes while busy are ignored.
A request clears valid/data immediately. Poll until busy=0 and valid=1 before
reading. A stopped capture clock leaves busy asserted; software must time out.
Reset cancels the request and clears valid. Wrappers not enabling the generic
return zero capability and retain the legacy register behavior.

The acquisition clock captures all five AFE frame lanes on two adjacent cycles.
A four-phase request/acknowledge handshake crosses to/from AXI using three-stage
control synchronizers. Held data crosses through two stages and stays unchanged
through acknowledgement. The AXI result is not overwritten until a new request.
Source reset asserts asynchronously and releases after two acquisition clocks.
`frontend_control_cdc.tcl` constrains the bundled-data crossing to one AXI period;
only first-stage control inputs are false-pathed. No RAM or FIFO is inferred;
there is one outstanding request and no effect on streaming throughput.

`daphne-os` uses this readback for delay scans, bitslip scans and four final
verification reads per AFE. Expected aligned word remains `0x00FF00FF`.
Compact packet-v4 configuration must align, even if the old skip-alignment
environment override remains installed. Missing capability or timeout is failure;
input/output spy dumps remain unsupported. Hardware eye/alignment validation is
still required after deploying the matching firmware and server.
