# ==========================================================
# device.mk — 设备级额外配置 (被 athens.mk 继承)
# ==========================================================

# 屏幕密度 (来自 HyperOS 默认, 真机以 wm density 为准)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=480

# 标记设备为 A/B
PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.ab_ota_partitions=boot,system,system_ext,vendor,vendor_dlkm,product,odm,mi_ext,mi_product

# 关闭 Treble 兼容性强制检查 (防止 OrangeFox 启动报红)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.treble.enabled=true
