# =============================================================================
# device.mk  — 设备级包与属性声明
# Device: Xiaomi athens (Redmi K100 Pro) / Canoe (SM8850) / Android 16
#
# 说明: 本文件不声明 vendor 预编译二进制/内核模块。
#       解密相关的 vendor 服务与 .ko 会放在 recovery/root/ 下由构建系统叠加进
#       recovery ramdisk。
# =============================================================================

# --- AOSP 基础继承 ---
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)

# 无 sdcardfs 的模拟存储 (支持 project quota / casefolding)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# 把 GSI 公钥装进 ramdisk (验证启动用)
$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_keys.mk)

# --- 平台 ---
QCOM_BOARD_PLATFORMS += canoe
TARGET_BOARD_PLATFORM := canoe
TARGET_BOOTLOADER_BOARD_NAME := canoe

# --- A/B ---
AB_OTA_UPDATER := true

# --- Virtual A/B ---
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)

# 注: 设备上还有 system_dlkm / mi_ext 两个动态分区, 但 fox_12.1 的构建系统
#     不承认它们, 放进 AB_OTA_PARTITIONS 会触发校验报错, 故此处不列。
#     TWRP 运行时通过 lpdump 读真实 super 布局, 仍可挂载。
AB_OTA_PARTITIONS ?= \
    boot \
    init_boot \
    vendor_boot \
    recovery \
    dtbo \
    vbmeta \
    vbmeta_system \
    system \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    odm

# --- A/B 相关包 ---
PRODUCT_PACKAGES += \
    update_engine \
    update_engine_client \
    update_engine_sideload \
    update_verifier \
    android.hardware.boot@1.2-impl-qti \
    android.hardware.boot@1.2-impl-qti.recovery \
    android.hardware.boot@1.2-service

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_vendor=true \
    POSTINSTALL_PATH_vendor=bin/checkpoint_gc \
    FILESYSTEM_TYPE_vendor=erofs \
    POSTINSTALL_OPTIONAL_vendor=true

# --- Soong namespace ---
PRODUCT_SOONG_NAMESPACES += \
    $(DEVICE_PATH)

# --- 动态分区 ---
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# --- fastbootd ---
PRODUCT_PACKAGES += \
    fastbootd \
    android.hardware.fastboot@1.1-impl-mock

# --- f2fs / ext4 工具 ---
PRODUCT_PACKAGES += \
    sg_write_buffer \
    f2fs_io \
    check_f2fs

# --- Userdata checkpoint ---
PRODUCT_PACKAGES += \
    checkpoint_gc

# --- QCOM 解密 (FBE) ---
PRODUCT_PACKAGES += \
    qcom_decrypt \
    qcom_decrypt_fbe

# --- 屏幕密度 (1440 x 3200, QHD+) ---
PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=560

# --- Treble ---
PRODUCT_PROPERTY_OVERRIDES += \
    ro.treble.enabled=true

# =============================================================================
# recovery/root 叠加层  ★ 关键 ★
#
#   OrangeFox / TWRP 的标准机制: 用 find-copy-subdir-files 把
#   $(DEVICE_PATH)/recovery/root 整个目录映射进 recovery ramdisk 的根 /。
#
#   ⚠️ 这一行之前是缺失的 —— 所以 recovery/root 下的文件（设备专属 init 层、
#      触摸固件加载脚本）根本不会进镜像。参考同平台已验证的设备树
#      songyuan / myron / annibale / nezha 的 device.mk 都有这一行。
#
#   本目录当前内容:
#     init.recovery.qcom.rc                 <- init.rc 里 import 的就是它
#     init.recovery.usb.rc                  <- configfs USB gadget (adb/MTP/fastboot)
#     system/bin/athens-touch-fw-load.sh    <- 加载原厂 FT3685G 触摸固件
# =============================================================================
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(DEVICE_PATH)/recovery/root,recovery/root)

# -----------------------------------------------------------------------------
# 触摸固件 (从原厂 odm.img 提取)
#   focaltech_touch_3685g.ko 自带的 fallback 固件 THP 帧布局与 athens 面板不符,
#   必须用原厂这份 148220 字节的固件。
#   同时放 /odm/firmware 与 /vendor/firmware:
#   TWRP 挂载真实 odm/vendor 分区后会盖掉 ramdisk 副本, 未挂载时用副本兜底。
# -----------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/prebuilt/odm/firmware/focaltech_ts_fw_athens.bin:recovery/root/odm/firmware/focaltech_ts_fw_athens.bin \
    $(DEVICE_PATH)/prebuilt/odm/firmware/focaltech_ts_fw_athens.bin:recovery/root/vendor/firmware/focaltech_ts_fw_athens.bin

# --- A/B OTA 分区列表 ---
PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.ab_ota_partitions=boot,init_boot,vendor_boot,recovery,dtbo,system,system_ext,product,vendor,vendor_dlkm,system_dlkm,odm,mi_ext
