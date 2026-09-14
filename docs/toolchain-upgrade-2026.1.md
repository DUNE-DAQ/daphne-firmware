# Toolchain Upgrade To 2026.1

This branch starts the migration of the DAPHNE firmware build flow from the
old 2024.x tool defaults to AMD Vivado, Vitis, and PetaLinux 2026.1.

## Updated Defaults

- Vivado Tcl flow expected version: `2026.1`
- Vitis device-tree generation prefers installed `sdtgen`; legacy `xsct`
  remains as a fallback for older installations.
- WSL Windows tool wrappers default to `DAPHNE_VIVADO_VERSION=2026.1`
- Windows DTBO recovery helper defaults to `C:\Xilinx\2026.1\Vitis`
- Debian 13 SDTGen runs with a repo-local ncurses compatibility shim under
  `build/xilinx-compat-libs` when Xilinx's bundled `libedit.so.0` asks for
  `libncurses.so.5`.
- Current PetaLinux setup path for this workspace:

```bash
source /opt/Xilinx/2026.1/PetaLinux/settings.sh
```

## Runtime Bundle Status

`petalinux/daphne-server-deps.lock.cmake` still records the existing staged
runtime dependency bundle:

```text
daphne-deps-petalinux2024.1-aarch64-glibc2.36-protobuf30.1-zeromq4.3.4.tar.gz
```

That filename and checksum should not be changed until `daphne-server` produces
a qualified 2026.1/PetaLinux runtime bundle. The firmware-side Yocto recipe was
made release-neutral so it can consume either the existing 2024-named staged
bundle or a future 2026.1 bundle without changing the recipe path logic.

## Next Validation Gates

- Run the native 2026.1 Vivado dry-run and then a license-backed synthesis.
- Regenerate the XSA with Vivado 2026.1.
- Regenerate DT overlay sources with Vitis SDTGen 2026.1.
- Create or refresh the KR260 PetaLinux project using PetaLinux 2026.1.
- Rebuild the `daphne-server` runtime bundle against the 2026.1 sysroot and
  update `petalinux/daphne-server-deps.lock.cmake` only after the checksum is
  known.
