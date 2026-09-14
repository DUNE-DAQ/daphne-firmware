# Grouped32 synthesis handoff

Synthesis now completes with the RTL fixes in `8ae5f81`; timing is not closed.
See the [captured reports](reports/grouped32/synth-20260914-8ae5f81/README.md) for
provenance and the [implementation goal and plan](grouped32-timing-closure-plan.md)
for the next steps.

The original coding handoff stopped before synthesis. Use the exact committed revision of
`codex/selftrigger-512-32ch-grouped4`; the final handoff supplies the commit and
bundle checksum. Read [the implementation](grouped32-implementation.md) and
[local validation](grouped32-validation.json) first.

Preferred host, from the user's workstation:

```sh
/mnt/c/Windows/System32/OpenSSH/ssh.exe larsoft-wsl-rj45
```

The last read-only inventory found Vivado 2026.1 at
`/home/marroyav/tools/Xilinx/2026.1/Vivado`, 28 logical CPUs, 23 GiB RAM and
12 GiB swap. Check current jobs and free memory before starting. Use one full
implementation at a time, initially with eight Vivado threads. Cooper is the
fallback host, not the default; its prior Kerberos authentication was expired.

Transfer the supplied Git bundle and clone into a **new, absent directory** on
the host's Linux filesystem. Do not reuse any generated IP, XPR, DCP, output or
FuseSoC work directory from a previous build. A local worktree is not itself a
portable repository; use the bundle to preserve both source parents.

Inside that fresh clone:

```sh
git status --short
git rev-parse HEAD
export XILINX_SETTINGS_SH=/home/marroyav/tools/Xilinx/2026.1/Vivado/settings64.sh
export DAPHNE_BOARD=k26c
export DAPHNE_ETH_MODE=create_ip
export DAPHNE_MAX_THREADS=8
export DAPHNE_PLATFORM_CORE=dune-daq:daphne:k26c-composable-platform:0.1.0
export DAPHNE_PLATFORM_TARGET=impl
export DAPHNE_DUMP_POST_SYNTH_DEBUG=1
export DAPHNE_STOP_AFTER_SYNTH=1
bash scripts/remote/run_remote_vivado_chain.sh
```

The first run is synthesis and reporting only. Check actual vendor XPM/UNISIM
elaboration, MMCM legality, BRAM/URAM inference and the resulting hierarchy before
spending time on placement/routing. Expect **four AFE islands, eight instances of
`afe_stc3_stream_serializer`, 32 `stc3_frame_source` instances, and four Hermes
PHY paths**. The native `stc3_record_builder` remains source-available as a test
reference and must not appear in the active synthesized hierarchy.

Collect hierarchical LUT/FF/BRAM/URAM/DSP utilization, MMCM/BUFG counts, inferred
312.5 MHz clocks, clock interactions, CDC and unconstrained-path reports. Include
all header/control crossings inherited from the four-SFP transport; local packet
simulation does not establish their timing closure. Do not hide failing fast
paths with blanket false paths or relaxed clocks. Check the new mailbox and FIFO
XPM constraints and synchronous URAM clocks explicitly.

If synthesis fits and the clock/CDC checks are sound, proceed to placement and
routing under the user's build authorization. Preserve per-stage reports and
source/tool hashes. Use actual routed timing and DRC to decide usability; a
successful bitstream command alone is insufficient. Keep any further changes on
this branch or a clearly identified experiment branch. Do not revive a 40-channel
or historical single-SFP grouped target. Do not program hardware.

If 312.5 MHz is the limiting path, report the failing logic and utilization first;
a two-sample 156.25 MHz shared engine is a possible subsequent experiment, not an
implemented option in this commit.
