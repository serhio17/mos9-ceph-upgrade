#!/bin/sh
set -e
# Create RBD image, make ext4 filesystem, mount, run fio randwrite test
MYDIR="${0%/*}"

IMG="rbd/rbd_fio_`hostname`.img"
IMG_SIZE=32  # GB
nr_osd_nodes=3
BLOCK_SIZES="4 64" # KB
NUM_JOBS=8
IMAGE_FEATURES=1 # layering
DURATION="${1:-300}"
test_file_size="$(((IMG_SIZE*1024)/(NUM_JOBS*2)))M"

prepare () {
	rbd create --image-features $IMAGE_FEATURES --size="$((IMG_SIZE*1024))" "$IMG"
	rbd map --id admin --keyring /etc/ceph/ceph.client.admin.keyring "$IMG"
	mke2fs -t ext4 -b 4096 "/dev/rbd/$IMG"
	mount -t ext4 -o rw,data=ordered,noatime,nodiratime,nodev,nosuid,errors=remount-ro "/dev/rbd/$IMG" /mnt
}

cleanup () {
	cd /
	set +e
	if mountpoint -q /mnt; then
		umount /mnt
	fi
	if [ -e "/dev/rbd/$IMG" ]; then
		rbd unmap "/dev/rbd/$IMG"
	fi
	rbd remove "$IMG"
}

trap cleanup EXIT INT QUIT

prepare
cd /mnt

for block_size in $BLOCK_SIZES; do
	rm -f randwrite*
	fio --name=randwrite \
		--ioengine=libaio \
		--iodepth=$((nr_osd_nodes+2)) \
		--rw=randwrite \
		--bs=${block_size}k \
		--direct=1 \
		--size="$(((IMG_SIZE*1024)/(2*NUM_JOBS)))M" \
		--numjobs=$NUM_JOBS \
		--runtime=${DURATION} \
		--group_reporting
done

