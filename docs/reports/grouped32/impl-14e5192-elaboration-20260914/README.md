# Pinned `14e5192` implementation attempt: elaboration failure

The full K26C Vivado 2026.1 run started from a fresh, initially clean checkout
of `14e5192d8701b49e51215ccdf186b137ac62b322` with eight requested
threads and `2100@xilinx-lic`. Packaging preflight and board timing-contract
checks passed. Vivado generated the BD and entered `synth_design`, then exited
with code 1 during RTL elaboration. Placement and routing did not start.

The first causal error is `Synth 8-9486`: `selftrig_core.vhd` instantiates
`selftrigger_register_bank` without the new required `counter_clock_i` actual.
The same log then reports that `selftrig_core_arch` was ignored and synthesis
failed. The integration fix maps the core's 62.5 MHz acquisition `clock` to
that port. The [full build log](build.log.gz), [run environment](run.env),
[launcher](run.sh), and [exit code](exit-code.txt) are retained for review.
The source clone's tracked RTL remained at the pinned commit; generation only
modified two `.core` manifests to enumerate generated IP collateral.

The log also repeats XXV Ethernet IP license warnings, already seen in the
successful `5e86a75` synthesis. They are not the reported cause of this
elaboration failure. Their effect on implementation and bitstream generation
still needs checking on a complete run.
