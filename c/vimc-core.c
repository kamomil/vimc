// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * vimc-core.c Virtual Media Controller Driver
 *
 * Copyright (C) 2015-2017 Helen Koike <helen.fornazier@gmail.com>
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <media/media-device.h>
#include <media/v4l2-device.h>

#include "vimc-common.h"

#define VIMC_MDEV_MODEL_NAME "VIMC MDEV"

#include "vimc-configfs.h"

static struct vimc_ent_type ent_types[] = {
	{
		.name = VIMC_SEN_NAME,
		.add = vimc_sen_add,
		.rm = vimc_sen_rm,
	},
	{
		.name = VIMC_DEB_NAME,
		.add = vimc_deb_add,
		.rm = vimc_deb_rm,
	},
	{
		.name = VIMC_CAP_NAME,
		.add = vimc_cap_add,
		.rm = vimc_cap_rm,
	},
	{
		.name = VIMC_SCA_NAME,
		.add = vimc_sca_add,
		.rm = vimc_sca_rm,
	},
};

/* -------------------------------------------------------------------------- */

static int vimc_core_links_create(const struct vimc_device *vimc,
				  const struct vimc_platform_data_core *pdata)
{
	struct vimc_link *link;

	list_for_each_entry(link, pdata->links, list) {
		int ret = media_create_pad_link((*(link->source))->ent,
					    link->source_pad,
					    (*(link->sink))->ent,
					    link->sink_pad,
					    link->flags);
		pr_info("%s: created link\n",__func__);
		if (ret)
			return ret;
	}
	return 0;
}

static struct vimc_ent_type *vimc_get_ent_type(const char *drv_name)
{
	int i;

	for (i = 0; i < ARRAY_SIZE(ent_types); i++)
		if (!strcmp(drv_name, ent_types[i].name))
			return &ent_types[i];
	return NULL;
}

static int vimc_add_subdevs(struct vimc_device *vimc,
		const struct vimc_platform_data_core *pdata)
{

	struct vimc_entity *ent;
	struct vimc_entity *r_ent = NULL;
	int ret;

	list_for_each_entry(ent, pdata->ents, list) {

		struct vimc_ent_type *ent_type =
			vimc_get_ent_type(ent->drv_name);

		//the configfs should have already validate userspace input
		BUG_ON(!ent_type);
		//this pointer will be filled by the .add callback and so
		//if it is not NULL then something isn't right
		if (!ent_type) {
			ret = -EINVAL;
			goto err;
		}
		BUG_ON(ent->vimc_ent_dev);
		pr_info("%s: registering entity %s:%s\n", __func__,
			ent->drv_name, ent->name);

		ret = ent_type->add(vimc, ent);
		if (ret) {
			dev_err(vimc->mdev.dev, "failed to add entity %s:%s\n",
				ent->drv_name, ent->name);
			goto err;
		}
	}
	return 0;
err:
	list_for_each_entry_continue_reverse(r_ent, pdata->ents, list) {
		struct vimc_ent_type *ent_type =
			vimc_get_ent_type(r_ent->drv_name);

		ent_type->rm(vimc, r_ent);
		r_ent->vimc_ent_dev = NULL;
	}
	return ret;
}

static int vimc_register_devices(struct vimc_device *vimc,
				 const struct vimc_platform_data_core *pdata)
{
	int ret;

	/* Register the v4l2 struct */
	ret = v4l2_device_register(vimc->mdev.dev, &vimc->v4l2_dev);
	if (ret) {
		dev_err(vimc->mdev.dev,
			"v4l2 device register failed (err=%d)\n", ret);
		return ret;
	}

	ret = vimc_add_subdevs(vimc, pdata);
	if (ret)
		goto err_v4l2_unregister;

	ret = vimc_core_links_create(vimc, pdata);
	if (ret)
		goto err_v4l2_unregister;

	/* Register the media device */
	ret = media_device_register(&vimc->mdev);
	if (ret) {
		dev_err(vimc->mdev.dev,
		"media device register failed (err=%d)\n", ret);
		goto err_v4l2_unregister;
	}

	/* Expose all subdev's nodes*/
	ret = v4l2_device_register_subdev_nodes(&vimc->v4l2_dev);
	if (ret) {
		dev_err(vimc->mdev.dev,
		"vimc subdev nodes registration failed (err=%d)\n",
		ret);
		goto err_mdev_unregister;
	}


	return 0;

err_mdev_unregister:
	media_device_unregister(&vimc->mdev);
	media_device_cleanup(&vimc->mdev);
err_v4l2_unregister:
	v4l2_device_unregister(&vimc->v4l2_dev);

	return ret;
}

static void vimc_rm_subdevs(struct vimc_device *vimc,
			    struct vimc_platform_data_core *pdata)
{
	struct vimc_entity *ent;
	int i = 0;

	list_for_each_entry(ent, pdata->ents, list) {

		struct vimc_ent_type *ent_type = vimc_get_ent_type(ent->drv_name);

		i++;
		pr_info("%s: removing entity %s:%s\n", __func__, ent->drv_name, ent->name);
		//the configfs should have already validate userspace input
		BUG_ON(!ent_type);
		if (!ent_type)
			return;
		//this should not be null when removing the devices
		BUG_ON(!ent->vimc_ent_dev);
		if (!ent->vimc_ent_dev)
			return;
		dev_dbg(vimc->mdev.dev, "removing entity %s:%s\n", ent->drv_name, ent->name);

		ent_type->rm(vimc, ent);
		if (i>100)
			return;
	}
}

static int vimc_probe(struct platform_device *pdev)
{
	const struct vimc_platform_data_core *pdata = pdev->dev.platform_data;
	struct vimc_device *vimc;
	int ret = 0;

	dev_dbg(&pdev->dev, "probe\n");

	vimc = devm_kzalloc(&pdev->dev, sizeof(*vimc),
			GFP_KERNEL);
	memset(&vimc->mdev, 0, sizeof(vimc->mdev));

	pr_info("%s: %px\n", __func__, vimc);
	/* Link the media device within the v4l2_device */
	vimc->v4l2_dev.mdev = &vimc->mdev;

	/* Initialize media device */
	strscpy(vimc->mdev.model, VIMC_MDEV_MODEL_NAME,
		sizeof(vimc->mdev.model));
	snprintf(vimc->mdev.bus_info, sizeof(vimc->mdev.bus_info),
		 "platform:%s", VIMC_PDEV_NAME);
	vimc->mdev.dev = &pdev->dev;
	media_device_init(&vimc->mdev);

	ret = vimc_register_devices(vimc, pdata);
	if (ret) {
		media_device_cleanup(&vimc->mdev);
		kfree(vimc);
		return ret;
	}
	platform_set_drvdata(pdev, vimc);
	return 0;
}
//ret = v4l2_device_register(vimc->mdev.dev, &vimc->v4l2_dev);
//vimc_add_subdevs(vimc, pdata);
//ret = vimc_core_links_create(vimc, pdata);
//ret = v4l2_device_register_subdev_nodes(&vimc->v4l2_dev);
//ret = media_device_register(&vimc->mdev);

static int vimc_remove(struct platform_device *pdev)
{
	struct vimc_device *vimc = platform_get_drvdata(pdev);
	struct vimc_platform_data_core *pdata = pdev->dev.platform_data;

	dev_dbg(&pdev->dev, "remove\n");
	pr_info("%s: %px\n", __func__, vimc);

	media_device_unregister(&vimc->mdev);
	media_device_cleanup(&vimc->mdev);
	vimc_rm_subdevs(vimc, pdata);
	v4l2_device_unregister(&vimc->v4l2_dev);
	// no need to free vimc, since according to  the devm_kmalloc's doc:
	// Memory allocated with this function is automatically freed on driver detach ..

	return 0;
}

static struct platform_driver vimc_pdrv = {
	.probe		= vimc_probe,
	.remove		= vimc_remove,
	.driver		= {
		.name	= "vimc-core",
	},
};

static int __init vimc_init(void)
{
	int ret;

	ret = platform_driver_register(&vimc_pdrv);
	if (ret)
		return ret;

	ret = vimc_cfs_subsys_register();
	if (ret) {
		pr_err("%s: vimc_cfs_subsys_register failed (%d)\n", __func__, ret);
		platform_driver_unregister(&vimc_pdrv);
		return ret;
	}

	vimc_sen_init();
	vimc_deb_init();
	vimc_sca_init();
	vimc_cap_init();
	return 0;
}

static void __exit vimc_exit(void)
{
	vimc_sen_exit();
	vimc_deb_exit();
	vimc_sca_exit();
	vimc_cap_exit();

	vimc_cfs_subsys_unregister();
	platform_driver_unregister(&vimc_pdrv);
}

module_init(vimc_init);
module_exit(vimc_exit);

MODULE_DESCRIPTION("Virtual Media Controller Driver (VIMC)");
MODULE_AUTHOR("Helen Fornazier <helen.fornazier@gmail.com>");
MODULE_LICENSE("GPL");
