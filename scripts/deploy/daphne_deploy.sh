#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: daphne_deploy.sh --board BOARD --host HOST --bundle DIR [OPTIONS]

Deploy a collected DAPHNE PetaLinux bundle to the inactive eMMC slot over SSH,
set the U-Boot slot state for a trial boot, and optionally reboot.

This is the first repo-owned orchestration layer. It deliberately handles eMMC
slot deployment only. QSPI boot-firmware updates stay on the AMD-supported
helper path:

  scripts/remote/stage_bootfw_update_over_ssh.sh

Required:
  --board BOARD           Board id, for logging and operator checks.
  --host HOST             SSH hostname or IP.
  --bundle DIR            Collected PetaLinux bundle. Not required with --verify.

Options:
  --user USER             SSH user. Default: petalinux.
  --emmc inactive-slot    Deploy to the inactive slot. Default.
  --emmc a|b              Force a target slot.
  --remote-dir DIR        Target-board staging dir. Default: /tmp/daphne-deploy.
  --ssh-option OPT        Extra ssh/scp -o option. May be repeated.
  --control-host HOST     Optional SSH host that can reach the board.
  --control-dir DIR       Control-host staging dir. Default: /tmp/daphne-deploy-control.
  --control-ssh-option O  Extra ssh/scp -o option for --control-host.
  --reboot                Reboot after staging and env update.
  --verify                Verify the current boot state only; do not deploy.
  --dry-run               Resolve and print the plan without copying/writing.
  -h, --help              Show this help.

Expected bundle layout:
  boot/Image
  boot/system.dtb
  boot/ramdisk.cpio.gz.u-boot
  rootfs/rootfs.ext4
EOF
}

board=""
host=""
bundle_dir=""
ssh_user="petalinux"
emmc_mode="inactive-slot"
remote_dir="/tmp/daphne-deploy"
control_host=""
control_dir="/tmp/daphne-deploy-control"
reboot_after=0
verify_only=0
dry_run=0
ssh_options=()
control_ssh_options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --board)
      board="$2"
      shift 2
      ;;
    --host)
      host="$2"
      shift 2
      ;;
    --bundle)
      bundle_dir="$2"
      shift 2
      ;;
    --user)
      ssh_user="$2"
      shift 2
      ;;
    --emmc)
      emmc_mode="$2"
      shift 2
      ;;
    --remote-dir)
      remote_dir="$2"
      shift 2
      ;;
    --ssh-option)
      ssh_options+=("$2")
      shift 2
      ;;
    --control-host)
      control_host="$2"
      shift 2
      ;;
    --control-dir)
      control_dir="$2"
      shift 2
      ;;
    --control-ssh-option)
      control_ssh_options+=("$2")
      shift 2
      ;;
    --reboot)
      reboot_after=1
      shift
      ;;
    --verify)
      verify_only=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$board" || -z "$host" ]]; then
  usage >&2
  exit 2
fi

case "$emmc_mode" in
  inactive-slot|a|b) ;;
  *)
    echo "ERROR: --emmc must be inactive-slot, a, or b" >&2
    exit 2
    ;;
esac

ssh_flags=(-o BatchMode=yes)
for opt in "${ssh_options[@]}"; do
  ssh_flags+=(-o "$opt")
done

ssh_dest="${ssh_user}@${host}"

control_ssh_flags=(-o BatchMode=yes)
for opt in "${control_ssh_options[@]}"; do
  control_ssh_flags+=(-o "$opt")
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command '$1' not found" >&2
    exit 2
  }
}

need_cmd ssh
if (( ! verify_only && ! dry_run )); then
  need_cmd scp
fi

bundle_dir_abs=""
rootfs_img=""
kernel_img=""
dtb_img=""
ramdisk_img=""

if (( ! verify_only )); then
  if [[ -z "$bundle_dir" ]]; then
    echo "ERROR: --bundle is required unless --verify is used" >&2
    exit 2
  fi
  bundle_dir_abs="$(CDPATH= cd -- "$bundle_dir" && pwd)"
  rootfs_img="$bundle_dir_abs/rootfs/rootfs.ext4"
  kernel_img="$bundle_dir_abs/boot/Image"
  dtb_img="$bundle_dir_abs/boot/system.dtb"
  ramdisk_img="$bundle_dir_abs/boot/ramdisk.cpio.gz.u-boot"
  for path in "$rootfs_img" "$kernel_img" "$dtb_img" "$ramdisk_img"; do
    if [[ ! -f "$path" ]]; then
      echo "ERROR: missing bundle artifact: $path" >&2
      exit 2
    fi
  done
fi

stamp="$(date -u +%Y%m%d-%H%M%SZ)"

cat <<EOF
Board:       $board
Host:        $host
SSH user:    $ssh_user
Mode:        $([[ "$verify_only" -eq 1 ]] && echo verify || echo deploy)
eMMC target: $emmc_mode
Bundle:      ${bundle_dir_abs:-<not used>}
Remote dir:  $remote_dir
Control:     ${control_host:-<none>}
Reboot:      $reboot_after
Dry run:     $dry_run
Stamp:       $stamp
EOF

remote_script_common="$(cat <<'EOF'
set -euo pipefail

as_root() {
  sudo -n "$@"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required remote command '$1' not found" >&2
    exit 2
  }
}

slot_root() {
  case "$1" in
    a) printf '%s\n' /dev/mmcblk0p2 ;;
    b) printf '%s\n' /dev/mmcblk0p4 ;;
    *) return 2 ;;
  esac
}

slot_boot_part() {
  case "$1" in
    a) printf '%s\n' /dev/mmcblk0p1 ;;
    b) printf '%s\n' /dev/mmcblk0p3 ;;
    *) return 2 ;;
  esac
}

slot_boot_mount() {
  case "$1" in
    a) printf '%s\n' /run/media/boot-mmcblk0p1 ;;
    b) printf '%s\n' /run/media/boot_b-mmcblk0p3 ;;
    *) return 2 ;;
  esac
}

current_root="$(awk '$2 == "/" {print $1; exit}' /proc/mounts)"
active_slot="$(as_root /usr/bin/fw_printenv -n active_slot)"
bootcount="$(as_root /usr/bin/fw_printenv -n bootcount 2>/dev/null || true)"
upgrade_available="$(as_root /usr/bin/fw_printenv -n upgrade_available 2>/dev/null || true)"
last_good_slot="$(as_root /usr/bin/fw_printenv -n last_good_slot 2>/dev/null || true)"

case "$target_slot_requested" in
  inactive-slot)
    case "$active_slot" in
      a) target_slot=b ;;
      b) target_slot=a ;;
      *)
        echo "ERROR: unknown active_slot from U-Boot env: $active_slot" >&2
        exit 3
        ;;
    esac
    ;;
  a|b)
    target_slot="$target_slot_requested"
    ;;
  *)
    echo "ERROR: invalid target slot request: $target_slot_requested" >&2
    exit 2
    ;;
esac

target_root="$(slot_root "$target_slot")"
target_boot_part="$(slot_boot_part "$target_slot")"
target_boot_mount="$(slot_boot_mount "$target_slot")"

cat <<STATE
== remote-state ==
hostname=$(hostname)
current_root=$current_root
active_slot=$active_slot
last_good_slot=${last_good_slot:-}
upgrade_available=${upgrade_available:-}
bootcount=${bootcount:-}
target_slot=$target_slot
target_root=$target_root
target_boot_part=$target_boot_part
target_boot_mount=$target_boot_mount
STATE

if [[ "$mode" == "verify" ]]; then
  exit 0
fi

if [[ "$current_root" == "$target_root" ]]; then
  echo "ERROR: refusing to deploy over the currently mounted rootfs: $target_root" >&2
  exit 4
fi

for cmd in /bin/dd /bin/cp /bin/mkdir /bin/sync /bin/umount /sbin/e2fsck /usr/bin/fw_setenv; do
  if [[ ! -e "$cmd" ]]; then
    echo "ERROR: missing expected absolute command on target: $cmd" >&2
    exit 2
  fi
done

resize_cmd=""
for cmd in /sbin/resize2fs /usr/sbin/resize2fs; do
  if [[ -x "$cmd" ]]; then
    resize_cmd="$cmd"
    break
  fi
done

if [[ "$dry_run" == "1" ]]; then
  echo "== dry-run: no remote writes =="
  exit 0
fi
EOF
)"

remote_deploy_tail="$(cat <<'EOF'
remote_rootfs="$remote_dir/rootfs.ext4"
remote_kernel="$remote_dir/Image"
remote_dtb="$remote_dir/system.dtb"
remote_ramdisk="$remote_dir/ramdisk.cpio.gz.u-boot"

for path in "$remote_rootfs" "$remote_kernel" "$remote_dtb" "$remote_ramdisk"; do
  if [[ ! -f "$path" ]]; then
    echo "ERROR: staged artifact missing on target: $path" >&2
    exit 5
  fi
done

target_mounts="$(awk -v dev="$target_root" '$1 == dev {print $2}' /proc/mounts || true)"
if [[ -n "$target_mounts" ]]; then
  while read -r mount_point; do
    [[ -n "$mount_point" ]] || continue
    echo "Unmounting inactive rootfs mount: $mount_point"
    as_root /bin/umount "$mount_point"
  done <<MOUNTS
$target_mounts
MOUNTS
fi

echo "Writing rootfs to $target_root"
as_root /bin/dd if="$remote_rootfs" of="$target_root" bs=16M
as_root /bin/sync

echo "Checking rootfs on $target_root"
set +e
as_root /sbin/e2fsck -fy "$target_root"
e2fsck_rc=$?
set -e
if (( e2fsck_rc > 3 )); then
  echo "ERROR: e2fsck failed with rc=$e2fsck_rc" >&2
  exit "$e2fsck_rc"
fi
if [[ -n "$resize_cmd" ]]; then
  echo "Growing rootfs on $target_root with $resize_cmd"
  as_root "$resize_cmd" "$target_root"
  as_root /bin/sync
else
  echo "WARNING: resize2fs not available on active runtime; $target_root keeps image filesystem size." >&2
fi

if [[ ! -d "$target_boot_mount" ]]; then
  as_root /bin/mkdir -p "$target_boot_mount"
fi
if ! awk -v dev="$target_boot_part" -v mp="$target_boot_mount" '$1 == dev && $2 == mp {found=1} END {exit found ? 0 : 1}' /proc/mounts; then
  as_root /bin/mount "$target_boot_part" "$target_boot_mount"
fi

echo "Staging boot assets to $target_boot_mount"
as_root /bin/cp "$remote_kernel" "$target_boot_mount/Image"
as_root /bin/cp "$remote_dtb" "$target_boot_mount/system.dtb"
as_root /bin/cp "$remote_ramdisk" "$target_boot_mount/ramdisk.cpio.gz.u-boot"
as_root /bin/sync

echo "Setting U-Boot env for trial boot from slot $target_slot"
as_root /usr/bin/fw_setenv active_slot "$target_slot"
as_root /usr/bin/fw_setenv upgrade_available 1
as_root /usr/bin/fw_setenv bootcount 0

echo "== updated-env =="
as_root /usr/bin/fw_printenv active_slot upgrade_available bootcount last_good_slot

if [[ "$reboot_after" == "1" ]]; then
  echo "Rebooting target"
  as_root /sbin/reboot
else
  echo "Deployment staged. Reboot with --reboot or run sudo reboot on the target."
fi
EOF
)"

run_remote() {
  ssh "${ssh_flags[@]}" "$ssh_dest" "$@"
}

run_control() {
  ssh "${control_ssh_flags[@]}" "$control_host" "$@"
}

copy_to_control() {
  scp "${control_ssh_flags[@]}" "$1" "$control_host:$2"
}

append_bash_array() {
  local array_name="$1"
  shift
  local opt
  for opt in "$@"; do
    printf '%s+=(%q %q)\n' "$array_name" "-o" "$opt"
  done
}

if [[ -n "$control_host" ]]; then
  control_run_dir="$control_dir/$board-$stamp"
  target_script="${control_run_dir}/target-deploy.sh"
  control_wrapper="${control_run_dir}/control-wrapper.sh"

  run_control "mkdir -p '$control_run_dir'"

  if (( ! verify_only && ! dry_run )); then
    copy_to_control "$rootfs_img" "$control_run_dir/rootfs.ext4"
    copy_to_control "$kernel_img" "$control_run_dir/Image"
    copy_to_control "$dtb_img" "$control_run_dir/system.dtb"
    copy_to_control "$ramdisk_img" "$control_run_dir/ramdisk.cpio.gz.u-boot"
  fi

  if (( verify_only || dry_run )); then
    target_payload="$remote_script_common"
  else
    target_payload="${remote_script_common}
${remote_deploy_tail}"
  fi
  run_control "cat > '$target_script'" <<<"$target_payload"

  {
    printf 'set -euo pipefail\n'
    printf 'target_dest=%q\n' "$ssh_dest"
    printf 'target_remote_dir=%q\n' "$remote_dir"
    printf 'control_run_dir=%q\n' "$control_run_dir"
    printf 'target_script=%q\n' "$target_script"
    printf 'mode=%q\n' "$([[ "$verify_only" -eq 1 ]] && echo verify || echo deploy)"
    printf 'target_slot_requested=%q\n' "$emmc_mode"
    printf 'dry_run=%q\n' "$dry_run"
    printf 'reboot_after=%q\n' "$reboot_after"
    printf 'target_ssh_flags=(-o BatchMode=yes)\n'
    append_bash_array target_ssh_flags "${ssh_options[@]}"
    cat <<'EOF'

if [[ "$mode" == "deploy" && "$dry_run" != "1" ]]; then
  ssh "${target_ssh_flags[@]}" "$target_dest" "mkdir -p '$target_remote_dir'"
  scp "${target_ssh_flags[@]}" "$control_run_dir/rootfs.ext4" "$target_dest:$target_remote_dir/rootfs.ext4"
  scp "${target_ssh_flags[@]}" "$control_run_dir/Image" "$target_dest:$target_remote_dir/Image"
  scp "${target_ssh_flags[@]}" "$control_run_dir/system.dtb" "$target_dest:$target_remote_dir/system.dtb"
  scp "${target_ssh_flags[@]}" "$control_run_dir/ramdisk.cpio.gz.u-boot" "$target_dest:$target_remote_dir/ramdisk.cpio.gz.u-boot"
fi

ssh "${target_ssh_flags[@]}" "$target_dest" \
  "mode='$mode' target_slot_requested='$target_slot_requested' dry_run='$dry_run' remote_dir='$target_remote_dir' reboot_after='$reboot_after' bash -s" \
  < "$target_script"
EOF
  } | run_control "cat > '$control_wrapper'"

  run_control "bash '$control_wrapper'"
  exit 0
fi

if (( verify_only || dry_run )); then
  run_remote \
    "mode=$([[ "$verify_only" -eq 1 ]] && echo verify || echo deploy) target_slot_requested=$(printf '%q' "$emmc_mode") dry_run=$dry_run bash -s" \
    <<<"$remote_script_common"
  exit 0
fi

run_remote "mkdir -p '$remote_dir'"
scp "${ssh_flags[@]}" "$rootfs_img" "$ssh_dest:$remote_dir/rootfs.ext4"
scp "${ssh_flags[@]}" "$kernel_img" "$ssh_dest:$remote_dir/Image"
scp "${ssh_flags[@]}" "$dtb_img" "$ssh_dest:$remote_dir/system.dtb"
scp "${ssh_flags[@]}" "$ramdisk_img" "$ssh_dest:$remote_dir/ramdisk.cpio.gz.u-boot"

run_remote \
  "mode=deploy target_slot_requested=$(printf '%q' "$emmc_mode") dry_run=0 remote_dir=$(printf '%q' "$remote_dir") reboot_after=$reboot_after bash -s" \
  <<<"${remote_script_common}
${remote_deploy_tail}"
