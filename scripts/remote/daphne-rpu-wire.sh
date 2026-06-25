#!/bin/sh
set -eu

REMOTEPROC="${DAPHNE_RPU_REMOTEPROC:-/sys/class/remoteproc/remoteproc0}"
FIRMWARE="${DAPHNE_RPU_FIRMWARE:-daphne-rpu-wire-rpu0.elf}"
CTRL="${DAPHNE_RPU_RPMSG_CTRL:-/dev/rpmsg_ctrl0}"
ENDPOINT_DST="${DAPHNE_RPU_ENDPOINT_DST:-1024}"
SYMLINK="${DAPHNE_RPU_RPMSG_SYMLINK:-/dev/rpmsg_daphne_afe}"
CREATE_ENDPOINT="${DAPHNE_RPU_CREATE_ENDPOINT:-/usr/local/bin/create_rpmsg_endpoint.py}"

write_sysfs() {
	printf '%s\n' "$1" > "$2"
}

endpoint_is_live() {
	target="$(readlink -f "$SYMLINK" 2>/dev/null || true)"
	[ -n "$target" ] && [ -c "$target" ]
}

[ -d "$REMOTEPROC" ] || {
	echo "Missing remoteproc: $REMOTEPROC" >&2
	exit 1
}

[ -r "/lib/firmware/$FIRMWARE" ] || {
	echo "Missing RPU firmware: /lib/firmware/$FIRMWARE" >&2
	exit 1
}

state="$(cat "$REMOTEPROC/state")"
if [ "$state" = "running" ]; then
	current="$(cat "$REMOTEPROC/firmware" 2>/dev/null || true)"
	if [ "$current" != "$FIRMWARE" ]; then
		echo "Stopping $REMOTEPROC running $current"
		write_sysfs stop "$REMOTEPROC/state"
		sleep 1
	else
		echo "$REMOTEPROC already running $FIRMWARE"
	fi
fi

if [ "$(cat "$REMOTEPROC/state")" != "running" ]; then
	write_sysfs "$FIRMWARE" "$REMOTEPROC/firmware"
	write_sysfs start "$REMOTEPROC/state"
fi

for _ in $(seq 1 50); do
	[ -c "$CTRL" ] && break
	sleep 0.1
done

[ -c "$CTRL" ] || {
	echo "RPMsg control device did not appear: $CTRL" >&2
	exit 1
}

if endpoint_is_live; then
	echo "$SYMLINK already points to a live endpoint"
	exit 0
fi

"$CREATE_ENDPOINT" --ctrl "$CTRL" --dst "$ENDPOINT_DST" --symlink "$SYMLINK"
