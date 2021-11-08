#!/bin/bash

lava_result() {
	reason=$1
	result=$2
	stop_session=$3

	lava-test-case "$reason" --result "$result"
	[ "$stop_session" = 'yes' ] && lava-test-raise "$reason" && exit 1
}

find_vland_iface() {
	# lv must match lava vlan name
	lv='vlan_one'
	pattern=$(lava-vland-names | awk -F ',' -v vlan=$lv '$0 ~ vlan {print $2}' | awk -F '\' '{print $1}')
	pattern=$(printf '%s' "$pattern" | sed 's/[.[(+)]/\\&/g')

	iface_str=$(lava-vland-self | awk -v pat="$pattern" 'match($0,pat){print substr($0,RSTART,50)}')
	mac=$(echo $iface_str | awk -F ',' '{print $2}')
	for i in $(ls /sys/class/net/); do
		new_mac=$(cat /sys/class/net/"$i"/address)
		[ "$new_mac" == "$mac" ] && iface="$i" && break
	done
	echo $iface
}
