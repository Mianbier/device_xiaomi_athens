# =============================================================================
# Android.mk — GNU Make 入口
# Device: Xiaomi athens (Redmi K100 Pro)
#
# 只在目标设备为 athens 时包含子目录 makefile, 避免在同一源码树里为其它设备
# 构建时误入。
# =============================================================================

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),athens)
    include $(call all-subdir-makefiles,$(LOCAL_PATH))
endif
