#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
toolchain_bin="${RPU_TOOLCHAIN_BIN:-/opt/Xilinx/PetaLinux/2024.1/tools/components/xsct/gnu/armr5/lin/gcc-arm-none-eabi/bin}"
gcc="${toolchain_bin}/armr5-none-eabi-gcc"
size="${toolchain_bin}/armr5-none-eabi-size"
readelf="${toolchain_bin}/armr5-none-eabi-readelf"

out_dir="${1:-${repo_root}/build/rpu-smoke}"
mkdir -p "$out_dir"

"$gcc" \
	-mcpu=cortex-r5 \
	-marm \
	-ffreestanding \
	-nostdlib \
	-Wl,--build-id=none \
	-Wl,-T,"${repo_root}/rpu/smoke/linker.ld" \
	-o "${out_dir}/noop-r5.elf" \
	"${repo_root}/rpu/smoke/noop_r5.S"

"$size" "${out_dir}/noop-r5.elf"
"$readelf" -l "${out_dir}/noop-r5.elf"
