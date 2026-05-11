# RBD `device_add_disk()` Error Path KASAN Reproducer

This directory contains a host/guest workflow for reproducing the
double-free / UAF candidate in `drivers/block/rbd.c` around:

- `err_out_cleanup_disk: rbd_free_disk(rbd_dev);`
- `err_out_image_lock: rbd_dev_device_release(rbd_dev);`

The reproducer keeps the real `rbd_add()` path intact, uses a real Ceph
backend, and relies on fault injection only to make `device_add_disk()`
fail inside `__add_disk()`.

## Target tree

- Kernel tree: `/home/gzl/linux`
- Guest rootfs: `/home/gzl/images/ubuntu-rootfs.raw`
- QEMU SSH forward: `localhost:10022`
- Guest root password: `root`

When this workflow is used through `report2patch`, keep host-side logs under the bug-specific `kasan_artifact_dir`.
For example, if `kasan_artifact_dir=/tmp/rbd_add_disk_uaf`, save pre-fix artifacts under `/tmp/rbd_add_disk_uaf/pre-fix` and post-fix artifacts under `/tmp/rbd_add_disk_uaf/post-fix`.

## Required kernel config

The following options must be enabled in `/home/gzl/linux/.config`:

- `CONFIG_KASAN=y`
- `CONFIG_DEBUG_INFO=y`
- `CONFIG_DEBUG_FS=y`
- `CONFIG_KPROBES=y`
- `CONFIG_KALLSYMS_ALL=y`
- `CONFIG_CEPH_LIB=y`
- `CONFIG_BLK_DEV_RBD=y`
- `CONFIG_FAULT_INJECTION=y`
- `CONFIG_FAILSLAB=y`
- `CONFIG_FAULT_INJECTION_DEBUG_FS=y`
- `CONFIG_FAULT_INJECTION_STACKTRACE_FILTER=y`

## Files

- `host_bootstrap_ceph.sh`
  Creates a single-node Ceph cluster with `cephadm`, prepares one loop-backed
  file, converts it into an LVM LV-backed OSD, creates a pool and a test RBD
  image, and exports guest-side mapping parameters.
- `host_start_qemu.sh`
  Boots the guest with the built kernel and the provided rootfs image.
- `guest_rbd_uaf.sh`
  Runs inside the guest. It configures `failslab`, maps the RBD image via
  `/sys/bus/rbd/add_single_major`, iterates `fail-nth`, and saves logs.
- `host_collect_logs.sh`
  Pulls the guest artifacts and `dmesg` back to the host through SSH.

## Host-side flow

### 1. Build the kernel

```bash
cd /home/gzl/linux
make -j"$(nproc)"
```

Expected artifacts:

- `/home/gzl/linux/arch/x86/boot/bzImage`
- `/home/gzl/linux/vmlinux`

### 2. Bootstrap single-node Ceph

Pick an explicit Ceph image tag. Example:

```bash
export CEPH_IMAGE=quay.io/ceph/ceph:v18.2.4
cd /home/gzl/linux/tools/testing/rbd_add_uaf
sudo ./host_bootstrap_ceph.sh \
  --ceph-image "$CEPH_IMAGE" \
  --cluster-dir /tmp/rbd-add-uaf-ceph \
  --pool rbd \
  --image uaf-test \
  --image-size 64M
```

This writes:

- `/tmp/rbd-add-uaf-ceph/ceph.conf`
- `/tmp/rbd-add-uaf-ceph/client.admin.keyring`
- `/tmp/rbd-add-uaf-ceph/guest.env`

`guest.env` contains the exact values consumed by the guest reproducer:

- `RBD_MON_ADDR`
- `RBD_POOL`
- `RBD_IMAGE`
- `RBD_USER`
- `RBD_SECRET`

The monitor address is written as the real host IP chosen during bootstrap,
for example `10.9.130.4:6789`.

### 3. Boot QEMU

```bash
cd /home/gzl/linux/tools/testing/rbd_add_uaf
./host_start_qemu.sh \
  --kernel /home/gzl/linux/arch/x86/boot/bzImage \
  --disk /home/gzl/images/ubuntu-rootfs.raw \
  --disk-format raw \
  --vmlinux /home/gzl/linux/vmlinux \
  --append "ip=dhcp printk.devkmsg=on panic=-1"
```

### 4. Copy the guest reproducer

```bash
scp -P 10022 -o StrictHostKeyChecking=no \
  ./guest_rbd_uaf.sh root@127.0.0.1:/root/
scp -P 10022 -o StrictHostKeyChecking=no \
  /tmp/rbd-add-uaf-ceph/guest.env root@127.0.0.1:/root/
```

Password: `root`

### 5. Run inside the guest

SSH into the guest:

```bash
ssh -p 10022 root@127.0.0.1
```

Then:

```bash
source /root/guest.env
chmod +x /root/guest_rbd_uaf.sh
/root/guest_rbd_uaf.sh setup
/root/guest_rbd_uaf.sh trigger --start 1 --end 256
```

Artifacts are written to:

- `/root/rbd_add_uaf/`

Important files:

- `/root/rbd_add_uaf/repro.log`
- `/root/rbd_add_uaf/dmesg.txt`
- `/root/rbd_add_uaf/kasan-tail.txt`

### 6. Pull the logs back to the host

```bash
cd /home/gzl/linux/tools/testing/rbd_add_uaf
./host_collect_logs.sh \
  --out-dir /tmp/rbd_add_disk_uaf/pre-fix \
  --ssh-port 10022
```

After the fix is applied and the runtime workflow is re-run, collect the second run into the matching post-fix directory:

```bash
cd /home/gzl/linux/tools/testing/rbd_add_uaf
./host_collect_logs.sh \
  --out-dir /tmp/rbd_add_disk_uaf/post-fix \
  --ssh-port 10022
```

## Guest-side injection strategy

The guest reproducer:

1. Mounts `debugfs`
2. Resets `failslab`
3. Uses `/proc/kallsyms` to find `__add_disk`
4. Sets `failslab/require-start` and `failslab/require-end` to the
   `__add_disk()` region
5. Executes the mapping write in a short-lived shell that first writes to
   `/proc/self/fail-nth`

The goal is to fail an allocation inside `device_add_disk()` after
`rbd_init_disk()` has already succeeded, so the error path reaches:

```c
err_out_cleanup_disk:
	rbd_free_disk(rbd_dev);
err_out_image_lock:
	rbd_dev_image_unlock(rbd_dev);
	rbd_dev_device_release(rbd_dev);
```

`rbd_dev_device_release()` calls `rbd_free_disk()` again, which is what KASAN
is expected to report.

## Expected signal

The relevant KASAN report should include frames similar to:

- `rbd_free_disk`
- `rbd_dev_device_release`
- `blk_mq_free_tag_set`
- `blk_mq_free_map_and_rqs`
- `blk_mq_free_rq_map`
- `blk_mq_free_tags`
- `kfree`

## Observed successful run

This workflow was executed on the current workspace on April 9, 2026.

- Built kernel artifacts:
  `/home/gzl/linux/arch/x86/boot/bzImage`
  `/home/gzl/linux/vmlinux`
- Ceph image:
  `quay.io/ceph/ceph:v18.2.4`
- Bootstrap cluster fsid:
  `8669a438-341b-11f1-b8df-a723005abded`
- Guest monitor address:
  `10.9.130.4:6789`
- `fail-nth` hit:
  `4`
- Captured host-side artifacts:
  `/tmp/rbd-add-uaf-artifacts/`

The reproduced KASAN path included:

- `__add_disk`
- `do_rbd_add`
- `__blk_mq_free_map_and_rqs`
- `blk_mq_free_tag_set`

The trigger log recorded:

```text
[2026-04-09 14:24:17] trying fail-nth=4
[2026-04-09 14:24:17] map command returned failure at fail-nth=4
[2026-04-09 14:24:17] KASAN report detected at fail-nth=4
```

The relevant KASAN report is stored in:

- `/tmp/rbd-add-uaf-artifacts/kasan-tail.txt`
- `/tmp/rbd-add-uaf-artifacts/dmesg.txt`

## References

- Ceph container image guidance:
  https://docs.ceph.com/en/pacific/install/containers/
- cephadm single-host bootstrap:
  https://docs.ceph.com/en/tentacle/cephadm/install/
