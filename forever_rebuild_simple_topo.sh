#!/bin/bash
source ./functions.sh

while true
do
	reinstall_vimc
	simple_topo mdev
	echo 1 > /configfs/vimc/mdev/hotplug
	sleep 10
done

