################################################################################
#
# librfdc
#
################################################################################

LIBRFDC_VERSION = 1.1
LIBRFDC_SITE = $(BR2_EXTERNAL_MPSOC_IMAGE_BUILDER_PATH)/../embeddedsw/XilinxProcessorIPLib/drivers/rfdc/src
LIBRFDC_SITE_METHOD = local
LIBRFDC_INSTALL_STAGING = YES
LIBRFDC_LICENSE = MIT
LIBRFDC_DEPENDENCIES = libmetal

define LIBRFDC_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) -f Makefile.Linux \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS) -I$(@D) -I$(STAGING_DIR)/usr/include" \
		LDFLAGS="$(TARGET_LDFLAGS) -L$(STAGING_DIR)/usr/lib"
endef

define LIBRFDC_INSTALL_STAGING_CMDS
	$(INSTALL) -D -m 0755 $(@D)/librfdc.so.$(LIBRFDC_VERSION) $(STAGING_DIR)/usr/lib/librfdc.so.$(LIBRFDC_VERSION)
	ln -sf librfdc.so.$(LIBRFDC_VERSION) $(STAGING_DIR)/usr/lib/librfdc.so.1
	ln -sf librfdc.so.1 $(STAGING_DIR)/usr/lib/librfdc.so
	$(INSTALL) -D -m 0644 $(@D)/xrfdc.h $(STAGING_DIR)/usr/include/xrfdc.h
	$(INSTALL) -D -m 0644 $(@D)/xrfdc_hw.h $(STAGING_DIR)/usr/include/xrfdc_hw.h
endef

define LIBRFDC_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/librfdc.so.$(LIBRFDC_VERSION) $(TARGET_DIR)/usr/lib/librfdc.so.$(LIBRFDC_VERSION)
	ln -sf librfdc.so.$(LIBRFDC_VERSION) $(TARGET_DIR)/usr/lib/librfdc.so.1
	ln -sf librfdc.so.1 $(TARGET_DIR)/usr/lib/librfdc.so
endef

$(eval $(generic-package))
