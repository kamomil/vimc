/* SPDX-License-Identifier: GPL-2.0-or-later */
/*
 * vimc-common.h Virtual Media Controller Driver
 *
 * Copyright (C) 2015-2017 Helen Koike <helen.fornazier@gmail.com>
 */

#ifndef _VIMC_COMMON_H_
#define _VIMC_COMMON_H_

#include <linux/slab.h>
#include <linux/platform_device.h>
#include <media/media-device.h>
#include <media/v4l2-device.h>

#define VIMC_PDEV_NAME "vimc"
#define VIMC_MAX_NAME_LEN 32

/* VIMC-specific controls */
#define VIMC_CID_VIMC_BASE		(0x00f00000 | 0xf000)
#define VIMC_CID_VIMC_CLASS		(0x00f00000 | 1)
#define VIMC_CID_TEST_PATTERN		(VIMC_CID_VIMC_BASE + 0)

#define VIMC_FRAME_MAX_WIDTH 4096
#define VIMC_FRAME_MAX_HEIGHT 2160
#define VIMC_FRAME_MIN_WIDTH 16
#define VIMC_FRAME_MIN_HEIGHT 16

#define VIMC_FRAME_INDEX(lin, col, width, bpp) ((lin * width + col) * bpp)

/**
 * struct vimc_colorimetry_clamp - Adjust colorimetry parameters
 *
 * @fmt:		the pointer to struct v4l2_pix_format or
 *			struct v4l2_mbus_framefmt
 *
 * Entities must check if colorimetry given by the userspace is valid, if not
 * then set them as DEFAULT
 */
#define vimc_colorimetry_clamp(fmt)					\
do {									\
	if ((fmt)->colorspace == V4L2_COLORSPACE_DEFAULT		\
	    || (fmt)->colorspace > V4L2_COLORSPACE_DCI_P3) {		\
		(fmt)->colorspace = V4L2_COLORSPACE_DEFAULT;		\
		(fmt)->ycbcr_enc = V4L2_YCBCR_ENC_DEFAULT;		\
		(fmt)->quantization = V4L2_QUANTIZATION_DEFAULT;	\
		(fmt)->xfer_func = V4L2_XFER_FUNC_DEFAULT;		\
	}								\
	if ((fmt)->ycbcr_enc > V4L2_YCBCR_ENC_SMPTE240M)		\
		(fmt)->ycbcr_enc = V4L2_YCBCR_ENC_DEFAULT;		\
	if ((fmt)->quantization > V4L2_QUANTIZATION_LIM_RANGE)		\
		(fmt)->quantization = V4L2_QUANTIZATION_DEFAULT;	\
	if ((fmt)->xfer_func > V4L2_XFER_FUNC_SMPTE2084)		\
		(fmt)->xfer_func = V4L2_XFER_FUNC_DEFAULT;		\
} while (0)


/**
 * struct vimc_platform_data_core - platform data to the core
 *
 * @ents: list of vimc_entity objects allocated by the configfs
 * @links: list of vimc_links objects allocated by the configfs
 */
struct vimc_platform_data_core {
	struct list_head *ents;
	struct list_head *links;
};

/**
 * struct vimc_pix_map - maps media bus code with v4l2 pixel format
 *
 * @code:		media bus format code defined by MEDIA_BUS_FMT_* macros
 * @bbp:		number of bytes each pixel occupies
 * @pixelformat:	pixel format devined by V4L2_PIX_FMT_* macros
 *
 * Struct which matches the MEDIA_BUS_FMT_* codes with the corresponding
 * V4L2_PIX_FMT_* fourcc pixelformat and its bytes per pixel (bpp)
 */
struct vimc_pix_map {
	unsigned int code;
	unsigned int bpp;
	u32 pixelformat;
	bool bayer;
};

/**
 * struct vimc_device - main device for vimc driver
 *
 * @pdev	pointer to the platform device
 * @pipe_cfg	pointer to the vimc pipeline configuration structure
 * @mdev	the associated media_device parent
 * @v4l2_dev	Internal v4l2 parent device
 */
struct vimc_device {
	/* The Associated media_device parent */
	struct media_device mdev;

	/* Internal v4l2 parent device */
	struct v4l2_device v4l2_dev;
};

/**
 * struct vimc_ent_device - core struct that represents a node in the topology
 *
 * @ent:		the pointer to struct media_entity for the node
 * @pads:		the list of pads of the node
 * @process_frame:	callback send a frame to that node
 * @vdev_get_format:	callback that returns the current format a pad, used
 *			only when is_media_entity_v4l2_video_device(ent) returns
 *			true
 *
 * Each node of the topology must create a vimc_ent_device struct. Depending on
 * the node it will be of an instance of v4l2_subdev or video_device struct
 * where both contains a struct media_entity.
 * Those structures should embedded the vimc_ent_device struct through
 * v4l2_set_subdevdata() and video_set_drvdata() respectivaly, allowing the
 * vimc_ent_device struct to be retrieved from the corresponding struct
 * media_entity
 */
struct vimc_ent_device {
	struct media_entity *ent;
	struct media_pad *pads;
	void * (*process_frame)(struct vimc_ent_device *ved,
				const void *frame);
	void (*vdev_get_format)(struct vimc_ent_device *ved,
			      struct v4l2_pix_format *fmt);
};

struct vimc_entity {
	char name[VIMC_MAX_NAME_LEN];
	char drv_name[VIMC_MAX_NAME_LEN];
	struct vimc_ent_device *vimc_ent_dev;
	struct list_head list;
};

struct vimc_link {
	char source_name[VIMC_MAX_NAME_LEN];
	char sink_name[VIMC_MAX_NAME_LEN];
	u16 source_pad;
	u16 sink_pad;
	u32 flags;
	struct vimc_ent_device **source;
	struct vimc_ent_device **sink;
	struct list_head list;
};

#define VIMC_DEB_NAME "vimc-debayer"
#define VIMC_SEN_NAME "vimc-sensor"
#define VIMC_SCA_NAME "vimc-scaler"
#define VIMC_CAP_NAME "vimc-capture"

/**
 * struct vimc_ent_config	Structure which describes individual
 *				configuration for each entity
 *
 * @name		entity name
 * @ved		pointer to vimc_ent_device (a node in the topology)
 * @add		subdev add hook - initializes and registers subdev
 *			called from vimc-core
 * @rm			subdev rm hook - unregisters and frees subdev
 *			called from vimc-core
 */
struct vimc_ent_type {
	const char *name;
	int (*add)(struct vimc_device *vimc, struct vimc_entity *ent);
	void (*rm)(struct vimc_device *vimc, struct vimc_entity *ent);
};

/* prototypes for vimc_ent_config add and rm hooks */
int vimc_cap_add(struct vimc_device *vimc, struct vimc_entity *ent);
void vimc_cap_rm(struct vimc_device *vimc, struct vimc_entity *ent);
void vimc_cap_init(void);
void vimc_cap_exit(void);

int vimc_deb_add(struct vimc_device *vimc, struct vimc_entity *ent);
void vimc_deb_rm(struct vimc_device *vimc, struct vimc_entity *ent);
void vimc_deb_init(void);
void vimc_deb_exit(void);

int vimc_sca_add(struct vimc_device *vimc, struct vimc_entity *ent);
void vimc_sca_rm(struct vimc_device *vimc, struct vimc_entity *ent);
void vimc_sca_init(void);
void vimc_sca_exit(void);

int vimc_sen_add(struct vimc_device *vimc, struct vimc_entity *ent);
void vimc_sen_rm(struct vimc_device *vimc, struct vimc_entity *ent);
void vimc_sen_init(void);
void vimc_sen_exit(void);

 /**
 * vimc_pads_init - initialize pads
 *
 * @num_pads:	number of pads to initialize
 * @pads_flags:	flags to use in each pad
 *
 * Helper functions to allocate/initialize pads
 */
struct media_pad *vimc_pads_init(u16 num_pads,
				 const unsigned long *pads_flag);

/**
 * vimc_pads_cleanup - free pads
 *
 * @pads: pointer to the pads
 *
 * Helper function to free the pads initialized with vimc_pads_init
 */
static inline void vimc_pads_cleanup(struct media_pad *pads)
{
	kfree(pads);
}

/**
 * vimc_pipeline_s_stream - start stream through the pipeline
 *
 * @ent:		the pointer to struct media_entity for the node
 * @enable:		1 to start the stream and 0 to stop
 *
 * Helper function to call the s_stream of the subdevices connected
 * in all the sink pads of the entity
 */
int vimc_pipeline_s_stream(struct media_entity *ent, int enable);

/**
 * vimc_pix_map_by_index - get vimc_pix_map struct by its index
 *
 * @i:			index of the vimc_pix_map struct in vimc_pix_map_list
 */
const struct vimc_pix_map *vimc_pix_map_by_index(unsigned int i);

/**
 * vimc_pix_map_by_code - get vimc_pix_map struct by media bus code
 *
 * @code:		media bus format code defined by MEDIA_BUS_FMT_* macros
 */
const struct vimc_pix_map *vimc_pix_map_by_code(u32 code);

/**
 * vimc_pix_map_by_pixelformat - get vimc_pix_map struct by v4l2 pixel format
 *
 * @pixelformat:	pixel format devined by V4L2_PIX_FMT_* macros
 */
const struct vimc_pix_map *vimc_pix_map_by_pixelformat(u32 pixelformat);

/**
 * vimc_ent_sd_register - initialize and register a subdev node
 *
 * @ved:	the vimc_ent_device struct to be initialize
 * @sd:		the v4l2_subdev struct to be initialize and registered
 * @v4l2_dev:	the v4l2 device to register the v4l2_subdev
 * @name:	name of the sub-device. Please notice that the name must be
 *		unique.
 * @function:	media entity function defined by MEDIA_ENT_F_* macros
 * @num_pads:	number of pads to initialize
 * @pads_flag:	flags to use in each pad
 * @sd_int_ops:	pointer to &struct v4l2_subdev_internal_ops
 * @sd_ops:	pointer to &struct v4l2_subdev_ops.
 *
 * Helper function initialize and register the struct vimc_ent_device and struct
 * v4l2_subdev which represents a subdev node in the topology
 */
int vimc_ent_sd_register(struct vimc_ent_device *ved,
			 struct v4l2_subdev *sd,
			 struct v4l2_device *v4l2_dev,
			 const char *const name,
			 u32 function,
			 u16 num_pads,
			 const unsigned long *pads_flag,
			 const struct v4l2_subdev_internal_ops *sd_int_ops,
			 const struct v4l2_subdev_ops *sd_ops);

/**
 * vimc_ent_sd_unregister - cleanup and unregister a subdev node
 *
 * @ved:	the vimc_ent_device struct to be cleaned up
 * @sd:		the v4l2_subdev struct to be unregistered
 *
 * Helper function cleanup and unregister the struct vimc_ent_device and struct
 * v4l2_subdev which represents a subdev node in the topology
 */
void vimc_ent_sd_unregister(struct vimc_ent_device *ved,
			    struct v4l2_subdev *sd);

/**
 * vimc_link_validate - validates a media link
 *
 * @link: pointer to &struct media_link
 *
 * This function calls validates if a media link is valid for streaming.
 */
int vimc_link_validate(struct media_link *link);

#endif
