#!/bin/bash
# Display commands and their arguments as they are executed.
set -x

function reinstall_vimc {
	find /configfs/ -name "pad:sink*" -exec unlink {} \;
	find /configfs/ -name "to-*" -exec rmdir {} \;
	rmdir /configfs/vimc/mdev/*
	rmdir /configfs/vimc/mdev
	rmdir /configfs/vimc/mdev2/*
	rmdir /configfs/vimc/mdev2

	modprobe -vr vimc
	umount /configfs
	modprobe -v vimc
	mount -t configfs none /configfs
	# This produce to much debugs when streaming on debayer and scaler
	# echo "file drivers/media/platform/vimc/* +p" > /sys/kernel/debug/dynamic_debug/control
	# echo "file drivers/media/mc/* +p" > /sys/kernel/debug/dynamic_debug/control
	echo "file drivers/media/platform/vimc/vimc-core.c +p" > /sys/kernel/debug/dynamic_debug/control
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

function simpler_topo {
	echo "start simple topo"
	# Creating the entities
	mkdir "/configfs/vimc/mdev2"
	mkdir "/configfs/vimc/mdev2/vimc-sensor:sen"
	mkdir "/configfs/vimc/mdev2/vimc-capture:cap-sen" #/dev/video0
	
	#sen -> cap-sen
	mkdir "/configfs/vimc/mdev2/vimc-sensor:sen/pad:source:0/to-cap"
	ln -s "/configfs/vimc/mdev2/vimc-capture:cap-sen/pad:sink:0" "/configfs/vimc/mdev2/vimc-sensor:sen/pad:source:0/to-cap"
	echo on > "/configfs/vimc/mdev2/vimc-sensor:sen/pad:source:0/to-cap/immutable"
	echo on > "/configfs/vimc/mdev2/vimc-sensor:sen/pad:source:0/to-cap/enabled"
}

function simple_topo {
	echo "start simple topo"
	# Creating the entities
	mkdir "/configfs/vimc/mdev"
	mkdir "/configfs/vimc/mdev/vimc-sensor:sen"
	mkdir "/configfs/vimc/mdev/vimc-debayer:deb"
	mkdir "/configfs/vimc/mdev/vimc-scaler:sca"
	mkdir "/configfs/vimc/mdev/vimc-capture:cap-sca" #/dev/video2
	mkdir "/configfs/vimc/mdev/vimc-capture:cap-sen" #/dev/video1
	mkdir "/configfs/vimc/mdev/vimc-capture:cap-deb" #/dev/video0

	# Creating the links
	#sen -> deb
	mkdir "/configfs/vimc/mdev/vimc-sensor:sen/pad:source:0/to-deb"
	ln -s "/configfs/vimc/mdev/vimc-debayer:deb/pad:sink:0" "/configfs/vimc/mdev/vimc-sensor:sen/pad:source:0/to-deb"
	echo on > "/configfs/vimc/mdev/vimc-sensor:sen/pad:source:0/to-deb/immutable"
	echo on > "/configfs/vimc/mdev/vimc-sensor:sen/pad:source:0/to-deb/enabled"

	#deb -> sca
	mkdir "/configfs/vimc/mdev/vimc-debayer:deb/pad:source:1/to-sca"
	ln -s "/configfs/vimc/mdev/vimc-scaler:sca/pad:sink:0" "/configfs/vimc/mdev/vimc-debayer:deb/pad:source:1/to-sca"
	echo on > "/configfs/vimc/mdev/vimc-debayer:deb/pad:source:1/to-sca/immutable"
	echo on > "/configfs/vimc/mdev/vimc-debayer:deb/pad:source:1/to-sca/enabled"

	#sca -> cap-sca
	mkdir "/configfs/vimc/mdev/vimc-scaler:sca/pad:source:1/to-cap"
	ln -s "/configfs/vimc/mdev/vimc-capture:cap-sca/pad:sink:0" "/configfs/vimc/mdev/vimc-scaler:sca/pad:source:1/to-cap"
	echo on > "/configfs/vimc/mdev/vimc-scaler:sca/pad:source:1/to-cap/immutable"
	echo on > "/configfs/vimc/mdev/vimc-scaler:sca/pad:source:1/to-cap/enabled"

	#sen -> cap-sen
	mkdir "/configfs/vimc/mdev/vimc-sensor:sen/pad:source:0/to-cap"
	ln -s "/configfs/vimc/mdev/vimc-capture:cap-sen/pad:sink:0" "/configfs/vimc/mdev/vimc-sensor:sen/pad:source:0/to-cap"
	echo on > "/configfs/vimc/mdev/vimc-sensor:sen/pad:source:0/to-cap/immutable"
	echo on > "/configfs/vimc/mdev/vimc-sensor:sen/pad:source:0/to-cap/enabled"

	#deb -> cap-deb
	mkdir "/configfs/vimc/mdev/vimc-debayer:deb/pad:source:1/to-cap"
	ln -s "/configfs/vimc/mdev/vimc-capture:cap-deb/pad:sink:0" "/configfs/vimc/mdev/vimc-debayer:deb/pad:source:1/to-cap"
	echo on > "/configfs/vimc/mdev/vimc-debayer:deb/pad:source:1/to-cap/immutable"
	echo on > "/configfs/vimc/mdev/vimc-debayer:deb/pad:source:1/to-cap/enabled"
}

function configure_all_formats {
	media-ctl -d platform:vimc-000 -V '"sen":0[fmt:SBGGR8_1X8/640x480]'
	media-ctl -d platform:vimc-000 -V '"deb":0[fmt:SBGGR8_1X8/640x480]'
	# This is actually the default and the only supported format for deb:1
	# see `v4l2-ctl -d /dev/v4l-subdev1 --list-subdev-mbus 1`
	media-ctl -d platform:vimc-000 -V '"deb":1[fmt:RGB888_1X24/640x480]'
	media-ctl -d platform:vimc-000 -V '"sca":0[fmt:RGB888_1X24/640x480]'
	media-ctl -d platform:vimc-000 -V '"sca":1[fmt:RGB888_1X24/640x480]'
	v4l2-ctl -z platform:vimc-000 -d "cap-sen" -v pixelformat=BA81
	v4l2-ctl -z platform:vimc-000 -d "cap-deb" -v pixelformat=RGB3
	#The scaler scales times 3, so need to set its capture accordingly
	v4l2-ctl -z platform:vimc-000 -d "cap-sca" -v pixelformat=RGB3,width=1920,height=1440
}

function configure_all_formats1 {
	media-ctl -d platform:vimc-001 -V '"sen":0[fmt:SBGGR8_1X8/640x480]'
	v4l2-ctl -z platform:vimc-001 -d "cap-sen" -v pixelformat=BA81
}

echo 15 > /proc/sys/kernel/printk

test_idx=1
reinstall_vimc
simple_topo || exit 1
echo "===================================================================================="
echo "Test $test_idx: make sure that the deivce can be plugged and all captures can stream"
echo "===================================================================================="
((test_idx++))
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
media-ctl -d0 --print-dot > vmpath/simle.dot
media-ctl -d0 --print-dot | dot -Tps -o vmpath/simle.ps

configure_all_formats
out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSEN 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sen failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDDEB 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming deb failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSCA 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sca failed"; exit; fi


reinstall_vimc
simple_topo || exit 1
echo "=========================================================================="
echo "Test $test_idx: make sure it is impossible to remove the scaler"
echo "=========================================================================="
((test_idx++))
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
rmdir "/configfs/vimc/mdev/vimc-scaler:sca" && exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1

reinstall_vimc
simple_topo || exit 1
echo "=========================================================================="
echo "Test $test_idx: remove the two links [debayer -> scaler],[scaler->vimc-cpature] and the scaler"
echo "and make sure that the cap-sca can't be streamed and that the the other captures can"
echo "=========================================================================="
((test_idx++))
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
rm /configfs/vimc/mdev/vimc-debayer:deb/pad:source:1/to-sca/pad:sink:0 || exit 1
rm "/configfs/vimc/mdev/vimc-scaler:sca/pad:source:1/to-cap/pad:sink:0" || exit 1
rmdir /configfs/vimc/mdev/vimc-scaler:sca/pad:source:1/to-cap || exit 1
rmdir "/configfs/vimc/mdev/vimc-scaler:sca" || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
configure_all_formats
out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSEN 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sen failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDDEB 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming deb failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSCA 2>&1)
if [ "$out" == $STRM_OUT ]; then echo "streaming sca DID NOT fail (it should have)"; exit; fi

reinstall_vimc
simple_topo || exit 1
echo "=========================================================================="
echo "Test $test_idx: remove the scaler and its links and create it again and make
echo "sure the device can be plugged and stream"
echo "=========================================================================="
((test_idx++))
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
rm /configfs/vimc/mdev/vimc-debayer:deb/pad:source:1/to-sca/pad:sink:0 || exit 1
rm "/configfs/vimc/mdev/vimc-scaler:sca/pad:source:1/to-cap/pad:sink:0" || exit 1
rmdir /configfs/vimc/mdev/vimc-scaler:sca/pad:source:1/to-cap || exit 1

mkdir /configfs/vimc/mdev/vimc-scaler:sca/pad:source:1/to-cap || exit 1
ln -s "/configfs/vimc/mdev/vimc-capture:cap-sca/pad:sink:0" "/configfs/vimc/mdev/vimc-scaler:sca/pad:source:1/to-cap"
echo on > "/configfs/vimc/mdev/vimc-scaler:sca/pad:source:1/to-cap/immutable"
echo on > "/configfs/vimc/mdev/vimc-scaler:sca/pad:source:1/to-cap/enabled"

mkdir "/configfs/vimc/mdev/vimc-debayer:deb/pad:source:1/to-sca"
ln -s "/configfs/vimc/mdev/vimc-scaler:sca/pad:sink:0" "/configfs/vimc/mdev/vimc-debayer:deb/pad:source:1/to-sca"
echo on > "/configfs/vimc/mdev/vimc-debayer:deb/pad:source:1/to-sca/immutable"
echo on > "/configfs/vimc/mdev/vimc-debayer:deb/pad:source:1/to-sca/enabled"

echo 1 > /configfs/vimc/mdev/hotplug || exit 1
configure_all_formats
out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSEN 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sen failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDDEB 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming deb failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSCA 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sca failed"; exit; fi

reinstall_vimc
simple_topo || exit 1
echo "==============================================================================="
echo "Test $test_idx: create two simple devices and make sure that they can both be loaded and upstreamed together
echo "==============================================================================="
((test_idx++))
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
simpler_topo || exit 1
echo 1 > /configfs/vimc/mdev2/hotplug || exit 1
configure_all_formats
configure_all_formats1
out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSEN 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sen failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDDEB 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming deb failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSCA 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sca failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d /dev/video3 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming simpler pipline failed"; exit; fi

