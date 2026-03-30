# Gap Analysis

## Implemented in this bootstrap

- Fresh `daphne-firmware` git repository created and connected to the empty
  GitHub remote.
- Current `Daphne_MEZZ` source tree imported as the baseline.
- Board-dependent Tcl settings parameterized.
- Initial board metadata added.
- FuseSoC HDL smoke tests added for the frontend trigger path and threshold
  window.
- Petalinux/dependency notes added for `daphne-server` compatibility.

## Still missing

- Full top-level FuseSoC integration for the complete Vivado design.
  Reason: the current firmware flow still generates Xilinx vendor IP and BD
  artifacts procedurally from Tcl; it is not yet decomposed into self-contained
  CAPI2 cores.

- Verified simulator/tool execution in this workspace.
  FuseSoC is wired up repo-locally, but no HDL simulator or Xilinx tools are
  available yet on this host, so the new smoke tests have not run end to end.

- Carrier support beyond the imported K26C baseline.
  The repo has a board abstraction point now, but `kr260` is only a scaffold
  until the real pin map, board preset, and overlay validation exist.

- Petalinux packaging.
  There is no Yocto layer, no systemd/service setup, no boot-image recipe, and
  no automated installation path for bitstream + dtbo + `daphne-server`.

- End-to-end deployment test.
  No generated bitstream, `.xsa`, `.dtbo`, or server-on-target validation has
  been executed from this new repo yet.

- Linux/C++ dependency bundling inside this repo.
  The lockfile is mirrored, but the actual dependency tarball and deployment
  scripts still live with `daphne-server`.

## Recommended next steps

1. Install `fusesoc`, `edalize`, `ghdl`, and the Xilinx 2024.1 toolchain on a
   Linux host.
2. Run the new frontend and threshold smoke tests and fix any CAPI2/backend
   issues.
3. Split the full design into reusable FuseSoC cores: common RTL, Hermes block,
   Kria PS/BD wrapper, and board constraints.
4. Add a Petalinux recipe or deploy bundle flow that consumes the generated
   firmware outputs and co-installs `daphne-server`.
