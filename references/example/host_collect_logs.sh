#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  host_collect_logs.sh [options]

Optional:
  --ssh-port <port>   SSH forwarded port (default: 10022)
  --out-dir <path>    Output directory (default: /tmp/rbd-add-uaf-artifacts)
EOF
}

SSH_PORT=10022
OUT_DIR="/tmp/rbd-add-uaf-artifacts"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-port) SSH_PORT="${2:-}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

mkdir -p "$OUT_DIR"

if command -v sshpass >/dev/null 2>&1; then
  sshpass -p root scp -P "$SSH_PORT" -o StrictHostKeyChecking=no -r \
    root@127.0.0.1:/root/rbd_add_uaf "$OUT_DIR/"
else
  echo "[INFO] sshpass not found; falling back to interactive scp"
  scp -P "$SSH_PORT" -o StrictHostKeyChecking=no -r \
    root@127.0.0.1:/root/rbd_add_uaf "$OUT_DIR/"
fi

echo "[INFO] Logs copied to $OUT_DIR"
