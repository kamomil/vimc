#!/bin/bash
# Display commands and their arguments as they are executed.
# set -x

# we set all links to be enabled and immutable
# therefore, when streaming we should make sure that
# so, if trying to stream the sensor capture, we should
# still make sure that also the formats in all other links match

source ./functions.sh

VIDSCA=/dev/video2
VIDSEN=/dev/video1
VIDDEB=/dev/video0
STRM_CNT=10
# generates the v4l-ctl streaming output "<<<<<<" ...
STRM_OUT=$(printf '<%.0s' `seq $STRM_CNT`)

# echo 15 > /proc/sys/kernel/printk

test_idx=1
reinstall_vimc
simple_topo mdev || exit 1
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
simple_topo mdev || exit 1
echo "=========================================================================="
echo "Test $test_idx: make sure it is impossible to remove the scaler"
echo "=========================================================================="
((test_idx++))
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
rmdir "/configfs/vimc/mdev/vimc-scaler:sca" && exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1

reinstall_vimc
simple_topo mdev || exit 1
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
simple_topo mdev || exit 1
echo "=========================================================================="
echo "Test $test_idx: remove the scaler and its links and create it again and make"
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
simple_topo mdev || exit 1
echo "==============================================================================="
echo "Test $test_idx: create two simple devices and make sure that they can both be loaded and upstreamed together"
echo "==============================================================================="
((test_idx++))
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
simpler_topo mdev2 || exit 1
echo 1 > /configfs/vimc/mdev2/hotplug || exit 1
configure_all_formats
configure_all_formats_simpler
out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSEN 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sen failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDDEB 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming deb failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSCA 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming sca failed"; exit; fi

out=$(v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d /dev/video3 2>&1)
if [ "$out" != $STRM_OUT ]; then echo "streaming simpler pipline failed"; exit; fi

