#!/bin/sh
set -eu

REMOTEPROC="${DAPHNE_RPU_REMOTEPROC:-/sys/class/remoteproc/remoteproc0}"
SYMLINK="${DAPHNE_RPU_RPMSG_SYMLINK:-/dev/rpmsg_daphne_afe}"

rm -f "$SYMLINK"

if [ -e "$REMOTEPROC/state" ] && [ "$(cat "$REMOTEPROC/state")" = "running" ]; then
	printf stop > "$REMOTEPROC/state"
fi
