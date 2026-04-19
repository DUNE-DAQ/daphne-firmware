# Build Manual

This is the repo-owned build path from `git clone` to the generated firmware
products.

All commands below run from the **repo root** unless a section says otherwise.

The architectural build-flow view is maintained separately in:

- [architecture-reference.md](/Users/marroyav/repo/daphne-firmware/docs/architecture-reference.md)

![daphne-firmware build flow](figures/architecture/build_flow.svg)

## Scope

The currently qualified hardware build path is:

- board: `k26c`
- branch: `main`
- routed-clean hardware baseline: `a389fcd`
- current `main` tip carrying that baseline plus DTBO packaging fixes:
  `eb5f971`
- qualified host/tool arrangement:
  - WSL2 shell
  - Windows Vivado 2024.1
  - Windows Vitis 2024.1

The repo also supports a native Linux remote-Vivado path. The macOS workspace
is useful for local smoke tests and documentation work, but not as the
qualified full hardware build host.

## Path Rules

Keep the repo path short.

Recommended:

- WSL + Windows tools:
  - Windows path: `C:\w\d`
  - WSL path: `/mnt/c/w/d`
- native Linux remote host:
  - `~/w/d`

Avoid:

- deep home-directory paths
- paths with spaces
- long nested build roots

Reason:

- Vivado, XSCT, DTG, and generated IP trees create very deep paths
- the WSL-to-Windows wrapper path is more reliable when the repo is visible
  through a short Windows path

## 1. Clone The Repo

### WSL2 + Windows Vivado/Vitis

Run in WSL:

```bash
mkdir -p /mnt/c/w
git clone git@github.com:DUNE-DAQ/daphne-firmware.git /mnt/c/w/d
cd /mnt/c/w/d
git checkout main
git pull --ff-only
```

### Native Linux Remote Host

Run on the remote Linux host:

```bash
mkdir -p ~/w
git clone git@github.com:DUNE-DAQ/daphne-firmware.git ~/w/d
cd ~/w/d
git checkout main
git pull --ff-only
```

## 2. Optional Local Sanity Checks

Run from the repo root on any host with the local HDL tools installed:

```bash
./scripts/fusesoc/run_logic_test.sh
./scripts/formal/run_formal.sh --list
```

These are not the hardware build. They only sanity-check the checked-in smoke
and formal targets.

## 3. Full Qualified Build From WSL

Run in WSL from `/mnt/c/w/d`:

```bash
cd /mnt/c/w/d
export DAPHNE_BOARD=k26c
export DAPHNE_ETH_MODE=create_ip
export DAPHNE_GIT_SHA="$(git rev-parse --short=7 HEAD)"
export DAPHNE_OUTPUT_DIR="./output-$DAPHNE_GIT_SHA"
./scripts/wsl/check_windows_xilinx.sh
./scripts/wsl/run_wsl_vivado_chain.sh
```

What this does:

1. checks the Windows Vivado/Vitis wrappers
2. runs packaged-IP preflight when the selected target needs it
3. runs the qualified K26C implementation flow
4. runs DT overlay packaging

Logs go under:

```text
build/wsl-vivado/<timestamp>/
```

Important environment rules:

- keep `DAPHNE_OUTPUT_DIR` unset or relative to `xilinx/`
- do not point `DAPHNE_OUTPUT_DIR` at a Linux absolute path outside the repo
- `DAPHNE_BOARD=k26c` is the qualified board path
- `DAPHNE_ETH_MODE=create_ip` is the qualified Ethernet mode

## 4. Full Build On A Native Linux Vivado Host

Run on the Linux host from `~/w/d`:

```bash
cd ~/w/d
export XILINX_SETTINGS_SH=/path/to/Vivado/2024.1/settings64.sh
export XILINX_VITIS_SETTINGS_SH=/path/to/Vitis/2024.1/settings64.sh
export DAPHNE_BOARD=k26c
export DAPHNE_ETH_MODE=create_ip
export DAPHNE_GIT_SHA="$(git rev-parse --short=7 HEAD)"
export DAPHNE_OUTPUT_DIR="./output-$DAPHNE_GIT_SHA"
./scripts/remote/run_remote_vivado_chain.sh
```

If you also want the remote wrapper to attempt DTBO packaging, add:

```bash
export DAPHNE_REMOTE_PACKAGE_DTBO=1
```

Logs go under:

```text
build/remote-vivado/<timestamp>/
```

## 5. Packaging From Existing `.xsa` / `.bin`

If the main implementation already produced:

- `daphne_selftrigger_<gitsha>.xsa`
- `daphne_selftrigger_<gitsha>.bin`

then the repo can finish the overlay bundle from the existing handoff:

```bash
cd /mnt/c/w/d
export DAPHNE_GIT_SHA="$(git rev-parse --short=7 HEAD)"
./scripts/package/complete_dtbo_bundle.sh ./xilinx/output-$DAPHNE_GIT_SHA
```

This is the right recovery step when implementation finished but the overlay
bundle still needs to be generated.

## 6. Expected Build Products

The main output directory is:

```text
xilinx/output-<gitsha>/
```

For a successful qualified build, expect at least:

- `daphne_selftrigger_<gitsha>.bit`
- `daphne_selftrigger_<gitsha>.bin`
- `daphne_selftrigger_<gitsha>.xsa`
- `daphne_selftrigger_<gitsha>.dtbo`
- `daphne_selftrigger_ol_<gitsha>/`
- `daphne_selftrigger_ol_<gitsha>.zip`
- `SHA256SUMS`
- implementation reports such as:
  - `post_route_timing_summary.rpt`
  - `post_route_methodology.rpt`
  - `post_route_util.rpt`

## 7. Current Hardware-Proven Boundary

The current repo-owned build and deployment boundary is now proven through:

- routed-clean firmware baseline `a389fcd`
- repo `main` tip `eb5f971` for DTBO packaging
- overlay load on target
- clock-client bring-up
- `daphne-server` start
- oscilloscope-mode signal visibility on hardware

That means the repo now owns a real build-to-overlay artifact flow. It does
not yet own the full boot-image/PetaLinux deliverable.

## 8. What Is Still Outside This Manual

This manual ends at the generated firmware products.

Still outside this scope:

- `BOOT.BIN` assembly
- kernel/rootfs image generation
- full `system.dtb`
- automated PetaLinux image handoff and collection

For those next steps, see:

- [petalinux/README.md](/Users/marroyav/repo/daphne-firmware/petalinux/README.md)
- [docs/firmware-delivery.md](/Users/marroyav/repo/daphne-firmware/docs/firmware-delivery.md)
- [docs/remote-vivado.md](/Users/marroyav/repo/daphne-firmware/docs/remote-vivado.md)
- [docs/wsl-windows-vivado.md](/Users/marroyav/repo/daphne-firmware/docs/wsl-windows-vivado.md)
