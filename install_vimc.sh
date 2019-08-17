if [ "$#" -ne 1 ]; then
echo "need kernel version"
exit 1
fi

version=$1

mkdir -p /lib/modules/$version/kernel/drivers/media/platform/vimc ; cp drivers/media/platform/vimc/vimc.ko /lib/modules/$version/kernel/drivers/media/platform/vimc ; true /lib/modules/$version/kernel/drivers/media/platform/vimc/vimc.ko ; scripts/sign-file "sha512" "certs/signing_key.pem" certs/signing_key.x509 /lib/modules/$version/kernel/drivers/media/platform/vimc/vimc.ko  ; true /lib/modules/$version/kernel/drivers/media/platform/vimc/vimc.ko

mkdir -p /lib/modules/$version/kernel/drivers/media/platform/vicodec
cp drivers/media/platform/vicodec/vicodec.ko /lib/modules/$version/kernel/drivers/media/platform/vicodec
true /lib/modules/$version/kernel/drivers/media/platform/vicodec/vicodec.ko
scripts/sign-file "sha512" "certs/signing_key.pem" certs/signing_key.x509 /lib/modules/$version/kernel/drivers/media/platform/vicodec/vicodec.ko  && true /lib/modules/$version/kernel/drivers/media/platform/vicodec/vicodec.ko

mkdir -p /lib/modules/$version/kernel/drivers/media/v4l2-core ; cp drivers/media/v4l2-core/v4l2-mem2mem.ko /lib/modules/$version/kernel/drivers/media/v4l2-core ; true /lib/modules/$version/kernel/drivers/media/v4l2-core/v4l2-mem2mem.ko ; scripts/sign-file "sha512" "certs/signing_key.pem" certs/signing_key.x509 /lib/modules/$version/kernel/drivers/media/v4l2-core/v4l2-mem2mem.ko  && true /lib/modules/$version/kernel/drivers/media/v4l2-core/v4l2-mem2mem.ko

mkdir -p /lib/modules/$version/kernel/drivers/media/v4l2-core ; cp drivers/media/v4l2-core/videodev.ko /lib/modules/$version/kernel/drivers/media/v4l2-core ; true /lib/modules/$version/kernel/drivers/media/v4l2-core/videodev.ko ; scripts/sign-file "sha512" "certs/signing_key.pem" certs/signing_key.x509 /lib/modules/$version/kernel/drivers/media/v4l2-core/videodev.ko  && true /lib/modules/$version/kernel/drivers/media/v4l2-core/videodev.ko

mkdir -p /lib/modules/$version/kernel/drivers/media/common/videobuf2 ; cp drivers/media/common/videobuf2/videobuf2-v4l2.ko /lib/modules/$version/kernel/drivers/media/common/videobuf2 ; true /lib/modules/$version/kernel/drivers/media/common/videobuf2/videobuf2-v4l2.ko ; scripts/sign-file "sha512" "certs/signing_key.pem" certs/signing_key.x509 /lib/modules/$version/kernel/drivers/media/common/videobuf2/videobuf2-v4l2.ko  && true /lib/modules/$version/kernel/drivers/media/common/videobuf2/videobuf2-v4l2.ko

mkdir -p /lib/modules/$version/kernel/drivers/media/common/videobuf2 ; cp drivers/media/common/videobuf2/videobuf2-vmalloc.ko /lib/modules/$version/kernel/drivers/media/common/videobuf2 ; true /lib/modules/$version/kernel/drivers/media/common/videobuf2/videobuf2-vmalloc.ko ; scripts/sign-file "sha512" "certs/signing_key.pem" certs/signing_key.x509 /lib/modules/$version/kernel/drivers/media/common/videobuf2/videobuf2-vmalloc.ko  && true /lib/modules/$version/kernel/drivers/media/common/videobuf2/videobuf2-vmalloc.ko

mkdir -p /lib/modules/$version/kernel/drivers/media/common/videobuf2 ; cp drivers/media/common/videobuf2/videobuf2-common.ko /lib/modules/$version/kernel/drivers/media/common/videobuf2 ; true /lib/modules/$version/kernel/drivers/media/common/videobuf2/videobuf2-common.ko ; scripts/sign-file "sha512" "certs/signing_key.pem" certs/signing_key.x509 /lib/modules/$version/kernel/drivers/media/common/videobuf2/videobuf2-common.ko  && true /lib/modules/$version/kernel/drivers/media/common/videobuf2/videobuf2-common.ko
