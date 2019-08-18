// SPDX-License-Identifier: GPL-2.0+
/*
 * vimc-configfs.c Virtual Media Controller Driver
 *
 * Copyright (C) 2018 Helen Koike <helen.koike@collabora.com>
 */

#include <linux/module.h>
#include <linux/slab.h>
#include <linux/platform_device.h>

#include "vimc-common.h"
#include "vimc-configfs.h"
//#include "vimc-core.h"

#define CHAR_SEPARATOR ':'
#define LINK_SEPARATOR "->"
#define CFS_SUBSYS_NAME "vimc"

#define ci_err(ci, fmt, ...) \
	pr_err("vimc: %s: " pr_fmt(fmt), (ci)->ci_name, ##__VA_ARGS__)
#define cg_err(cg, ...) ci_err(&(cg)->cg_item, ##__VA_ARGS__)
#define ci_warn(ci, fmt, ...) \
	pr_warn("vimc: %s: " pr_fmt(fmt), (ci)->ci_name, ##__VA_ARGS__)
#define cg_warn(cg, ...) ci_warn(&(cg)->cg_item, ##__VA_ARGS__)
#define ci_dbg(ci, fmt, ...) \
	pr_debug("vimc: %s: " pr_fmt(fmt), (ci)->ci_name, ##__VA_ARGS__)
#define cg_dbg(cg, ...) ci_dbg(&(cg)->cg_item, ##__VA_ARGS__)

#define is_plugged(cfs) (!!(cfs)->pdev)

enum vimc_cfs_hotplug_state {
	VIMC_CFS_HOTPLUG_STATE_UNPLUGGED = 0,
	VIMC_CFS_HOTPLUG_STATE_PLUGGED = 1,
};

const static char *vimc_cfs_hotplug_values[2][3] = {
	[VIMC_CFS_HOTPLUG_STATE_UNPLUGGED] = {"unplugged\n", "unplug\n", "0\n"},
	[VIMC_CFS_HOTPLUG_STATE_PLUGGED] = {"plugged\n", "plug\n", "1\n"},
};

struct config_item_type vimc_default_cfs_pad_type = {
	.ct_owner	= THIS_MODULE,
};
EXPORT_SYMBOL_GPL(vimc_default_cfs_pad_type);
/* --------------------------------------------------------------------------
 * Pipeline structures
 */

static struct vimc_cfs_subsystem {
	struct configfs_subsystem subsys;
	struct list_head drvs;
} vimc_cfs_subsys;

/* Structure which describes the whole topology */
struct vimc_cfs_device {
	struct list_head ents;
	struct list_head links;
	struct platform_device *pdev;
	struct vimc_platform_data_core pdata;
	struct config_group gdev;
	struct config_group gents;
	struct config_group glinks;
};

/* Structure which describes individual configuration for each entity */
struct vimc_cfs_ent {
	struct vimc_entity ent;
	struct config_group cg;
	struct config_group default_groups[2];
};

/* Structure which describes links between entities */
struct vimc_cfs_link {
	struct vimc_link link;
	struct config_item ci;
};

void vimc_cfs_drv_register(struct vimc_cfs_drv *c_drv)
{
	list_add(&c_drv->list, &vimc_cfs_subsys.drvs);
}
EXPORT_SYMBOL_GPL(vimc_cfs_drv_register);

void vimc_cfs_drv_unregister(struct vimc_cfs_drv *c_drv)
{
	list_del(&c_drv->list);
}
EXPORT_SYMBOL_GPL(vimc_cfs_drv_unregister);

/* --------------------------------------------------------------------------
 * Platform Device builders
 */
static void dump_ents(const struct vimc_cfs_device *cfs)
{
	struct vimc_entity *ent;
	int i = 0;

	pr_info("%s: start\n", __func__);
	list_for_each_entry(ent, &cfs->ents, list) {
		i++;
		pr_info("%s: i=%d ent=%px\n", __func__, i, ent);
		if (i>10)
			return;
	}
}

static int vimc_cfs_link_set_ents(const struct vimc_cfs_device *cfs,
				   struct vimc_link *link)
{
	struct vimc_entity *ent;

	list_for_each_entry(ent, &cfs->ents, list) {
		if (!link->source &&
		    !strcmp(ent->name, link->source_name))
			link->source = &ent->vimc_ent_dev;
		if (!link->sink &&
				!strcmp(ent->name, link->sink_name))
			link->sink = &ent->vimc_ent_dev;
		if (link->source && link->sink)
			return 0;
	}
	pr_err("%s: could not validate link %s->%s\n", __func__,
	       link->source_name,
	       link->sink_name);
	if (!link->source)
		pr_err("%s: source not found\n", __func__);
	if (!link->sink)
		pr_err("%s: sink not found\n", __func__);
	return -EINVAL;
}

static void vimc_cfs_device_unplug(struct vimc_cfs_device *cfs)
{
	dev_dbg(&cfs->pdev->dev, "Unplugging device\n");
	platform_device_unregister(cfs->pdev);

	cfs->pdev = NULL;
}

static int vimc_cfs_device_plug(struct vimc_cfs_device *cfs)
{
	struct vimc_link *link;
	struct vimc_entity *ent;
	int i = 0;

	cg_dbg(&cfs->gdev, "Plugging device\n");

	if (list_empty(&cfs->ents)) {
		cg_err(&cfs->gdev,
			"At least one entity is required to plug the device\n");
		return -EINVAL;
	}


	list_for_each_entry(link, &cfs->links, list) {
		if (vimc_cfs_link_set_ents(cfs, link)) {
			cg_err(&cfs->gdev, "could not validate link\n");
			return -EINVAL;
		}
	}
	pr_info("%s: start cfs=%px &cfs->pdata.ents=%px\n", __func__, cfs, &cfs->pdata.ents);
	list_for_each_entry(ent, &cfs->ents, list) {
		i++;
		pr_info("%s: start i=%d ent=%px\n", __func__, i, ent);
		if (i>10)
			return -EINVAL;
	}

	cfs->pdev = platform_device_register_data(NULL, "vimc-core",
						  PLATFORM_DEVID_AUTO,
						  &cfs->pdata,
						  sizeof(cfs->pdata));
	if (IS_ERR(cfs->pdev)) {
		int ret = PTR_ERR(cfs->pdev);

		cfs->pdev = NULL;
		return ret;
	}

	return 0;
}

/* --------------------------------------------------------------------------
 * Links
 */

static ssize_t vimc_cfs_links_attr_flags_show(struct config_item *item,
					      char *buf)
{
	struct vimc_cfs_link *c_link = container_of(item, struct vimc_cfs_link,
						    ci);

	sprintf(buf, "0x%x\n", c_link->link.flags);
	return strlen(buf);
}

static ssize_t vimc_cfs_links_attr_flags_store(struct config_item *item,
					       const char *buf, size_t size)
{
	struct vimc_cfs_link *c_link = container_of(item, struct vimc_cfs_link,
						    ci);

	if (kstrtou32(buf, 0, &c_link->link.flags))
		return -EINVAL;

	return size;
}

CONFIGFS_ATTR(vimc_cfs_links_attr_, flags);

static struct configfs_attribute *vimc_cfs_link_attrs[] = {
	&vimc_cfs_links_attr_attr_flags,
	NULL,
};

static void vimc_cfs_link_release(struct config_item *item)
{
	struct vimc_cfs_link *c_link = container_of(item, struct vimc_cfs_link,
						    ci);

	pr_info("%s: releasing link %px\n", __func__, c_link);
	kfree(c_link);
}

static struct configfs_item_operations vimc_cfs_link_item_ops = {
	.release	= vimc_cfs_link_release,
};

static struct config_item_type vimc_cfs_link_type = {
	.ct_item_ops	= &vimc_cfs_link_item_ops,
	.ct_attrs	= vimc_cfs_link_attrs,
	.ct_owner	= THIS_MODULE,
};

static void vimc_cfs_link_drop_item(struct config_group *group,
				    struct config_item *item)
{
	struct vimc_cfs_link *c_link = container_of(item,
						  struct vimc_cfs_link, ci);
	struct vimc_cfs_device *cfs = container_of(group,
						   struct vimc_cfs_device,
						   glinks);

	if (is_plugged(cfs))
		vimc_cfs_device_unplug(cfs);
	list_del(&c_link->link.list);
	config_item_put(item);
}

static struct config_item *vimc_cfs_link_make_item(struct config_group *group,
						   const char *name)
{
	struct vimc_cfs_device *cfs = container_of(group,
						   struct vimc_cfs_device,
						   glinks);
	size_t src_pad_strlen, sink_pad_strlen, sink_namelen, source_namelen;
	const char *sep, *src_pad_str, *sink_pad_str, *sink_name,
	      *source_name = name;
	struct vimc_cfs_link *c_link;
	u16 source_pad, sink_pad;
	char tmp[4];

	cg_dbg(&cfs->gdev, "Creating link %s\n", name);

	if (is_plugged(cfs))
		vimc_cfs_device_unplug(cfs);

	/* Parse format "source_name:source_pad->sink_name:sink_pad" */
	sep = strchr(source_name, CHAR_SEPARATOR);
	if (!sep)
		goto syntax_error;
	source_namelen = (size_t)(sep - source_name);

	src_pad_str = &sep[1];
	sep = strstr(src_pad_str, LINK_SEPARATOR);
	if (!sep)
		goto syntax_error;
	src_pad_strlen = (size_t)(sep - src_pad_str);

	sink_name = &sep[strlen(LINK_SEPARATOR)];
	sep = strchr(sink_name, CHAR_SEPARATOR);
	if (!sep)
		goto syntax_error;
	sink_namelen = (size_t)(sep - sink_name);

	sink_pad_str = &sep[1];
	sink_pad_strlen = strlen(sink_pad_str);

	/* Validate sizes */
	if (!src_pad_strlen || !sink_pad_strlen ||
	    !sink_namelen || !source_namelen)
		goto syntax_error;

	/* we limit the size here so we don't need to allocate another buffer */
	if (src_pad_strlen >= sizeof(tmp) || sink_pad_strlen >= sizeof(tmp)) {
		cg_err(&cfs->gdev,
		       "Pad with more then %ld digits is not supported\n",
		       sizeof(tmp) - 1);
		goto syntax_error;
	}
	strscpy(tmp, src_pad_str, src_pad_strlen + 1);
	if (kstrtou16(tmp, 0, &source_pad)) {
		cg_err(&cfs->gdev, "Couldn't convert pad %s to number\n", tmp);
		goto syntax_error;
	}
	strscpy(tmp, sink_pad_str, sink_pad_strlen + 1);
	if (kstrtou16(tmp, 0, &sink_pad)) {
		cg_err(&cfs->gdev, "Couldn't convert pad %s to number\n", tmp);
		goto syntax_error;
	}

	c_link = kzalloc(sizeof(*c_link), GFP_KERNEL);
	if (!c_link)
		return ERR_PTR(-ENOMEM);

	c_link->link.source_pad = source_pad;
	c_link->link.sink_pad = sink_pad;
	strscpy(c_link->link.source_name, source_name, source_namelen + 1);
	strscpy(c_link->link.sink_name, sink_name, sink_namelen + 1);

	list_add(&c_link->link.list, &cfs->links);
	config_item_init_type_name(&c_link->ci, name, &vimc_cfs_link_type);

	return &c_link->ci;

syntax_error:
	cg_err(&cfs->gdev,
	       "Couldn't create link %s, wrong syntax.", name);
	return ERR_PTR(-EINVAL);
}

static void vimc_cfs_ent_release(struct config_item *item)
{
	struct vimc_cfs_ent *c_ent = container_of(item, struct vimc_cfs_ent,
						  cg.cg_item);
	pr_info("%s: releasing ent %px\n", __func__, c_ent);
	kfree(c_ent);
}

static struct configfs_item_operations vimc_cfs_ent_item_ops = {
	.release	= vimc_cfs_ent_release,
};

static struct config_item_type vimc_cfs_ent_type = {
	.ct_item_ops	= &vimc_cfs_ent_item_ops,
	.ct_owner	= THIS_MODULE,
};

static void vimc_cfs_ent_drop_item(struct config_group *group,
				   struct config_item *item)
{
	struct vimc_cfs_ent *c_ent = container_of(item, struct vimc_cfs_ent,
						  cg.cg_item);
	struct vimc_cfs_device *cfs = container_of(group,
						   struct vimc_cfs_device,
						   gents);

	pr_info("%s: cfs=%px\n", __func__, cfs);
	pr_info("%s: c_ent=%px\n", __func__, c_ent);
	if (is_plugged(cfs))
		vimc_cfs_device_unplug(cfs);
	list_del(&c_ent->ent.list);
	dump_ents(cfs);
	config_item_put(item);
}

static struct config_group *vimc_cfs_ent_make_group(struct config_group *group,
						    const char *name)
{
	struct vimc_cfs_device *cfs = container_of(group,
						   struct vimc_cfs_device,
						   gents);
	char *ent_name, *sep = strchr(name, CHAR_SEPARATOR);
	struct vimc_cfs_ent *c_ent;
	struct vimc_entity *ent;
	size_t drv_namelen;
	struct vimc_cfs_drv *c_drv = NULL;

	pr_info("%s: cfs=%px\n", __func__, cfs);
	if (is_plugged(cfs))
		vimc_cfs_device_unplug(cfs);

	/* Parse format "drv_name:ent_name" */
	if (!sep) {
		cg_err(&cfs->gdev,
			"Could not find separator '%c'\n", CHAR_SEPARATOR);
		goto syntax_error;
	}
	drv_namelen = (size_t)(sep - name);
	ent_name = &sep[1];
	if (!*ent_name || !drv_namelen) {
		cg_err(&cfs->gdev,
			"%s: Driver name and entity name can't be empty.\n",
		       name);
		goto syntax_error;
	}
	if (drv_namelen >= sizeof(c_ent->ent.drv_name)) {
		cg_err(&cfs->gdev,
		       "%s: Driver name length should be less than %ld.\n",
		       name, sizeof(c_ent->ent.drv_name));
		goto syntax_error;
	}
	list_for_each_entry(ent, &cfs->ents, list) {
		if (!strncmp(ent->name, ent_name, sizeof(ent->name))) {
			cg_err(&cfs->gdev, "entity `%s` already exist\n",
			       ent->name);
			goto syntax_error;
		}
	}

	c_ent = kzalloc(sizeof(*c_ent), GFP_KERNEL);
	if (!c_ent)
		return ERR_PTR(-ENOMEM);

	strscpy(c_ent->ent.drv_name, name, drv_namelen + 1);
	strscpy(c_ent->ent.name, ent_name, sizeof(c_ent->ent.name));

	cg_dbg(&cfs->gdev, "new entity %s:%s\n",
	       c_ent->ent.drv_name, c_ent->ent.name);

	pr_info("%s: c_ent=%px\n", __func__, c_ent);

	/* Configure group */

	/* *TODO: add support for hotplug in entity level */
	list_for_each_entry(c_drv, &vimc_cfs_subsys.drvs, list) {
		if (!strcmp(c_ent->ent.drv_name, c_drv->name)) {
			config_group_init_type_name(&c_ent->cg, name,
						    &vimc_cfs_ent_type);
			if (c_drv->configfs_cb)
				c_drv->configfs_cb(&c_ent->cg, c_ent->default_groups);
			pr_info("%s: c_ent=%px\n", __func__, c_ent);
			list_add(&c_ent->ent.list, &cfs->ents);
			dump_ents(cfs);
			return &c_ent->cg;
		}
	}
	cg_err(&cfs->gdev, "entity type %s not found\n", c_ent->ent.drv_name);
	kfree(c_ent);
	return ERR_PTR(-EINVAL);

syntax_error:
	cg_err(&cfs->gdev,
		"couldn't create entity %s, wrong syntax.", name);
	return ERR_PTR(-EINVAL);
}

/* --------------------------------------------------------------------------
 * Default group: Links
 */

static struct configfs_group_operations vimc_cfs_dlink_group_ops = {
	.make_item	= vimc_cfs_link_make_item,
	.drop_item	= vimc_cfs_link_drop_item,
};

static struct config_item_type vimc_cfs_dlink_type = {
	.ct_group_ops	= &vimc_cfs_dlink_group_ops,
	.ct_owner	= THIS_MODULE,
};

void vimc_cfs_dlink_add_default_group(struct vimc_cfs_device *cfs)
{
	config_group_init_type_name(&cfs->glinks, "links",
				    &vimc_cfs_dlink_type);
	configfs_add_default_group(&cfs->glinks, &cfs->gdev);
}

/* --------------------------------------------------------------------------
 * Default group: Entities
 */

static struct configfs_group_operations vimc_cfs_dent_group_ops = {
	.make_group	= vimc_cfs_ent_make_group,
	.drop_item	= vimc_cfs_ent_drop_item,
};

static struct config_item_type vimc_cfs_dent_type = {
	.ct_group_ops	= &vimc_cfs_dent_group_ops,
	.ct_owner	= THIS_MODULE,
};

void vimc_cfs_dent_add_default_group(struct vimc_cfs_device *cfs)
{
	config_group_init_type_name(&cfs->gents, "entities",
				    &vimc_cfs_dent_type);
	configfs_add_default_group(&cfs->gents, &cfs->gdev);
}

/* --------------------------------------------------------------------------
 * Device instance
 */

static int vimc_cfs_decode_state(const char *buf, size_t size)
{
	unsigned int i, j;

	for (i = 0; i < ARRAY_SIZE(vimc_cfs_hotplug_values); i++) {
		for (j = 0; j < ARRAY_SIZE(vimc_cfs_hotplug_values[0]); j++) {
			if (!strncmp(buf, vimc_cfs_hotplug_values[i][j], size))
				return i;
		}
	}
	return -EINVAL;
}

static ssize_t vimc_cfs_dev_attr_hotplug_show(struct config_item *item,
					      char *buf)
{
	struct vimc_cfs_device *cfs = container_of(item, struct vimc_cfs_device,
						   gdev.cg_item);

	strcpy(buf, vimc_cfs_hotplug_values[is_plugged(cfs)][0]);
	return strlen(buf);
}

static int vimc_cfs_hotplug_set(struct vimc_cfs_device *cfs,
				enum vimc_cfs_hotplug_state state)
{
	if (state == is_plugged(cfs)) {
		return 0;
	} else if (state == VIMC_CFS_HOTPLUG_STATE_UNPLUGGED) {
		vimc_cfs_device_unplug(cfs);
		return 0;
	} else if (state == VIMC_CFS_HOTPLUG_STATE_PLUGGED) {
		return vimc_cfs_device_plug(cfs);
	}
	return -EINVAL;
}

static ssize_t vimc_cfs_dev_attr_hotplug_store(struct config_item *item,
					       const char *buf, size_t size)
{
	struct vimc_cfs_device *cfs = container_of(item, struct vimc_cfs_device,
						   gdev.cg_item);
	int state = vimc_cfs_decode_state(buf, size);

	if (vimc_cfs_hotplug_set(cfs, state))
		return -EINVAL;
	return size;
}

CONFIGFS_ATTR(vimc_cfs_dev_attr_, hotplug);

static struct configfs_attribute *vimc_cfs_dev_attrs[] = {
	&vimc_cfs_dev_attr_attr_hotplug,
	NULL,
};

static void vimc_cfs_dev_release(struct config_item *item)
{
	struct vimc_cfs_device *cfs = container_of(item, struct vimc_cfs_device,
						   gdev.cg_item);

	pr_info("%s: releasing cfs %px\n", __func__, cfs);
	kfree(cfs);
}

static struct configfs_item_operations vimc_cfs_dev_item_ops = {
	.release	= vimc_cfs_dev_release,
};

static struct config_item_type vimc_cfs_dev_type = {
	.ct_item_ops	= &vimc_cfs_dev_item_ops,
	.ct_attrs	= vimc_cfs_dev_attrs,
	.ct_owner	= THIS_MODULE,
};

static void vimc_cfs_dev_drop_item(struct config_group *group,
				   struct config_item *item)
{
	struct vimc_cfs_device *cfs = container_of(to_config_group(item),
						   struct vimc_cfs_device,
						   gdev);

	if (is_plugged(cfs))
		vimc_cfs_device_unplug(cfs);
	pr_info("%s: droping cfs=%px\n", __func__, cfs);
	config_item_put(item);
}

static struct config_group *vimc_cfs_dev_make_group(
				struct config_group *group, const char *name)
{
	struct vimc_cfs_device *cfs = kzalloc(sizeof(*cfs), GFP_KERNEL);

	pr_info("%s: start cfs=%px &cfs->pdata=%px\n", __func__, cfs, &cfs->pdata);
	if (!cfs)
		return ERR_PTR(-ENOMEM);

	/* Configure platform data */
	INIT_LIST_HEAD(&cfs->ents);
	INIT_LIST_HEAD(&cfs->links);
	cfs->pdata.links = &cfs->links;
	cfs->pdata.ents = &cfs->ents;

	pr_info("%s: start cfs=%px &cfs->pdata.ents=%px\n", __func__, cfs, &cfs->ents);

	/* Configure configfs group */
	config_group_init_type_name(&cfs->gdev, name, &vimc_cfs_dev_type);
	vimc_cfs_dent_add_default_group(cfs);
	vimc_cfs_dlink_add_default_group(cfs);

	return &cfs->gdev;
}

/* --------------------------------------------------------------------------
 * Subsystem
 */

static struct configfs_group_operations vimc_cfs_subsys_group_ops = {
	/* Create vimc devices */
	.make_group	= vimc_cfs_dev_make_group,
	.drop_item	= vimc_cfs_dev_drop_item,
};

static struct config_item_type vimc_cfs_subsys_type = {
	.ct_group_ops	= &vimc_cfs_subsys_group_ops,
	.ct_owner	= THIS_MODULE,
};

int vimc_cfs_subsys_register(void)
{
	struct configfs_subsystem *subsys = &vimc_cfs_subsys.subsys;
	int ret;

	INIT_LIST_HEAD(&vimc_cfs_subsys.drvs);
	config_group_init_type_name(&subsys->su_group, CFS_SUBSYS_NAME,
				    &vimc_cfs_subsys_type);
	mutex_init(&subsys->su_mutex);
	ret = configfs_register_subsystem(subsys);

	return ret;
}

void vimc_cfs_subsys_unregister(void)
{
	configfs_unregister_subsystem(&vimc_cfs_subsys.subsys);
}
