#!/usr/bin/env sh
set -eu

firmware_src="${1:-/tmp/noop-r5.elf}"
firmware_name="${2:-daphne-noop-r5.elf}"
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

section "start-stop smoke"
for rp in /sys/class/remoteproc/remoteproc0 /sys/class/remoteproc/remoteproc1; do
	[ -e "$rp" ] || continue
	printf '\n%s\n' "$rp"
	printf 'name='
	cat "$rp/name"
	printf 'initial_state='
	read_state "$rp"

	if [ "$(read_state "$rp")" != "offline" ]; then
		write_sysfs "$rp/state" stop
		sleep 1
	fi

	write_sysfs "$rp/firmware" "$firmware_name"
	printf 'firmware='
	cat "$rp/firmware"

	write_sysfs "$rp/state" start
	sleep 1
	printf 'running_state='
	read_state "$rp"

	write_sysfs "$rp/state" stop
	sleep 1
	printf 'final_state='
	read_state "$rp"
done

section "dmesg"
dmesg | grep -Ei 'remoteproc|rproc|r5|rpu|tcm' | tail -n 80 || true
