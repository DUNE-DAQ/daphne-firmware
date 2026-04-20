## Fullstream Support Plan

This worktree stages support for two firmware architectures in the same
repository:

- self-trigger / composable path from `daphne-firmware`
- fullstream / streaming path from `daphne-fullstream-firmware`

### Recommendation

Do not create a new long-lived repository for this.

Use:

- one repository: `daphne-firmware`
- one development branch: `marroyav/fullstream-support`
- one board/profile selection per build target

This keeps:

- shared board collateral in one place
- shared subsystem boundaries in one place
- one build entry surface for Linux and WSL users
- one documentation and verification story

### Why FuseSoC Is The Right Integration Point

The fullstream migration is staged as a parallel namespace instead of a rewrite:

- `boards/k26c-fullstream/board.yml`
- `cores/common/daphne-fullstream-subsystem-types.core`
- `cores/features/daphne-fullstream-boundary-top.core`
- `cores/features/daphne-fullstream-modular.core`
- `cores/generated/daphne-fullstream-ip.core`
- `cores/platform/k26c-platform.core`
- `cores/platform/k26c-modular-platform.core`
- `cores/fullstream/features/*` for the colliding boundary wrappers
- `scripts/fusesoc/generate_daphne_fullstream_core.py`
- `xilinx/daphne_fullstream_*`

The self-trigger path remains in the existing `boards/k26c/`,
`cores/features/`, and `xilinx/` files.

### Practical Architecture

Phase 1 should preserve the fullstream naming and build surface as much as
possible.

Recommended first import model:

- keep the current self-trigger FuseSoC family unchanged
- add the fullstream family alongside it under the `fullstream/` namespace
- keep fullstream Vivado Tcl entry points unchanged during the first import
- select the architecture through `DAPHNE_BOARD`

That means the repository should eventually carry both:

- self-trigger platform cores
- fullstream platform cores

with the board profile deciding which implementation path to run.

### Initial Migration Scope

Import these first from `daphne-fullstream-firmware`:

- `boards/k26c/board.yml` as the source for the staged `k26c-fullstream`
  profile
- `cores/common/daphne-fullstream-subsystem-types.core`
- `cores/features/daphne-fullstream-boundary-top.core`
- `cores/features/daphne-fullstream-modular.core`
- `cores/generated/daphne-fullstream-ip.core`
- `cores/platform/k26c-platform.core`
- `cores/platform/k26c-modular-platform.core`
- `scripts/fusesoc/generate_daphne_fullstream_core.py`
- `xilinx/daphne_fullstream_*`

The colliding fullstream boundary wrappers live under
`cores/fullstream/features/` in this worktree so the self-trigger cores stay in
place.

Keep these variant-local on the first pass:

- `ip_repo/daphne3_ip/rtl/stream/*`
- `ip_repo/daphne3_ip/rtl/daphne3.vhd`
- stream-specific top and lane wiring

### Proposed Build Surface

The self-trigger build should remain the default.

The fullstream path should be introduced as an additional explicit board
selection, not as a replacement.

Example shape:

- self-trigger:
  - `DAPHNE_BOARD=k26c`
  - `dune-daq:daphne:k26c-composable-platform:0.1.0`
- fullstream:
  - `DAPHNE_BOARD=k26c-fullstream`
  - `dune-daq:daphne-fullstream:k26c-platform:0.1.0`

The staged `k26c-fullstream` board profile also carries a small legacy-manifest
compatibility shim so the existing repo-local board helpers can resolve the
fullstream naming surface without touching the self-trigger profile.

### Validation

There is no new RTL boundary in this scaffold yet, so there is nothing
meaningful to prove with the repo's formal flow at this stage.

The strongest practical check for this worktree is the focused smoke script:

```bash
./scripts/fusesoc/check_fullstream_support.sh
```

That check verifies:

- the fullstream platform cores are discoverable through FuseSoC
- `DAPHNE_BOARD=k26c-fullstream` resolves to the fullstream platform core
- the dry-run build path resolves the expected system name and work root
- the selected flow stops before Vivado exactly as intended for this scaffold

### Migration Order

1. Import the fullstream FuseSoC platform layer into this repository.
2. Keep its Vivado Tcl surface unchanged on the first pass.
3. Add build entry selection without changing the self-trigger default path.
4. Classify shared vs variant-local subsystems.
5. Converge shared boundaries only after the imported fullstream build is
   reproducible inside this repository.

### Non-Goals For The First Pass

- no Hermes rewrite
- no transport redesign
- no forced VLNV renaming on day one
- no deep RTL rename of the imported streaming top
- no attempt to unify self-trigger and fullstream internals before both build
  paths are reproducible

### Current Worktree

This migration staging area lives in:

- `/Users/marroyav/repo/daphne-firmware-fullstream`

on branch:

- `marroyav/fullstream-support`
