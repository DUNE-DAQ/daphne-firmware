# KR260 PetaLinux Bootstrap

This directory contains repo-owned config fragments for integrating
`petalinux/meta-daphne/` into an existing KR260 PetaLinux project.

The expected flow is:

1. create or import a KR260-compatible PetaLinux project,
2. point it at the generated hardware handoff (`.xsa`),
3. attach `meta-daphne`,
4. choose the DAPHNE image profile,
5. install the DAPHNE package set into the image,
6. later add the real overlay and userspace payloads.

The helper script:

```bash
./scripts/petalinux/bootstrap_kr260_project.sh /path/to/petalinux-project
```

uses the fragments here to:

- add `project-spec/meta-daphne`
- append the DAPHNE layer to `build/conf/bblayers.conf`
- append the DAPHNE package set to `build/conf/local.conf`
- record `DAPHNE_IMAGE_PROFILE` in the project `local.conf`

Two profiles are currently supported:

- `developer`
  includes the on-target build stack for `daphne-server` / `daphneZMQ`
- `minimal`
  keeps only the repo-owned deploy payload (`daphne-overlay`,
  `daphne-server`, `daphne-services`)

Example:

```bash
./scripts/petalinux/bootstrap_kr260_project.sh \
  /path/to/petalinux-project \
  --image-profile minimal
```

This is still scaffolding, not a verified end-to-end PetaLinux image build.
