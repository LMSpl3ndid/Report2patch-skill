#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  host_start_qemu.sh --kernel <bzImage> --disk <guest.img> [options]

Required:
  --kernel <path>        Guest kernel bzImage
  --disk <path>          Guest disk image

Optional:
  --vmlinux <path>       Uncompressed vmlinux path
  --memory <MB>          Guest memory in MB (default: 4096)
  --cpus <N>             vCPU count (default: 4)
  --ssh-forward <port>   Host forwarded SSH port (default: 10022)
  --root-dev <path>      Root device passed to guest (default: /dev/vda)
  --disk-format <fmt>    auto|qcow2|raw (default: auto)
  --append <cmdline>     Extra kernel cmdline
  --no-pause             Do not start QEMU with -S
  --no-kvm               Disable KVM acceleration
EOF
}

KERNEL=""
DISK=""
VMLINUX=""
MEMORY_MB=4096
CPUS=4
SSH_FWD=10022
ROOT_DEV="/dev/vda"
DISK_FORMAT="auto"
EXTRA_APPEND=""
USE_KVM=1
PAUSE_AT_START=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kernel) KERNEL="${2:-}"; shift 2 ;;
    --disk) DISK="${2:-}"; shift 2 ;;
    --vmlinux) VMLINUX="${2:-}"; shift 2 ;;
    --memory) MEMORY_MB="${2:-}"; shift 2 ;;
    --cpus) CPUS="${2:-}"; shift 2 ;;
    --ssh-forward) SSH_FWD="${2:-}"; shift 2 ;;
    --root-dev) ROOT_DEV="${2:-}"; shift 2 ;;
    --disk-format) DISK_FORMAT="${2:-}"; shift 2 ;;
    --append) EXTRA_APPEND="${2:-}"; shift 2 ;;
    --no-pause) PAUSE_AT_START=0; shift ;;
    --no-kvm) USE_KVM=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$KERNEL" || -z "$DISK" ]]; then
  echo "--kernel and --disk are required" >&2
  exit 1
fi

for path in "$KERNEL" "$DISK"; do
  [[ -f "$path" ]] || { echo "Missing file: $path" >&2; exit 1; }
done

if [[ -n "$VMLINUX" && ! -f "$VMLINUX" ]]; then
  echo "Missing vmlinux: $VMLINUX" >&2
  exit 1
fi

detect_disk_format() {
  local disk_path="$1"
  if [[ "$DISK_FORMAT" != "auto" ]]; then
    echo "$DISK_FORMAT"
    return 0
  fi

  if command -v qemu-img >/dev/null 2>&1; then
    local probed
    probed="$(qemu-img info --output=json "$disk_path" 2>/dev/null | sed -n 's/.*"format": "\([^"]\+\)".*/\1/p' | head -n1)"
    if [[ "$probed" == "qcow2" || "$probed" == "raw" ]]; then
      echo "$probed"
      return 0
    fi
  fi

  case "$disk_path" in
    *.qcow2) echo "qcow2" ;;
    *) echo "raw" ;;
  esac
}

QEMU_DISK_FORMAT="$(detect_disk_format "$DISK")"

ACCEL_ARGS=()
CPU_ARGS=("-cpu" "max")
if [[ "$USE_KVM" -eq 1 ]]; then
  ACCEL_ARGS=("-enable-kvm")
  CPU_ARGS=("-cpu" "host")
fi

PAUSE_ARGS=()
if [[ "$PAUSE_AT_START" -eq 1 ]]; then
  PAUSE_ARGS=(-S)
fi

BASE_APPEND="console=ttyS0,115200 ignore_loglevel nokaslr root=${ROOT_DEV} rw"
if [[ -n "$EXTRA_APPEND" ]]; then
  BASE_APPEND+=" $EXTRA_APPEND"
fi

cat <<EOF
[INFO] Guest SSH forwarded to localhost:${SSH_FWD}
[INFO] Root device: ${ROOT_DEV}
[INFO] Disk format: ${QEMU_DISK_FORMAT}
[INFO] Cmdline: ${BASE_APPEND}
[INFO] vmlinux: ${VMLINUX:-not provided}
EOF

exec qemu-system-x86_64 \
  -machine q35 \
  "${ACCEL_ARGS[@]}" \
  "${CPU_ARGS[@]}" \
  -m "$MEMORY_MB" \
  -smp "$CPUS" \
  -nographic \
  -kernel "$KERNEL" \
  -append "$BASE_APPEND" \
  -drive "file=$DISK,if=virtio,format=${QEMU_DISK_FORMAT}" \
  -netdev "user,id=n1,hostfwd=tcp::${SSH_FWD}-:22" \
  -device virtio-net-pci,netdev=n1 \
  -s \
  "${PAUSE_ARGS[@]}"
