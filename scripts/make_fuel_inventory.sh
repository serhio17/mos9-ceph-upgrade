#!/bin/sh
set -e

list_nodes () {
	local fuel_role="$1"
	local ceph_role="$2"
	local inventory="$3"
	cat >> "$inventory" <<-EOF
	[$ceph_role]
	EOF
	fuel nodes | grep "$fuel_role" | tr -d ' ' | cut -d '|' -f 1,5 | \
		while read line; do
			IFS='|'
			set -- $line
			unset IFS
			echo "node-$1 ansible_host=$2"
		done >> "$inventory"
}

make_inventory() {
	local inventory="$1"
	list_nodes "controller" "mons" "${inventory}.tmp"
	list_nodes "ceph-osd" "osds" "${inventory}.tmp"
	list_nodes "compute" "clients" "${inventory}.tmp"	
	mv "${inventory}.tmp" "$inventory"
}

make_inventory "${1:-hosts}"
