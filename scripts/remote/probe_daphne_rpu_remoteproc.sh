#!/usr/bin/env sh
set -eu

section() {
	printf '\n== %s ==\n' "$1"
}

print_file() {
	label=$1
	path=$2
	if [ -e "$path" ]; then
		printf '%s=' "$label"
		cat "$path"
	fi
}

dump_dt_reg() {
	path=$1
	if [ -f "$path/reg" ]; then
		printf '%s reg:' "$path"
		od -An -tx4 -v "$path/reg"
	fi
}

section "host"
hostname
uname -a
if [ -r /proc/device-tree/model ]; then
	printf 'model='
	tr '\000' ' ' < /proc/device-tree/model
	printf '\n'
fi

section "remoteproc sysfs"
if [ -d /sys/class/remoteproc ]; then
	ls -l /sys/class/remoteproc
	for rp in /sys/class/remoteproc/remoteproc*; do
		[ -e "$rp" ] || continue
		printf '\n%s\n' "$rp"
		print_file name "$rp/name"
		print_file state "$rp/state"
		print_file firmware "$rp/firmware"
	done
else
	echo "/sys/class/remoteproc is missing"
fi

section "rpmsg sysfs"
for path in /sys/bus/rpmsg /sys/class/rpmsg /dev/rpmsg* /dev/ttyRPMSG*; do
	[ -e "$path" ] || continue
	ls -ld "$path"
done

section "kernel modules"
kver=$(uname -r)
for mod in \
	remoteproc/zynqmp_r5_remoteproc.ko \
	rpmsg/rpmsg_core.ko \
	rpmsg/rpmsg_char.ko \
	rpmsg/rpmsg_ctrl.ko \
	rpmsg/rpmsg_ns.ko \
	rpmsg/virtio_rpmsg_bus.ko
do
	path="/lib/modules/$kver/kernel/drivers/$mod"
	[ -e "$path" ] && ls -l "$path"
done

section "kernel config"
if [ -r /proc/config.gz ]; then
	zcat /proc/config.gz | grep -E 'CONFIG_(REMOTEPROC|ZYNQMP_R5_REMOTEPROC|RPMSG|ZYNQMP_IPI_MBOX|MAILBOX)=' || true
else
	echo "/proc/config.gz is not readable"
fi

section "device tree rpu nodes"
for node in \
	/proc/device-tree/r5fss@ff9a0000 \
	/proc/device-tree/tcm_0a@ffe00000 \
	/proc/device-tree/tcm_0b@ffe20000 \
	/proc/device-tree/tcm_1a@ffe90000 \
	/proc/device-tree/tcm_1b@ffeb0000 \
	/proc/device-tree/reserved-memory/rproc@3ed00000 \
	/proc/device-tree/reserved-memory/rpu0vdev0vring0@3ed40000 \
	/proc/device-tree/reserved-memory/rpu0vdev0vring1@3ed44000 \
	/proc/device-tree/reserved-memory/rpu0vdev0buffer@3ed48000 \
	/proc/device-tree/reserved-memory/rproc@3ef00000 \
	/proc/device-tree/reserved-memory/rpu1vdev0vring0@3ef40000 \
	/proc/device-tree/reserved-memory/rpu1vdev0vring1@3ef44000 \
	/proc/device-tree/reserved-memory/rpu1vdev0buffer@3ef48000
do
	if [ -d "$node" ]; then
		echo "present: $node"
		dump_dt_reg "$node"
	else
		echo "missing: $node"
	fi
done

section "dmesg"
dmesg | grep -Ei 'remoteproc|rproc|r5|rpu|rpmsg|virtio|ipi|mailbox|tcm' | tail -n 80 || true
