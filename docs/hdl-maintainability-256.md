# HDL maintainability review: production 256/5

## Scope and outcome

This review covers only the XPM storage primitives
`grouped_sample_ring` and `packet_frame_store`.  The changes are intentionally
small and behavior-preserving: clearer module-purpose comments, consistently
laid-out interfaces, comments explaining the otherwise non-obvious XPM
one-bit write-enable vector, and private signal names that state that role.

It applies the general review principles in Google's engineering-practices
guidance: code should be understandable by a later reader; names should be
clear; comments should explain information that code cannot; and a review
should improve code health without demanding unrelated perfection.  This is
not a claim that Google publishes a VHDL or FPGA coding standard.

- [What to look for in a code review](https://google.github.io/eng-practices/review/reviewer/looking-for.html)
- [The standard of code review](https://google.github.io/eng-practices/review/reviewer/standard.html)

## Audit findings and preserved invariants

| Primitive | Preserved interface and implementation invariants |
| --- | --- |
| `grouped_sample_ring` | Entity name, ports, generic defaults, `ram_inst` hierarchy label, independent `clock_i`/`builder_clock_i` XPM mode, block-RAM primitive, full-word writes, no reset, and `READ_LATENCY_B = 1` are unchanged. `DEPTH_G = 2**ADDR_WIDTH_G` remains asserted. The primitive still contains no CDC mechanism or backpressure. |
| `packet_frame_store` | Entity name, ports, `ram_inst` hierarchy label, common `clock_i` XPM mode, UltraRAM primitive, 4096 x 72 geometry, full-word writes, no reset, `READ_LATENCY_B = 1`, and `read_first` behavior are unchanged. The caller still owns FWFT one-word look-ahead addressing and header publication ordering. |

Searches of repository XDC, Tcl, and SDC sources found no direct references to
these entity names or their `ram_inst` labels.  Nevertheless, those labels were
not renamed because hierarchy can also be consumed by generated reports,
external scripts, or out-of-tree constraints.  No memory inference parameters
were changed.

## Maintenance guidance

Preserve the module comments when changing any latency, clock ownership,
publication ordering, or inferred memory resource.  Such a change needs an RTL
and timing/CDC review, not a comment-only cleanup.

Descriptive names and comments improve human review and modification safety;
they do not by themselves make synthesis faster or smaller.  Pursue structural
performance work separately, using measured synthesis, implementation, timing,
and resource reports while explicitly rechecking latency, reset, CDC, and
memory-inference contracts.
