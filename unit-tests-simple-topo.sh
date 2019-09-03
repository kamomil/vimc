#!/bin/bash
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
	# This produce to much debugs when streaming on debayer and scaler
	# echo "file drivers/media/platform/vimc/* +p" > /sys/kernel/debug/dynamic_debug/control
	# echo "file drivers/media/mc/* +p" > /sys/kernel/debug/dynamic_debug/control
}

# we set all links to be enabled and immutable
# therefore, when streaming we should make sure that
# so, if trying to stream the sensor capture, we should
# still make sure that also the formats in all other links match

VIDSCA=/dev/video2
VIDSEN=/dev/video1
VIDDEB=/dev/video0
STRM_CNT=10
# generates the v4l-ctl streaming output "<<<<<<" ...
STRM_OUT=$(printf '<%.0s' `seq $STRM_CNT`)

function simple_topo {
	# Creating the entities
	mkdir "/configfs/vimc/mdev"
	mkdir "/configfs/vimc/mdev/entities/vimc-sensor:sen"
	mkdir "/configfs/vimc/mdev/entities/vimc-debayer:deb"
	mkdir "/configfs/vimc/mdev/entities/vimc-scaler:sca"
	mkdir "/configfs/vimc/mdev/entities/vimc-capture:cap-sca" #/dev/video2
	mkdir "/configfs/vimc/mdev/entities/vimc-capture:cap-sen" #/dev/video1
	mkdir "/configfs/vimc/mdev/entities/vimc-capture:cap-deb" #/dev/video0

	# Creating the links
	mkdir "/configfs/vimc/mdev/links/sen:0->deb:0"
	# 1 = enable, 2=immutable, 1|2=3
	echo 3 > "/configfs/vimc/mdev/links/sen:0->deb:0/flags"
	mkdir "/configfs/vimc/mdev/links/deb:1->sca:0"
	echo 3 > "/configfs/vimc/mdev/links/deb:1->sca:0/flags"

	mkdir "/configfs/vimc/mdev/links/sen:0->cap-sen:0"
	echo 3 > "/configfs/vimc/mdev/links/sen:0->cap-sen:0/flags"
	mkdir "/configfs/vimc/mdev/links/deb:1->cap-deb:0"
	echo 3 > "/configfs/vimc/mdev/links/deb:1->cap-deb:0/flags"
	mkdir "/configfs/vimc/mdev/links/sca:1->cap-sca:0"
	echo 3 > "/configfs/vimc/mdev/links/sca:1->cap-sca:0/flags"
}


function configure_all_formats {
	media-ctl -d platform:vimc -V '"sen":0[fmt:SBGGR8_1X8/640x480]'
	media-ctl -d platform:vimc -V '"deb":0[fmt:SBGGR8_1X8/640x480]'
	# This is actually the default and the only supported format for deb:1
	# see `v4l2-ctl -d /dev/v4l-subdev1 --list-subdev-mbus 1`
	media-ctl -d platform:vimc -V '"deb":1[fmt:RGB888_1X24/640x480]'
	media-ctl -d platform:vimc -V '"sca":0[fmt:RGB888_1X24/640x480]'
	media-ctl -d platform:vimc -V '"sca":1[fmt:RGB888_1X24/640x480]'
	v4l2-ctl -z platform:vimc -d "cap-sen" -v pixelformat=BA81
	v4l2-ctl -z platform:vimc -d "cap-deb" -v pixelformat=RGB3
	#The scaler scales times 3, so need to set its capture accordingly
	v4l2-ctl -z platform:vimc -d "cap-sca" -v pixelformat=RGB3,width=1920,height=1440
}

echo 15 > /proc/sys/kernel/printk

test_idx=1
echo "===================================================================================="
echo "Test $test_idx: make sure that the deivce can be plugged and all captures can stream"
echo "===================================================================================="
((test_idx++))
reinstall_vimc
simple_topo || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
configure_all_formats
out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSEN 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sen failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDDEB 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming deb failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSCA 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sca failed"; exit; fi

media-ctl -d0 --print-dot > vmpath/simle.dot
media-ctl -d0 --print-dot | dot -Tps -o vmpath/simle.ps


echo "=========================================================================="
echo "Test $test_idx: remove the scaler and see that the device can't be plugged"
echo "=========================================================================="
((test_idx++))
reinstall_vimc
simple_topo || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
rmdir "/configfs/vimc/mdev/entities/vimc-sensor:sen" || exit 1
echo 1 > /configfs/vimc/mdev/hotplug && exit 1

echo "=========================================================================="
echo "Test $test_idx: remove the scaler and the two links [debayer -> scaler],[scaler->vimc-cpature]"
echo "and make sure that the cap-sca can't be streamed and that the the other captures can"
echo "=========================================================================="
((test_idx++))
reinstall_vimc
simple_topo || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
rmdir "/configfs/vimc/mdev/entities/vimc-scaler:sca" || exit 1
rmdir "/configfs/vimc/mdev/links/deb:1->sca:0" || exit 1
rmdir "/configfs/vimc/mdev/links/sca:1->cap-sca:0" || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
configure_all_formats
out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSEN 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sen failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDDEB 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming deb failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSCA 2>&1)
if [ "$out" == $STRM_OUT ]; then echo "streaming sca DID NOT fail (it should have)"; exit; fi

echo "=========================================================================="
echo "Test $test_idx: remove the scaler and create it again and make sure the device can be plugged and stream"
echo "=========================================================================="
((test_idx++))
reinstall_vimc
simple_topo || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
rmdir "/configfs/vimc/mdev/entities/vimc-scaler:sca" || exit 1
echo 1 > /configfs/vimc/mdev/hotplug && exit 1
mkdir "/configfs/vimc/mdev/entities/vimc-scaler:sca" || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
configure_all_formats
out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSEN 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sen failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDDEB 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming deb failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSCA 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sca failed"; exit; fi

echo "=========================================================================="
echo "Test $test_idx: remove the scaler and the scaler's capture and any link they particpate. Make"
echo "sure that the device can be plug, and the capture nodes of the sensor and the debayer can be streamed."
echo "=========================================================================="
((test_idx++))
reinstall_vimc
simple_topo || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
rmdir "/configfs/vimc/mdev/entities/vimc-scaler:sca" || exit 1
rmdir "/configfs/vimc/mdev/links/deb:1->sca:0" || exit 1
rmdir "/configfs/vimc/mdev/entities/vimc-capture:cap-sca" || exit 1
rmdir "/configfs/vimc/mdev/links/sca:1->cap-sca:0" || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
configure_all_formats
out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSEN 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sen failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDDEB 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming deb failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSCA 2>&1)
if [ "$out" == $STRM_OUT ]; then echo "streaming sca DID NOT fail (it should have)"; exit; fi

