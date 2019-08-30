#!/bin/bash
set -i
set -x

echo "file drivers/media/platform/vimc/* +p" > /sys/kernel/debug/dynamic_debug/control
echo 15 > /proc/sys/kernel/printk

mount -t configfs none /configfs
mkdir /configfs/vimc/mdev

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
mkdir "/configfs/vimc/mdev/links/sen:0->cap-sen:0"
# 1 = enable, 2=immutable, 1|2=3
echo 3 > "/configfs/vimc/mdev/links/sen:0->cap-sen:0/flags"
mkdir "/configfs/vimc/mdev/links/deb:1->sca:0"
mkdir "/configfs/vimc/mdev/links/deb:1->cap-deb:0"
echo 3 > "/configfs/vimc/mdev/links/deb:1->cap-deb:0/flags"
mkdir "/configfs/vimc/mdev/links/sca:1->cap-sca:0"
echo 3 > "/configfs/vimc/mdev/links/sca:1->cap-sca:0/flags"
echo 1 > /configfs/vimc/mdev/hotplug
