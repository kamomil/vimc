function reinstall_vimc {
	find /configfs/ -mindepth 6 -name "pad:sink*" -exec unlink {} \;
	find /configfs/ -mindepth 5 -maxdepth 5 -exec rmdir {} \;
	find /configfs/ -mindepth 3 -maxdepth 3 -type d -exec rmdir {} \;
	find /configfs/ -mindepth 2 -maxdepth 2 -type d -exec rmdir {} \;
	modprobe -vr vimc
	umount /configfs
	modprobe -v vimc
	mount -t configfs none /configfs
	# This produce to much debugs when streaming on debayer and scaler
	# echo "file drivers/media/platform/vimc/* +p" > /sys/kernel/debug/dynamic_debug/control
	echo "file drivers/media/platform/vimc/vimc-core.c +p" > /sys/kernel/debug/dynamic_debug/control
	echo "file drivers/media/platform/vimc/vimc-configfs.c +p" > /sys/kernel/debug/dynamic_debug/control
	# echo "file drivers/media/mc/* +p" > /sys/kernel/debug/dynamic_debug/control
	# echo "file drivers/media/platform/vimc/vimc-core.c +p" > /sys/kernel/debug/dynamic_debug/control
}
function simpler_topo {
	echo "start simple topo"
	DEV2=$1
	# Creating the entities
	mkdir "/configfs/vimc/$DEV2"
	mkdir "/configfs/vimc/$DEV2/vimc-sensor:sen"
	mkdir "/configfs/vimc/$DEV2/vimc-capture:cap-sen" #/dev/video0

	#sen -> cap-sen
	mkdir "/configfs/vimc/$DEV2/vimc-sensor:sen/pad:source:0/to-cap"
	ln -s "/configfs/vimc/$DEV2/vimc-capture:cap-sen/pad:sink:0" "/configfs/vimc/$DEV2/vimc-sensor:sen/pad:source:0/to-cap"
	echo immutable > "/configfs/vimc/$DEV2/vimc-sensor:sen/pad:source:0/to-cap/type"
}

function simple_topo {
	echo "start simple topo for device "
	DEV=$1
# Creating the entities
	mkdir "/configfs/vimc/$DEV"
	mkdir "/configfs/vimc/$DEV/vimc-sensor:sen"
	mkdir "/configfs/vimc/$DEV/vimc-debayer:deb"
	mkdir "/configfs/vimc/$DEV/vimc-scaler:sca"
	mkdir "/configfs/vimc/$DEV/vimc-capture:cap-sca" #/dev/video2
	mkdir "/configfs/vimc/$DEV/vimc-capture:cap-sen" #/dev/video1
	mkdir "/configfs/vimc/$DEV/vimc-capture:cap-deb" #/dev/video0

# Creating the links
#sen -> deb
	mkdir "/configfs/vimc/$DEV/vimc-sensor:sen/pad:source:0/to-deb"
	ln -s "/configfs/vimc/$DEV/vimc-debayer:deb/pad:sink:0" "/configfs/vimc/$DEV/vimc-sensor:sen/pad:source:0/to-deb"
	echo immutable > "/configfs/vimc/$DEV/vimc-sensor:sen/pad:source:0/to-deb/type"

#deb -> sca
	mkdir "/configfs/vimc/$DEV/vimc-debayer:deb/pad:source:1/to-sca"
	ln -s "/configfs/vimc/$DEV/vimc-scaler:sca/pad:sink:0" "/configfs/vimc/$DEV/vimc-debayer:deb/pad:source:1/to-sca"
	echo immutable > "/configfs/vimc/$DEV/vimc-debayer:deb/pad:source:1/to-sca/type"

#sca -> cap-sca
	mkdir "/configfs/vimc/$DEV/vimc-scaler:sca/pad:source:1/to-cap"
	ln -s "/configfs/vimc/$DEV/vimc-capture:cap-sca/pad:sink:0" "/configfs/vimc/$DEV/vimc-scaler:sca/pad:source:1/to-cap"
	echo immutable > "/configfs/vimc/$DEV/vimc-scaler:sca/pad:source:1/to-cap/type"

#sen -> cap-sen
	mkdir "/configfs/vimc/$DEV/vimc-sensor:sen/pad:source:0/to-cap"
	ln -s "/configfs/vimc/$DEV/vimc-capture:cap-sen/pad:sink:0" "/configfs/vimc/$DEV/vimc-sensor:sen/pad:source:0/to-cap"
	echo immutable > "/configfs/vimc/$DEV/vimc-sensor:sen/pad:source:0/to-cap/type"

#deb -> cap-deb
	mkdir "/configfs/vimc/$DEV/vimc-debayer:deb/pad:source:1/to-cap"
	ln -s "/configfs/vimc/$DEV/vimc-capture:cap-deb/pad:sink:0" "/configfs/vimc/$DEV/vimc-debayer:deb/pad:source:1/to-cap"
	echo immutable > "/configfs/vimc/$DEV/vimc-debayer:deb/pad:source:1/to-cap/type"
}

function configure_all_formats {
	SEN_0='"sen":0[fmt:SBGGR8_1X8/640x480]'
	DEB_0='"deb":0[fmt:SBGGR8_1X8/640x480]'
	DEB_1='"deb":1[fmt:RGB888_1X24/640x480]'
	SCA_0='"sca":0[fmt:RGB888_1X24/640x480]'
	SCA_1='"sca":1[fmt:RGB888_1X24/640x480]'

#	media-ctl -d platform:vimc-000 -V '"sen":0[fmt:SBGGR8_1X8/640x480],"deb":0[fmt:SBGGR8_1X8/640x480]'
# media-ctl -d platform:vimc-000 -V '"deb":0[fmt:SBGGR8_1X8/640x480]'
# This is actually the default and the only supported format for deb:1
# see `v4l2-ctl -d /dev/v4l-subdev1 --list-subdev-mbus 1`
#	media-ctl -d platform:vimc-000 -V '"deb":1[fmt:RGB888_1X24/640x480]'
#	media-ctl -d platform:vimc-000 -V '"sca":0[fmt:RGB888_1X24/640x480]'
#	media-ctl -d platform:vimc-000 -V '"sca":1[fmt:RGB888_1X24/640x480]'
	media-ctl -d platform:vimc-000 -V "${SEN_0},${DEB_0},${DEB_1},${SCA_0},${SCA_1}"
	v4l2-ctl -z platform:vimc-000 -d "cap-sen" -v pixelformat=BA81
	v4l2-ctl -z platform:vimc-000 -d "cap-deb" -v pixelformat=RGB3
#The scaler scales times 3, so need to set its capture accordingly
	v4l2-ctl -z platform:vimc-000 -d "cap-sca" -v pixelformat=RGB3,width=1920,height=1440
}


function configure_all_formats_simpler {
	media-ctl -d platform:vimc-001 -V '"sen":0[fmt:SBGGR8_1X8/640x480]'
	v4l2-ctl -z platform:vimc-001 -d "cap-sen" -v pixelformat=BA81
}


