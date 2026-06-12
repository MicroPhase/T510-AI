################################################################################
#
# rootfs-fixups
#
################################################################################

ROOTFS_FIXUPS_VERSION = 1.0
ROOTFS_FIXUPS_SITE = $(BR2_EXTERNAL_MPSOC_IMAGE_BUILDER_PATH)/package/rootfs-fixups/src
ROOTFS_FIXUPS_SITE_METHOD = local
ROOTFS_FIXUPS_INSTALL_TARGET = NO

define ROOTFS_FIXUPS_REMOVE_TOOLCHAIN_LDSO_CONF
	rm -f $(TARGET_DIR)/etc/ld.so.conf
	rm -rf $(TARGET_DIR)/etc/ld.so.conf.d
endef

ROOTFS_FIXUPS_TARGET_FINALIZE_HOOKS += ROOTFS_FIXUPS_REMOVE_TOOLCHAIN_LDSO_CONF

$(eval $(generic-package))
