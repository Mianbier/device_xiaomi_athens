# ==========================================================
# twrp_athens.mk — Redmi K100 Pro (athens) product makefile
# 注意: 构建器执行 `lunch twrp_athens-eng`, 故 PRODUCT_NAME 必须为 twrp_athens
# ==========================================================

PRODUCT_NAME := twrp_athens
PRODUCT_DEVICE := athens
PRODUCT_MODEL := Redmi K100 Pro
PRODUCT_BRAND := Xiaomi
PRODUCT_MANUFACTURER := xiaomi
PRODUCT_CHARACTERISTICS := nosdcard

# TWRP / 最小系统核心 (提供 recoveryimage 目标)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_minimal.mk)
$(call inherit-product, vendor/twrp/configs/twrp.mk)

# 设备级配置 (BoardConfig.mk 由构建系统按 PRODUCT_DEVICE 自动包含)
$(call inherit-product, $(DEVICE_PATH)/device.mk)

# OrangeFox 标识
FOX_BUILD_DEVICE := athens
FOX_VENDOR := Xiaomi
FOX_DEVICE_ALT := "Redmi K100 Pro"
