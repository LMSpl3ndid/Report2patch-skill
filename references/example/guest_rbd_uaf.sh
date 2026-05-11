#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_DIR="/root/rbd_add_uaf"
FAILSLAB_DIR="/sys/kernel/debug/failslab"
RBD_ADD_FILE="/sys/bus/rbd/add_single_major"

usage() {
  cat <<'EOF'
Usage:
  guest_rbd_uaf.sh setup
  guest_rbd_uaf.sh trigger [--start N] [--end N]
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$ARTIFACT_DIR/repro.log"
}

require_root() {
  [[ "$(id -u)" -eq 0 ]] || {
    echo "Run as root" >&2
    exit 1
  }
}

require_env() {
  : "${RBD_MON_ADDR:?missing RBD_MON_ADDR}"
  : "${RBD_POOL:?missing RBD_POOL}"
  : "${RBD_IMAGE:?missing RBD_IMAGE}"
  : "${RBD_USER:?missing RBD_USER}"
  : "${RBD_SECRET:?missing RBD_SECRET}"
}

ensure_artifacts() {
  mkdir -p "$ARTIFACT_DIR"
  : > "$ARTIFACT_DIR/repro.log"
}

ensure_debugfs() {
  if ! mount | grep -q "on /sys/kernel/debug type debugfs"; then
    mount -t debugfs none /sys/kernel/debug
  fi
}

ensure_rbd_ready() {
  if [[ ! -e /sys/bus/rbd ]]; then
    modprobe rbd || true
  fi

  [[ -e /sys/bus/rbd ]] || {
    echo "rbd sysfs bus is not available" >&2
    exit 1
  }
}

reset_failslab() {
  echo N > "$FAILSLAB_DIR/task-filter"
  echo 0 > "$FAILSLAB_DIR/probability"
  echo 1 > "$FAILSLAB_DIR/interval"
  echo 0 > "$FAILSLAB_DIR/space"
  echo 1 > "$FAILSLAB_DIR/times"
  echo 0 > "$FAILSLAB_DIR/verbose"
  echo N > "$FAILSLAB_DIR/ignore-gfp-wait"
  echo 0x0 > "$FAILSLAB_DIR/reject-start"
  echo 0x0 > "$FAILSLAB_DIR/reject-end"
  echo 0x0 > "$FAILSLAB_DIR/require-start"
  echo 0xffffffffffffffff > "$FAILSLAB_DIR/require-end"
}

find_add_disk_range() {
  local start_hex start end_hex
  start_hex="$(awk '$3 == "__add_disk" {print $1; exit}' /proc/kallsyms)"
  [[ -n "$start_hex" ]] || {
    echo "Unable to locate __add_disk in /proc/kallsyms" >&2
    exit 1
  }

  start=$((16#$start_hex))
  end_hex="$(printf '0x%x' $((start + 0x800)))"
  printf '0x%s %s\n' "$start_hex" "$end_hex"
}

setup_fault_injection() {
  local range start end
  range="$(find_add_disk_range)"
  start="${range%% *}"
  end="${range##* }"

  echo Y > "$FAILSLAB_DIR/task-filter"
  echo 100 > "$FAILSLAB_DIR/probability"
  echo 1 > "$FAILSLAB_DIR/interval"
  echo 1 > "$FAILSLAB_DIR/times"
  echo 0 > "$FAILSLAB_DIR/space"
  echo 2 > "$FAILSLAB_DIR/verbose"
  echo N > "$FAILSLAB_DIR/ignore-gfp-wait"
  echo "$start" > "$FAILSLAB_DIR/require-start"
  echo "$end" > "$FAILSLAB_DIR/require-end"

  log "failslab range set to ${start}-${end}"
}

cleanup_rbd_state() {
  if [[ -d /sys/bus/rbd/devices ]]; then
    for dev in /sys/bus/rbd/devices/*; do
      [[ -d "$dev" ]] || continue
      local id
      id="$(basename "$dev")"
      echo "$id" > /sys/bus/rbd/remove_single_major || true
    done
  fi
  modprobe -r rbd || true
  ensure_rbd_ready
}

map_once_with_failnth() {
  local nth="$1"
  local opts
  opts="name=${RBD_USER},secret=${RBD_SECRET}"
  bash -c "echo ${nth} > /proc/self/fail-nth; echo '${RBD_MON_ADDR} ${opts} ${RBD_POOL} ${RBD_IMAGE}' > '${RBD_ADD_FILE}'"
}

capture_logs() {
  dmesg > "$ARTIFACT_DIR/dmesg.txt" || true
  dmesg | tail -200 > "$ARTIFACT_DIR/kasan-tail.txt" || true
}

has_kasan() {
  dmesg | grep -q "KASAN:"
}

do_setup() {
  require_root
  require_env
  ensure_artifacts
  ensure_debugfs
  ensure_rbd_ready
  reset_failslab
  log "guest setup complete"
}

do_trigger() {
  local start_n=1
  local end_n=256

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --start) start_n="${2:-}"; shift 2 ;;
      --end) end_n="${2:-}"; shift 2 ;;
      *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
    esac
  done

  require_root
  require_env
  ensure_artifacts
  ensure_debugfs
  ensure_rbd_ready
  setup_fault_injection

  for nth in $(seq "$start_n" "$end_n"); do
    cleanup_rbd_state
    log "trying fail-nth=${nth}"
    if map_once_with_failnth "$nth" >>"$ARTIFACT_DIR/repro.log" 2>&1; then
      log "map command returned success at fail-nth=${nth}"
    else
      log "map command returned failure at fail-nth=${nth}"
    fi

    if has_kasan; then
      log "KASAN report detected at fail-nth=${nth}"
      printf '%s\n' "$nth" > "$ARTIFACT_DIR/fail-nth-hit.txt"
      capture_logs
      return 0
    fi
  done

  capture_logs
  log "no KASAN report observed in requested range"
  return 1
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    setup) do_setup "$@" ;;
    trigger) do_trigger "$@" ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
