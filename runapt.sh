#!/bin/sh
set -e

if [ "`id -u`" != '0' ]; then
	exec sudo $0 $@
fi

BASE_IMAGE=rbd/trusty-server-cloudimg-amd64-disk1.img.rootfs
BASE_SNAP=start
IMAGE_FEATURES=1 # layering
CEPHX_USER_ID=admin
CEPHX_KEYRING="/etc/ceph/ceph.client.${CEPHX_USER_ID}.keyring"
MNT_DIR=/tmp/mnt

set -x

mkdir -p -m 755 $MNT_DIR

cleanup () {
	local mntpt="$1"
	local img="${mntpt##${MNT_DIR}}"
	for fs in /proc /dev /; do
		if mountpoint -q "${mntpt}${fs}"; then
			umount "${mntpt}${fs}"
		fi
	done
	if [ -L "/dev/rbd/$img" ]; then
		rbd unmap "/dev/rbd/$img"
	fi
}

cleanup_all () {
	for dir in `find $MNT_DIR -maxdepth 2 -mindepth 2 -type d`; do
		cleanup $dir
	done
	rbd showmapped | awk "/${BASE_IMAGE##*/}/ { print \$2 \"/\" \$3 }" | \
	while read img; do
		rbd unmap "/dev/rbd/$img"
	done
}

trap cleanup_all TERM QUIT


clone_base () {
	local child="$1"
	rbd rm "$child" || true
	rbd clone --image-features $IMAGE_FEATURES \
		"${BASE_IMAGE}@${BASE_SNAP}" \
		"$child"
}

map_and_mount () {
	local img="$1"
	rbd map --id "$CEPHX_USER_ID" --keyring "$CEPHX_KEYRING" "$img"
	if ! e2fsck -f -p /dev/rbd/$img; then
		echo "RBD image ${img}: unexpected filesystem inconsistency" >&2
		exit 1
	fi
	mkdir -p "/$MNT_DIR/$img"
	mount -t ext4 -o rw,data=ordered,noatime,nodiratime,errors=remount-ro "/dev/rbd/$img" "${MNT_DIR}/$img"
}

copy_resolv_conf () {
	local dst="$1"
	local dst_conf="$dst/etc/resolv.conf"
	local dst_conf_real="$dst_conf"
	if [ -L "$dst_conf" ] && [ -z "`readlink -f \"$dst_conf\"`" ]; then
		dst_conf_real=`readlink -m "$dst_conf"`
	fi
	if [ ! -d "${dst_conf_real%/*}" ]; then
		mkdir -p -m755 "${dst_conf_real%/*}"
	fi
	cat /etc/resolv.conf > "$dst_conf_real"
}


copy_configs () {
	local dst="$1"
	local mirror="${2:-http://cz.archive.ubuntu.com/ubuntu}"
	local security="${3:-http://security.ubuntu.com/ubuntu}"
	local os_release="${4:-trusty}"
	# XXX: Ubuntu system deployed by fuel has empty sources.list
	cat > "$dst/etc/apt/sources.list" <<-EOF
	deb ${mirror} ${os_release} main universe multiverse restricted
	deb ${mirror} ${os_release}-updates main universe multiverse restricted
	deb ${security} ${os_release}-security main universe multiverse restricted
	EOF
	copy_resolv_conf "$dst"
}

bind_mount_virtfs () {
	local dst="$1"
	for fs in /proc /dev; do
		if ! mountpoint -q "${dst}${fs}"; then
			mount -o bind "${fs}" "${dst}${fs}"
		fi
	done
}

dist_upgrade () {
	local root="$1"
	chroot "$root" apt-get update
	chroot "$root" /usr/bin/env \
		LC_ALL=C \
		DEBIAN_FRONTEND=noninteractive \
		DEBCONF_NONINTERACTIVE_SEEN=true \
		apt-get dist-upgrade -y || true
}

run_once () {
	local img="$1"
	local mntpt="$MNT_DIR/$img"
	clone_base "$img"
	map_and_mount "$img"
	copy_configs "$mntpt"
	bind_mount_virtfs "$mntpt"
	dist_upgrade "$mntpt"
	cleanup "$mntpt"
}

main () {
	local img
	local short_hostname
	short_hostname=`hostname`
	short_hostname="${short_hostname%%.*}"

	cleanup_all
	for N in `seq 1 1000`; do
		img="${BASE_IMAGE}_${short_hostname}_${N}"
		run_once "$img"
	done
}

main

