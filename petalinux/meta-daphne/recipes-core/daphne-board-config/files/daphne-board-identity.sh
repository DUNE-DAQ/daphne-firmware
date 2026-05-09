#!/bin/sh
set -eu

env_file=/etc/daphne-board.env

[ -r "$env_file" ] || exit 0

# shellcheck disable=SC1090
. "$env_file"

hostname_value="${HOSTNAME_FQDN:-}"
[ -n "$hostname_value" ] || exit 0

printf '%s\n' "$hostname_value" > /etc/hostname
hostname "$hostname_value" || true
