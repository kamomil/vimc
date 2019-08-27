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

function stream_sen {
	media-ctl -d platform:vimc -V '"sen":1[fmt:SBGGR8_1X8/640x480]' || exit 1
	v4l2-ctl -z platform:vimc -d "sen-cap" -v width=1920,height=1440
	v4l2-ctl --stream-mmap --stream-count=100 -d /dev/video1
}

function stream_deb {
	media-ctl -d platform:vimc -V '"sen":0[fmt:SBGGR8_1X8/640x480]' || exit 1
	media-ctl -d platform:vimc -V '"deb":1[fmt:SBGGR8_1X8/640x480]' || exit 1
	v4l2-ctl -z platform:vimc -d "sen-cap" -v width=1920,height=1440
	v4l2-ctl -z platform:vimc -d "deb-cap" -v pixelformat=BA81
	v4l2-ctl --stream-mmap --stream-count=100 -d /dev/video2
}

function stream_sca {
	media-ctl -d platform:vimc -V '"sen":0[fmt:SBGGR8_1X8/640x480]' || exit 1
	media-ctl -d platform:vimc -V '"deb":0[fmt:SBGGR8_1X8/640x480]' || exit 1
	media-ctl -d platform:vimc -V '"sca":1[fmt:SBGGR8_1X8/640x480]' || exit 1
	v4l2-ctl -z platform:vimc -d "sen-cap" -v width=1920,height=1440
	v4l2-ctl -z platform:vimc -d "deb-cap" -v pixelformat=BA81
	v4l2-ctl -z platform:vimc -d "sca-cap" -v pixelformat=BA81
	v4l2-ctl --stream-mmap --stream-count=100 -d /dev/video3
}


echo 15 > /proc/sys/kernel/printk
echo 1 > /configfs/vimc/mdev/hotplug

test_idx=1
echo "===================================================================================="
echo "Test $test_idx: make sure that the deivce can be plugged and all captures can stream"
echo "===================================================================================="
((test_idx++))
reinstall_vimc
simple_topo || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
#TODO - this probably does not work
stream_sen || exit 1
stream_deb || exit 1
stream_sca || exit 1

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
echo "Test $test_idx: remove the scaler and the two links [debayer -> scaler],[scaler->vimc-cpature]"
echo "and make sure that the device CAN'T be plugged (since the capture of the scaler is not not linked to any pipe)"
echo "=========================================================================="
((test_idx++))
reinstall_vimc
simple_topo || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
rmdir "/configfs/vimc/mdev/entities/vimc-scaler:sca"
rmdir "/configfs/vimc/mdev/links/deb:0->sca:0"
rmdir "/configfs/vimc/mdev/links/sca:1->cap-sca:0"
echo 1 > /configfs/vimc/mdev/hotplug && exit 1

echo "=========================================================================="
echo "Test $test_idx: remove the scaler and create it again and make sure the device can be plugged and stream"
echo "=========================================================================="
((test_idx++))
reinstall_vimc
simple_topo || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
rmdir "/configfs/vimc/mdev/entities/vimc-scaler:sca"
echo 1 > /configfs/vimc/mdev/hotplug && exit 1
mkdir "/configfs/vimc/mdev/entities/vimc-scaler:sca"
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
stream_sen || exit 1
stream_deb || exit 1
stream_sca || exit 1

echo "=========================================================================="
echo "Test $test_idx: remove the scaler and the scaler's capture and any link they particpate. Make"
echo "sure that the device can be plug, and the capture nodes of the sensor and the debayer can be streamed."
echo "=========================================================================="
((test_idx++))
reinstall_vimc
simple_topo || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
rmdir "/configfs/vimc/mdev/entities/vimc-scaler:sca"
rmdir "/configfs/vimc/mdev/links/deb:1->sca:0"
rmdir "/configfs/vimc/mdev/entities/vimc-capture:cap-sca"
rmdir "/configfs/vimc/mdev/links/sca:1->cap-sca:0"
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
stream_sen || exit 1
stream_deb || exit 1
stream_sca && exit 1


