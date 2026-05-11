#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  host_bootstrap_ceph.sh --ceph-image <image:tag> [options]

Required:
  --ceph-image <image:tag>  Explicit Ceph container image tag

Optional:
  --cluster-dir <path>      State directory (default: /tmp/rbd-add-uaf-ceph)
  --mon-ip <ip>             Monitor IP to bootstrap with
  --pool <name>             Pool name (default: rbd)
  --image <name>            RBD image name (default: uaf-test)
  --image-size <size>       RBD image size (default: 64M)
  --osd-loop-file <path>    Backing file for loop OSD
  --osd-loop-size <size>    Loop OSD file size (default: 8G)
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

CEPH_IMAGE=""
CLUSTER_DIR="/tmp/rbd-add-uaf-ceph"
MON_IP=""
POOL="rbd"
IMAGE="uaf-test"
IMAGE_SIZE="64M"
OSD_LOOP_FILE=""
OSD_LOOP_SIZE="8G"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ceph-image) CEPH_IMAGE="${2:-}"; shift 2 ;;
    --cluster-dir) CLUSTER_DIR="${2:-}"; shift 2 ;;
    --mon-ip) MON_IP="${2:-}"; shift 2 ;;
    --pool) POOL="${2:-}"; shift 2 ;;
    --image) IMAGE="${2:-}"; shift 2 ;;
    --image-size) IMAGE_SIZE="${2:-}"; shift 2 ;;
    --osd-loop-file) OSD_LOOP_FILE="${2:-}"; shift 2 ;;
    --osd-loop-size) OSD_LOOP_SIZE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$CEPH_IMAGE" ]] || { echo "--ceph-image is required" >&2; exit 1; }

need_cmd curl
need_cmd docker
need_cmd python3
need_cmd losetup
need_cmd truncate
need_cmd pvcreate
need_cmd vgcreate
need_cmd lvcreate
need_cmd ip
need_cmd awk
need_cmd sed
need_cmd sudo

mkdir -p "$CLUSTER_DIR"
CEPHADM=""
OSD_LOOP_FILE="${OSD_LOOP_FILE:-$CLUSTER_DIR/osd-loop.img}"
OSD_LOOP_DEV_FILE="$CLUSTER_DIR/osd-loop.dev"
OSD_VG_NAME="cephvg_rbd_uaf"
OSD_LV_NAME="osd0"
GUEST_ENV="$CLUSTER_DIR/guest.env"
CEPH_CONF="$CLUSTER_DIR/ceph.conf"
KEYRING="$CLUSTER_DIR/client.admin.keyring"

if [[ -z "$MON_IP" ]]; then
  MON_IP="$(ip -4 route get 1.1.1.1 | awk '/src/ {for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}')"
fi

if [[ -z "$MON_IP" ]]; then
  echo "Unable to detect --mon-ip automatically" >&2
  exit 1
fi

if command -v cephadm >/dev/null 2>&1; then
  CEPHADM="$(command -v cephadm)"
else
  CEPHADM="$CLUSTER_DIR/cephadm"
  if [[ ! -x "$CEPHADM" ]]; then
    release="${CEPH_IMAGE##*:}"
    release="${release#v}"
    curl --fail --location \
      "https://download.ceph.com/rpm-${release}/el9/noarch/cephadm" \
      --output "$CEPHADM"
    chmod +x "$CEPHADM"
  fi
fi

sudo mkdir -p /etc/ceph

sudo CEPHADM_IMAGE="$CEPH_IMAGE" python3 "$CEPHADM" --image "$CEPH_IMAGE" bootstrap \
  --mon-ip "$MON_IP" \
  --allow-fqdn-hostname \
  --skip-mon-network \
  --single-host-defaults \
  --skip-dashboard \
  --skip-monitoring-stack \
  --skip-firewalld \
  --cleanup-on-failure \
  --output-config "$CEPH_CONF" \
  --output-keyring "$KEYRING"

if [[ ! -f "$OSD_LOOP_FILE" ]]; then
  truncate -s "$OSD_LOOP_SIZE" "$OSD_LOOP_FILE"
fi

LOOPDEV="$(sudo losetup --find --show "$OSD_LOOP_FILE")"
echo "$LOOPDEV" > "$OSD_LOOP_DEV_FILE"

if ! lvs "${OSD_VG_NAME}/${OSD_LV_NAME}" >/dev/null 2>&1; then
  sudo pvcreate -ff -y "$LOOPDEV"
  sudo vgcreate "$OSD_VG_NAME" "$LOOPDEV"
  sudo lvcreate -l 100%FREE -n "$OSD_LV_NAME" "$OSD_VG_NAME"
fi

OSD_LV_PATH="/dev/${OSD_VG_NAME}/${OSD_LV_NAME}"

sudo CEPHADM_IMAGE="$CEPH_IMAGE" python3 "$CEPHADM" --image "$CEPH_IMAGE" shell -- \
  ceph orch daemon add osd "$(hostname):${OSD_LV_PATH}" || true

sudo CEPHADM_IMAGE="$CEPH_IMAGE" python3 "$CEPHADM" --image "$CEPH_IMAGE" shell -- \
  ceph osd pool create "$POOL" 8 || true
sudo CEPHADM_IMAGE="$CEPH_IMAGE" python3 "$CEPHADM" --image "$CEPH_IMAGE" shell -- \
  ceph config set mon mon_allow_pool_size_one true || true
sudo CEPHADM_IMAGE="$CEPH_IMAGE" python3 "$CEPHADM" --image "$CEPH_IMAGE" shell -- \
  ceph osd pool set "$POOL" size 1 || true
sudo CEPHADM_IMAGE="$CEPH_IMAGE" python3 "$CEPHADM" --image "$CEPH_IMAGE" shell -- \
  ceph osd pool set "$POOL" min_size 1 || true
sudo CEPHADM_IMAGE="$CEPH_IMAGE" python3 "$CEPHADM" --image "$CEPH_IMAGE" shell -- \
  rbd pool init "$POOL" || true
sudo CEPHADM_IMAGE="$CEPH_IMAGE" python3 "$CEPHADM" --image "$CEPH_IMAGE" shell -- \
  rbd create "${POOL}/${IMAGE}" --size "$IMAGE_SIZE" || true

RBD_SECRET="$(sudo CEPHADM_IMAGE="$CEPH_IMAGE" python3 "$CEPHADM" --image "$CEPH_IMAGE" shell -- ceph-authtool -p /etc/ceph/ceph.client.admin.keyring)"

cat > "$GUEST_ENV" <<EOF
export RBD_MON_ADDR="${MON_IP}:6789"
export RBD_POOL="${POOL}"
export RBD_IMAGE="${IMAGE}"
export RBD_USER="admin"
export RBD_SECRET="${RBD_SECRET}"
EOF

cat <<EOF
[INFO] Ceph bootstrap state: ${CLUSTER_DIR}
[INFO] Monitor IP: ${MON_IP}
[INFO] Pool/Image: ${POOL}/${IMAGE}
[INFO] Guest env file: ${GUEST_ENV}
[INFO] Loop device: ${LOOPDEV}
[INFO] OSD LV path: ${OSD_LV_PATH}
EOF
