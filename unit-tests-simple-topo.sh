#!/bin/bash
set -i
# Display commands and their arguments as they are executed.
set -x


function reinstall_vimc {
	rmdir /configfs/vimc/mdev/entities/*
	rmdir /configfs/vimc/mdev/links/*
	rmdir /configfs/vimc/mdev

	modprobe -vr vimc
	umount /configfs
	modprobe -v vimc
	mount -t configfs none /configfs
	echo "file drivers/media/platform/vimc/* +p" > /sys/kernel/debug/dynamic_debug/control
}

function simple_topo {
	# Creating the entities
	mkdir "/configfs/vimc/mdev/entities/vimc-sensor:sen"
	mkdir "/configfs/vimc/mdev/entities/vimc-debayer:deb"
	mkdir "/configfs/vimc/mdev/entities/vimc-scaler:sca"
	mkdir "/configfs/vimc/mdev/entities/vimc-capture:cap-sca"
	mkdir "/configfs/vimc/mdev/entities/vimc-capture:cap-sen"
	mkdir "/configfs/vimc/mdev/entities/vimc-capture:cap-deb"

	# Creating the links
	mkdir "/configfs/vimc/mdev/links/sen:0->deb:0"
	mkdir "/configfs/vimc/mdev/links/sen:1->cap-sen:0"
	mkdir "/configfs/vimc/mdev/links/deb:0->sca:0"
	mkdir "/configfs/vimc/mdev/links/deb:1->cap-deb:0"
	mkdir "/configfs/vimc/mdev/links/sca:0->cap-sca:0"
}

echo 15 > /proc/sys/kernel/printk
echo 1 > /configfs/vimc/mdev/hotplug

test_idx=0
echo "=========================================================================="
echo "Test $test_idx: remove the scaler and see that the device can't be plugged"
echo "=========================================================================="
((test_idx++))
reinstall_vimc
simple_topo || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
rmdir "/configfs/vimc/mdev/entities/vimc-sensor:sen"
echo 1 > /configfs/vimc/mdev/hotplug && exit 1

echo "=========================================================================="
echo "Test $test_idx: remove the scaler and see that the device can't be plugged"
echo "=========================================================================="
((test_idx++))
reinstall_vimc
simple_topo || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
rmdir "/configfs/vimc/mdev/entities/vimc-sensor:sen"
echo 1 > /configfs/vimc/mdev/hotplug && exit 1



