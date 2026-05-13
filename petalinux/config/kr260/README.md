# KR260 PetaLinux Bootstrap

This directory contains repo-owned config fragments for integrating
`petalinux/meta-daphne/` into an existing KR260 PetaLinux project.

The expected flow is:

1. create or import a KR260-compatible PetaLinux project,
2. point it at the generated hardware handoff (`.xsa`),
3. attach `meta-daphne`,
4. choose the DAPHNE image profile,
5. install the DAPHNE package set into the image,
6. stage the qualified overlay and userspace runtime payloads.

The helper script:

```bash
./scripts/petalinux/bootstrap_kr260_project.sh /path/to/petalinux-project
```

uses the fragments here to:

- add `project-spec/meta-daphne`
- sync repo-owned `project-spec/meta-user/recipes-bsp/u-boot` fragments
- append the DAPHNE layer to `build/conf/bblayers.conf`
- append the DAPHNE package set to `build/conf/local.conf`
- pin the project config to the KR260 machine
  (`CONFIG_SUBSYSTEM_INITRAMFS_IMAGE_NAME="petalinux-initramfs-image"`,
  `CONFIG_YOCTO_MACHINE_NAME="xilinx-k26-kr"`,
  `CONFIG_YOCTO_INCLUDE_MACHINE_NAME="k26-smk-kr"`,
  `CONFIG_SUBSYSTEM_MACHINE_NAME="AUTO"`)
- record `DAPHNE_IMAGE_PROFILE` in the project `local.conf`
- inherit the repo-owned image postprocess hooks for access policy and
  runtime-service cleanup

Two profiles are currently supported:

- `developer`
  includes the on-target build stack for `daphne-server` / `daphneZMQ`
- `minimal`
  keeps only the repo-owned deploy payload (`daphne-overlay`,
  `daphne-server`, `daphne-services`)

Fresh KR260 projects now default to `minimal`. The `developer` profile is
still supported, but it is opt-in because the current initramfs-oriented build
path can exceed `INITRAMFS_MAXSIZE` when the full on-target build stack is
enabled.

Example:

```bash
./scripts/petalinux/bootstrap_kr260_project.sh \
  /path/to/petalinux-project \
  --image-profile minimal
```

This is still scaffolding, not a verified end-to-end PetaLinux image build.

The current KR260 repo build path still uses an initramfs-oriented experiment,
but that is not the long-term fleet contract. The intended remote-operations
boot model is documented in:

- `docs/remote-boot-deployment-plan.md`

The repo now also owns the KR260 U-Boot fragment used for DAPHNE A/B work:

- `project-spec/meta-user/recipes-bsp/u-boot/files/bsp.cfg`

That fragment enables the environment-backed boot counter:

- `CONFIG_BOOTCOUNT_LIMIT=y`
- `CONFIG_BOOTCOUNT_ENV=y`
- `CONFIG_BOOTCOUNT_BOOTLIMIT=3`

This matters because the upstream KR260 U-Boot defconfig does not enable any
bootcount backend by default. Without that fragment, the DAPHNE slot-failover
logic only works when `bootcount` is seeded manually in the environment.
