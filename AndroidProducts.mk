# =============================================================================
# AndroidProducts.mk
# Device: Xiaomi athens (Redmi K100 Pro)
# OrangeFox fox_12.1
#
# 重要 (踩坑记录):
#   Android 构建系统的 _decode-product-name 在 PRODUCT_MAKEFILES 条目中
#   没有 ':' 时, 会用「产品 mk 文件的文件名(去掉 .mk)」当作产品名。
#   因此产品 mk 文件必须叫 twrp_athens.mk, 且 PRODUCT_NAME := twrp_athens,
#   两者必须完全一致。否则 lunch twrp_athens-eng 会报:
#     "Can not locate config makefile for product twrp_athens"
# =============================================================================

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/twrp_athens.mk

COMMON_LUNCH_CHOICES := \
    twrp_athens-eng \
    twrp_athens-userdebug
