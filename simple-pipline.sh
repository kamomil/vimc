#!/bin/bash
set -i
set -x

echo "file drivers/media/platform/vimc/* +p" > /sys/kernel/debug/dynamic_debug/control
echo 15 > /proc/sys/kernel/printk

mount -t configfs none /configfs
mkdir /configfs/vimc/mdev

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

# mkdir "/configfs/vimc/mdev/links/my-sensor:0->my-capture:0"
# echo 3 > "/configfs/vimc/mdev/links/my-sensor:0->my-capture:0/flags"
echo 1 > /configfs/vimc/mdev/hotplug
