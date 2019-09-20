#!/bin/bash
# Display commands and their arguments as they are executed.
# set -x

source ./functions.sh

VIDSCA=/dev/video2
VIDSEN=/dev/video1
VIDDEB=/dev/video0
STRM_CNT=1000

# echo 15 > /proc/sys/kernel/printk

reinstall_vimc
simple_topo mdev || exit 1
echo 1 > /configfs/vimc/mdev/hotplug || exit 1
media-ctl -d0 --print-dot > vmpath/simle.dot
media-ctl -d0 --print-dot | dot -Tps -o vmpath/simle.ps

configure_all_formats
v4l2-ctl --stream-mmap --stream-count=$STRM_CNT -d $VIDSEN &
sleep 1
echo 0 > /configfs/vimc/mdev/hotplug


