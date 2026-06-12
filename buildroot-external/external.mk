# External tree used for board configuration, overlays and local packages.

include $(sort $(wildcard $(BR2_EXTERNAL_MPSOC_IMAGE_BUILDER_PATH)/package/*/*.mk))
