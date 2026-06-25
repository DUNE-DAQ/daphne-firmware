#!/usr/bin/env sh
set -eu

firmware_src="${1:-/tmp/rpmsg-resource-table-r5-rpu0.elf}"
firmware_name="${2:-daphne-rpmsg-resource-table-r5.elf}"
remoteproc="${3:-/sys/class/remoteproc/remoteproc0}"
firmware_dst="/lib/firmware/${firmware_name}"

section() {
	printf '\n== %s ==\n' "$1"
}

read_state() {
	cat "$1/state"
}

write_sysfs() {
	path=$1
	value=$2
	sudo -n sh -c 'printf "%s\n" "$1" > "$2"' sh "$value" "$path"
}

section "install firmware"
ls -l "$firmware_src"
sudo -n install -m 0644 "$firmware_src" "$firmware_dst"
ls -l "$firmware_dst"

section "load rpmsg modules"
for mod in rpmsg_core virtio_rpmsg_bus rpmsg_ns rpmsg_ctrl rpmsg_char; do
	sudo -n modprobe "$mod" 2>/dev/null || true
done
lsmod | grep -E 'rpmsg|remoteproc|virtio' || true

section "start"
printf 'remoteproc=%s\n' "$remoteproc"
printf 'name='
cat "$remoteproc/name"
printf 'initial_state='
read_state "$remoteproc"

if [ "$(read_state "$remoteproc")" != "offline" ]; then
	write_sysfs "$remoteproc/state" stop
	sleep 1
fi

write_sysfs "$remoteproc/firmware" "$firmware_name"
printf 'firmware='
cat "$remoteproc/firmware"

write_sysfs "$remoteproc/state" start
sleep 2
printf 'running_state='
read_state "$remoteproc"

section "virtio and rpmsg"
for path in /sys/bus/virtio/devices/* /sys/bus/rpmsg/devices/* /sys/class/rpmsg/* /dev/rpmsg* /dev/ttyRPMSG*; do
	[ -e "$path" ] || continue
	ls -ld "$path"
done

section "dmesg after start"
dmesg | grep -Ei 'remoteproc|rproc|r5|rpu|rpmsg|virtio|vring|resource' | tail -n 120 || true

section "stop"
write_sysfs "$remoteproc/state" stop
sleep 1
printf 'final_state='
read_state "$remoteproc"
