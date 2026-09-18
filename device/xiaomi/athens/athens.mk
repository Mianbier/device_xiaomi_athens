# ==========================================================
# athens.mk — Redmi K100 Pro (athens) product makefile
# ==========================================================

PRODUCT_NAME := athens
PRODUCT_DEVICE := athens
PRODUCT_MODEL := Redmi K100 Pro
PRODUCT_BRAND := Xiaomi
PRODUCT_MANUFACTURER := xiaomi
PRODUCT_CHARACTERISTICS := nosdcard

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=athens \
    TARGET_DEVICE=athens \
    PRIVILEGED_FIXED_SDK_VERSION=0

PRODUCT_GMS_CLIENT := false

# 继承设备配置 (BoardConfig.mk 由构建系统按 PRODUCT_DEVICE 自动包含)
$(call inherit-product, $(DEVICE_PATH)/device.mk)

# OrangeFox 标识
FOX_BUILD_DEVICE := athens
FOX_VENDOR := Xiaomi
FOX_DEVICE_ALT := "Redmi K100 Pro"
