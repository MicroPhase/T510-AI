################################################################################
#
# t510-fnic-rfdc
#
################################################################################

T510_FNIC_RFDC_VERSION = 1.0
T510_FNIC_RFDC_SITE = $(BR2_EXTERNAL_MPSOC_IMAGE_BUILDER_PATH)/../board/t510-fnic/app_rfdc
T510_FNIC_RFDC_SITE_METHOD = local
T510_FNIC_RFDC_LICENSE = Proprietary
T510_FNIC_RFDC_DEPENDENCIES = libmetal

define T510_FNIC_RFDC_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) clean APP_RFDC_BIN=t510-fnic-rfdc
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		CPPFLAGS="-I$(@D) -I$(@D)/lmk04828 -I$(@D)/xrfdc -I$(STAGING_DIR)/usr/include" \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS) -L$(STAGING_DIR)/usr/lib" \
		APP_RFDC_BIN=t510-fnic-rfdc
endef

define T510_FNIC_RFDC_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/t510-fnic-rfdc \
		$(TARGET_DIR)/usr/sbin/t510-fnic-rfdc
	$(INSTALL) -D -m 0755 $(T510_FNIC_RFDC_PKGDIR)/S47t510-fnic-rfdc \
		$(TARGET_DIR)/etc/init.d/S47t510-fnic-rfdc
endef

$(eval $(generic-package))
