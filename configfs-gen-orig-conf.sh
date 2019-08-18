#!/bin/bash
set -i
set -x

echo "file drivers/media/platform/vimc/* +p" > /sys/kernel/debug/dynamic_debug/control
echo 15 > /proc/sys/kernel/printk

mount -t configfs none /configfs
mkdir /configfs/vimc/mdev
mkdir "/configfs/vimc/mdev/entities/vimc-sensor:Sensor A"
mkdir "/configfs/vimc/mdev/entities/vimc-sensor:Sensor B"
mkdir "/configfs/vimc/mdev/entities/vimc-debayer:Debayer A"
mkdir "/configfs/vimc/mdev/entities/vimc-debayer:Debayer B"
mkdir "/configfs/vimc/mdev/entities/vimc-capture:Raw Capture 0"
mkdir "/configfs/vimc/mdev/entities/vimc-capture:Raw Capture 1"
mkdir "/configfs/vimc/mdev/entities/vimc-sensor:RGB-YUV Input"
mkdir "/configfs/vimc/mdev/entities/vimc-scaler:Scaler"
mkdir "/configfs/vimc/mdev/entities/vimc-capture:RGB-YUV Capture"

mkdir "/configfs/vimc/mdev/links/Sensor A:0->Debayer A:0"
mkdir "/configfs/vimc/mdev/links/Sensor A:0->Raw Capture 0:0"
mkdir "/configfs/vimc/mdev/links/Sensor B:0->Debayer B:0"
mkdir "/configfs/vimc/mdev/links/Sensor B:0->Raw Capture 1:0"
mkdir "/configfs/vimc/mdev/links/Debayer A:1->Scaler:0"
mkdir "/configfs/vimc/mdev/links/Debayer B:1->Scaler:0"
mkdir "/configfs/vimc/mdev/links/RGB-YUV Input:1->Scaler:0"
mkdir "/configfs/vimc/mdev/links/Scaler:1->RGB-YUV Capture:0"

# TODO - add the links
# mkdir "/configfs/vimc/mdev/links/my-sensor:0->my-capture:0"
# echo 3 > "/configfs/vimc/mdev/links/my-sensor:0->my-capture:0/flags"
echo 1 > /configfs/vimc/mdev/hotplug
