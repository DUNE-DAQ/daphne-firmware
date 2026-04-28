# `meta-daphne`

This is the first repo-owned scaffold for the PetaLinux side of the DAPHNE
delivery path.

Its purpose is not to claim a working PetaLinux image today. Its purpose is to
make ownership explicit for the pieces that are required to eventually produce:

- `system.dtb`
- `BOOT.BIN`
- kernel and boot assets
- installed DAPHNE overlay artifacts
- installed `daphne-server`
- systemd bring-up units

## What is here now

- `conf/layer.conf`
  layer registration and collection metadata
- `recipes-bsp/device-tree`
  the hook point for repo-owned device-tree changes
- `recipes-firmware/daphne-overlay`
  the hook point for installing the generated overlay bundle
- `recipes-apps/daphne-server`
  the hook point for packaging the userspace server
- `recipes-core/daphne-services`
  the hook point for systemd service ownership
- `recipes-core/packagegroups/packagegroup-daphne-server-build.bb`
  the default-on target-side build/runtime dependency set for `daphne-server`
  and `daphneZMQ`

## What is not here yet

- a complete PetaLinux project
- a verified KR260 BSP import
- a build-tested image recipe
- a boot-image recipe producing `BOOT.BIN`
- full service files and runtime packaging

## Current image profiles

The KR260 bootstrap config now records `DAPHNE_IMAGE_PROFILE` in the project
`local.conf`. Two profiles are currently supported:

- `developer`
  includes a repo-owned packagegroup that pulls in the dependencies needed to
  build `daphne-server` / `daphneZMQ` on target
- `minimal`
  keeps only the repo-owned deploy payload without the extra build stack

The `developer` packagegroup currently targets the dependency shape documented
by the upstream `daphneZMQ` project:

- C/C++ build toolchain
- CMake and pkg-config
- ZeroMQ / cppzmq
- Protobuf + `protoc`
- Abseil
- CLI11
- Python 3 plus the client-side packages (`pyzmq`, `protobuf`, `numpy`,
  `matplotlib`, `tqdm`)
- I2C tools

This is intentionally a developer-friendly baseline, not yet the final minimal
production image. To switch an initialized project to the smaller profile, set:

```conf
DAPHNE_IMAGE_PROFILE = "minimal"
```

## Design intent

The base KR260 board DT should stay owned by the PetaLinux/BSP layer.
DAPHNE-specific board policy should be layered on top through repo-owned device
tree fragments and recipes, while PL-specific hardware description remains the
responsibility of the firmware build and overlay path.
