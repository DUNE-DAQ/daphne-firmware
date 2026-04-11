# Synthesis Timing Review

This note records the synthesis-side timing review for the current K26C
build path on `marroyav/merge-candidate`.

## Current flow

The supported Vivado batch flow currently drives synthesis through:

- [daphne_vivado_flow.tcl](/Users/marroyav/repo/daphne-firmware/xilinx/daphne_vivado_flow.tcl)
- `synth_design -top <bd_wrapper> -directive PerformanceOptimized`

Relevant lines:

- [daphne_vivado_flow.tcl](/Users/marroyav/repo/daphne-firmware/xilinx/daphne_vivado_flow.tcl#L97)
- [daphne_vivado_flow.tcl](/Users/marroyav/repo/daphne-firmware/xilinx/daphne_vivado_flow.tcl#L233)

The flow does not currently expose extra synthesis options such as explicit
retiming, resource-sharing overrides, or hierarchy controls.

## What UG901 Says

The local Vivado 2024.1 synthesis manual is:

- [ug901-vivado-synthesis-en-us-2024.1.pdf](/Users/marroyav/repo/third_party_docs/amd/vivado-2024.1/pdf/ug901-vivado-synthesis-en-us-2024.1.pdf)

Important points from that guide:

- `PerformanceOptimized` already performs general timing optimizations and
  logic-level reduction.
- `AlternateRoutability` is a distinct synthesis directive intended to improve
  routeability by reducing MUXF and carry-chain pressure.
- `flatten_hierarchy = rebuilt` is the QoR-friendly hierarchy mode because it
  allows cross-boundary optimization while rebuilding a readable hierarchy.
- `global_retiming` defaults to `auto`, and UG901 states that on non-Versal
  devices `auto` does not actually perform retiming.

For this design, the most important consequence is:

- the current flow is not obviously missing a timing-oriented synthesis
  directive,
- but it is also not explicitly enabling retiming on a non-Versal device.

## Repo-Specific Risk Areas

### 1. Retiming is still unused

K26C is a Zynq UltraScale+ target, not a Versal target. The current flow never
passes an explicit retiming option to `synth_design`, so the build is
effectively running without synthesis retiming today.

This is a real lever worth testing, but only after validating the exact Tcl
form on a Vivado 2024.1 host.

### 2. The STC3 waveform delay path changed implementation style

The legacy STC3 path used explicit `SRLC32E` primitives:

- [Daphne_MEZZ stc3.vhd](/Users/marroyav/repo/Daphne_MEZZ/ip_repo/daphne3_ip/rtl/selftrig/stc3.vhd#L264)

The current modular builder uses a behavioral fixed delay line:

- [fixed_delay_line.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/common/primitives/fixed_delay_line.vhd#L16)
- [stc3_record_builder.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/subsystems/trigger/stc3_record_builder.vhd#L72)

Vivado should be able to infer SRLs from this structure, but that is no longer
forced the way it was in the legacy code. If SRL inference fails, timing and
resource use can both degrade.

This is the most important synthesis-vs-RTL hotspot to inspect in the first
usable synthesized netlist.

## What Is Probably Not Worth Changing Blindly

- Forcing `flatten_hierarchy` away from the default without evidence.
- Forcing `resource_sharing` on or off globally.
- Disabling LUT combining or SRL extraction globally.
- Random synthesis directives beyond `PerformanceOptimized` and
  `AlternateRoutability`.

Those changes can easily move area/timing around without helping the actual
critical paths.

## Recommended Experiments

### Baseline

Keep the current default flow first:

- `DAPHNE_SYNTH_DIRECTIVE=PerformanceOptimized`

This is already a timing-oriented baseline.

### If the first real issue is routeability or congestion

Try one controlled synthesis-only experiment:

- `DAPHNE_SYNTH_DIRECTIVE=AlternateRoutability`

This is the lowest-risk synthesis experiment backed directly by UG901.

### If the first real issue is arithmetic/register timing

Retiming is the next synthesis lever to validate:

- expose an explicit synthesis retiming knob,
- verify the exact 2024.1 Tcl form on the Vivado host before wiring it into the
  flow,
- compare timing and utilization against the non-retimed baseline.

### After the first good synth checkpoint

Inspect whether the delayed waveform path inferred SRLs as intended:

- [fixed_delay_line.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/common/primitives/fixed_delay_line.vhd)
- [stc3_record_builder.vhd](/Users/marroyav/repo/daphne-firmware/rtl/isolated/subsystems/trigger/stc3_record_builder.vhd)

That check is more valuable than adding another speculative synthesis flag.

## Practical Conclusion

There is no obvious synthesis-documentation violation left in the current flow.

The best synthesis-side timing opportunities are:

1. keep the current `PerformanceOptimized` baseline for the first run,
2. try `AlternateRoutability` if congestion/routeability is the limiting issue,
3. validate and expose explicit retiming only after confirming the exact
   Vivado 2024.1 command form,
4. inspect SRL inference on the migrated `fixed_delay_line` path.
