################################################################################
#
# libmetal
#
################################################################################

LIBMETAL_VERSION = xilinx-2022.2
LIBMETAL_SITE = $(BR2_EXTERNAL_MPSOC_IMAGE_BUILDER_PATH)/../embeddedsw/ThirdParty/sw_services/libmetal/src/libmetal
LIBMETAL_SITE_METHOD = local
LIBMETAL_INSTALL_STAGING = YES
LIBMETAL_LICENSE = BSD-3-Clause
LIBMETAL_LICENSE_FILES = LICENSE.md
LIBMETAL_DEPENDENCIES = eudev

LIBMETAL_CONF_OPTS = \
	-DWITH_DOC=OFF \
	-DWITH_TESTS=OFF \
	-DWITH_SHARED_LIB=ON \
	-DWITH_STATIC_LIB=OFF \
	-DLIBUDEV_FOUND=ON \
	-DLIBUDEV_INCLUDE_DIR=$(STAGING_DIR)/usr/include \
	-DLIBUDEV_LIBRARIES=$(STAGING_DIR)/usr/lib/libudev.so

define LIBMETAL_RELAX_UDEV_DEP
	python3 $(BR2_EXTERNAL_MPSOC_IMAGE_BUILDER_PATH)/../scripts/patch_libmetal_depends.py "$(@D)/cmake/depends.cmake"
endef

LIBMETAL_POST_RSYNC_HOOKS += LIBMETAL_RELAX_UDEV_DEP

$(eval $(cmake-package))
