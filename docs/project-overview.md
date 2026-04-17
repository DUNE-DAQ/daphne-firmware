# Project Overview

This page is the high-level entry point for the current `daphne-firmware`
repository state.

It is written so it can live both as a checked-in repo document and as the
basis for a GitHub wiki page later.

## Philosophy

The repo is intentionally split between:

- preserving the known-working hardware build path
- making the design reviewable, testable, and eventually replaceable in pieces

That means the project does **not** try to rewrite the imported firmware blob in
one step. The working rule is:

- keep the shipped build path alive
- isolate ownership boundaries
- add verification around smaller blocks
- only replace behavior once the boundary is explicit and testable

This is why the repo contains both:

- the imported legacy/non-project Vivado flow
- the newer modular FuseSoC and `rtl/isolated/` layers

## Why FuseSoC

FuseSoC gives the repo a stable source-graph and target layer around the
imported firmware tree.

Practical reasons:

- reproducible source selection
- explicit platform/feature/test manifests
- local smoke-test targets that do not require Vivado
- a cleaner path toward board-specific and feature-specific build targets
- less dependence on hand-maintained generated file lists

The project still preserves the qualified Vivado flow, but FuseSoC now owns the
top-level intent:

- what the platform is
- what the supported targets are
- what the smoke/formal targets are

## Why Modularization

The imported tree is large and tightly coupled. Modularization exists to make
the design easier to reason about without breaking the known-good path
prematurely.

Practical reasons:

- isolate control, trigger, timing, transport, and analog ownership
- add smoke tests and formal checks at realistic boundaries
- make incremental refactors possible
- stop every change from being an all-design risk

The modularization work is intentionally additive first. It introduces cleaner
boundaries before trying to retire the compatibility path.

## Current Scope

What the repo owns today:

- the K26C hardware build path
- the Vivado/XSCT/DT overlay packaging flow
- the FuseSoC source graph and smoke/formal targets
- the first repo-owned PetaLinux scaffolding
- the runtime contract needed by `daphne-server`

What the repo does not fully own yet:

- full boot-image assembly
- complete PetaLinux/system image delivery
- automated install/start of the full service stack
- validated support beyond the current K26C baseline

## Current Stable Reference

- last routed-clean tested hardware commit: `a389fcd`
- current `main` tip carrying the DTBO packaging fixes for that line:
  `eb5f971`

That baseline has already been validated through:

- bitstream generation
- overlay generation
- overlay load on target
- clock-client bring-up
- `daphne-server`
- oscilloscope-mode signal visibility

## Developer Manifest

The current subsystem-level attribution map lives in:

- `docs/developer-manifest.md`

That file records the major development lanes for the imported proto
self-trigger path, filter path, peak-descriptor path, xcorr trigger path, and
the repo-owned formal/contracts/integration work.

## Requirements

### For local smoke/formal work

- `fusesoc`
- `edalize`
- `ghdl`
- optional formal toolchain from `oss-cad-suite`

### For the qualified hardware build path

Either:

- WSL2
- Windows Vivado 2024.1
- Windows Vitis 2024.1

Or:

- native Linux host
- Vivado 2024.1
- Vitis 2024.1

Recommended path discipline:

- WSL/Windows: `C:\w\d` and `/mnt/c/w/d`
- native Linux: `~/w/d`

Keep the path short and avoid spaces.

## Main Building Blocks

### 1. Imported compatibility layer

These files preserve the currently qualified hardware path:

- `ip_repo/daphne_ip/`
- `xilinx/`
- `daphne-ip.core`
- `daphne-ip-export.core`

This is still the real compatibility lane for the production K26C build.

### 2. Board and platform layer

This is where supported board ownership is defined:

- `boards/`
- `cores/platform/k26c-composable-platform.core`
- `scripts/fusesoc/build_platform.sh`

This layer defines the supported platform core and default targets.

### 3. Modular isolated RTL layer

This is the additive decomposition work:

- `rtl/isolated/`
- `cores/features/`
- `cores/common/`

This is where subsystem boundaries, neutral records, and reusable feature cores
are being made explicit.

### 4. Analog/frontend control path

Main responsibility:

- AFE and DAC control
- frontend register ownership
- capture/control boundaries

Examples:

- AFE configuration slices and banks
- DAC/interface blocks
- frontend register and capture blocks

### 5. Trigger and readout path

Main responsibility:

- self-trigger logic
- peak-descriptor generation
- STC3 record assembly
- readout handoff

Examples:

- `stc3_record_builder`
- peak-descriptor channel blocks
- xcorr/self-trigger imports
- readout mux/buffer path

### 6. Timing path

Main responsibility:

- endpoint timing ingress
- timing/control crossing into the PL design

Examples:

- timing endpoint sources under `rtl/timing/`
- timing subsystem wrappers in `rtl/isolated/subsystems/timing/`

### 7. Transport path

Main responsibility:

- Hermes/Deimos Ethernet and readout transport
- AXI-lite and packet/export plumbing

Examples:

- Hermes transport sources under
  `ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/`
- isolated Hermes boundary wrappers

### 8. Verification and deployment support

Examples:

- `tests/logic/`
- `formal/`
- `scripts/`
- `petalinux/`

These are what make the firmware repo more than a raw HDL import.

## How To Build

Use the end-to-end manual:

- [build-manual.md](/Users/marroyav/repo/daphne-firmware/docs/build-manual.md)

Short version for the qualified WSL path:

```bash
cd /mnt/c/w/d
export DAPHNE_BOARD=k26c
export DAPHNE_ETH_MODE=create_ip
export DAPHNE_GIT_SHA="$(git rev-parse --short=7 HEAD)"
export DAPHNE_OUTPUT_DIR="./output-$DAPHNE_GIT_SHA"
./scripts/wsl/check_windows_xilinx.sh
./scripts/wsl/run_wsl_vivado_chain.sh
```

Expected products:

- `xilinx/output-<gitsha>/daphne_selftrigger_<gitsha>.bit`
- `xilinx/output-<gitsha>/daphne_selftrigger_<gitsha>.bin`
- `xilinx/output-<gitsha>/daphne_selftrigger_<gitsha>.xsa`
- `xilinx/output-<gitsha>/daphne_selftrigger_<gitsha>.dtbo`
- `xilinx/output-<gitsha>/daphne_selftrigger_ol_<gitsha>.zip`

## Current TODO

The highest-value remaining work is:

1. build and qualify the repo-owned PetaLinux/image path
2. automate the handoff from firmware outputs into the image build
3. preserve `a389fcd` as the hardware regression baseline for future cleanup
4. extend verification deeper into timing, frontend, spy-buffer, and Hermes
   internals where bounded proofs are realistic
5. continue modularization without breaking the proven K26C path
6. expand validation beyond the current K26C baseline and current board

## Related Documents

- [build-manual.md](/Users/marroyav/repo/daphne-firmware/docs/build-manual.md)
- [build-baseline.md](/Users/marroyav/repo/daphne-firmware/docs/build-baseline.md)
- [firmware-delivery.md](/Users/marroyav/repo/daphne-firmware/docs/firmware-delivery.md)
- [remote-vivado.md](/Users/marroyav/repo/daphne-firmware/docs/remote-vivado.md)
- [wsl-windows-vivado.md](/Users/marroyav/repo/daphne-firmware/docs/wsl-windows-vivado.md)
- [gap-analysis.md](/Users/marroyav/repo/daphne-firmware/docs/gap-analysis.md)
