#!/bin/bash
set -i
set -x

echo "file drivers/media/platform/vimc/* +p" > /sys/kernel/debug/dynamic_debug/control
echo 15 > /proc/sys/kernel/printk

mount -t configfs none /configfs
rmdir /configfs/vimc/mdev/entities/*
rmdir /configfs/vimc/mdev/links/*
rmdir /configfs/vimc/mdev

modprobe -vr vimc
