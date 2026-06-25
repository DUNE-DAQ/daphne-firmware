#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
toolchain_bin="${RPU_TOOLCHAIN_BIN:-/opt/Xilinx/PetaLinux/2024.1/tools/components/xsct/gnu/armr5/lin/gcc-arm-none-eabi/bin}"
gcc="${toolchain_bin}/armr5-none-eabi-gcc"
size="${toolchain_bin}/armr5-none-eabi-size"
readelf="${toolchain_bin}/armr5-none-eabi-readelf"

out_dir="${1:-${repo_root}/build/rpu-rpmsg-smoke}"
mkdir -p "$out_dir"

build_one() {
	local core="$1"
	local vring0="$2"
	local vring1="$3"
	local elf="${out_dir}/rpmsg-resource-table-r5-${core}.elf"

	"$gcc" \
		-mcpu=cortex-r5 \
		-marm \
		-ffreestanding \
		-nostdlib \
		-Wl,--build-id=none \
		-Wl,-T,"${repo_root}/rpu/rpmsg-smoke/linker.ld" \
		-DRPU_RSC_VRING0="${vring0}" \
		-DRPU_RSC_VRING1="${vring1}" \
		-o "$elf" \
		"${repo_root}/rpu/rpmsg-smoke/start.S" \
		"${repo_root}/rpu/rpmsg-smoke/resource_table.c"

	"$size" "$elf"
	"$readelf" -S "$elf" | grep -E 'resource_table|vectors|text'
}

build_one rpu0 0x3ED40000U 0x3ED44000U
build_one rpu1 0x3EF40000U 0x3EF44000U
