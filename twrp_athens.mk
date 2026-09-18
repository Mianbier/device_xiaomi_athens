# =============================================================================
# twrp_athens.mk  — 顶层产品定义
# Device:   Xiaomi athens (Redmi K100 Pro)
# Platform: Canoe / SM8850 (Snapdragon 8 Elite Gen 5)
# OS:       Android 16 / HyperOS 4.0
#
# 文件名必须与 PRODUCT_NAME 一致 (twrp_athens.mk <-> PRODUCT_NAME := twrp_athens)
# =============================================================================

# 设备代号 / 路径
PRODUCT_RELEASE_NAME := athens
DEVICE_PATH := device/xiaomi/$(PRODUCT_RELEASE_NAME)

# --- AOSP 基础 ---
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# --- 设备专属 ---
$(call inherit-product, $(DEVICE_PATH)/device.mk)

# --- OrangeFox 专属设置 (OF_*) ---
$(call inherit-product-if-exists, $(DEVICE_PATH)/fox_$(PRODUCT_RELEASE_NAME).mk)

# --- TWRP 公共配置 ---
$(call inherit-product, vendor/twrp/config/common.mk)

# --- 产品标识 (必须放在所有 inherit 之后) ---
PRODUCT_DEVICE       := athens
PRODUCT_NAME         := twrp_athens
PRODUCT_BRAND        := Xiaomi
PRODUCT_MODEL        := Redmi K100 Pro
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_CHARACTERISTICS := nosdcard

# OrangeFox 构建器读取
FOX_BUILD_DEVICE := athens
FOX_VENDOR       := Xiaomi
FOX_DEVICE_ALT   := "Redmi K100 Pro"
TARGET_DEVICE_ALT := "athens"
