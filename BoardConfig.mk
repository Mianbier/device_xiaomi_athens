# =============================================================================
# BoardConfig.mk
# Device:   Xiaomi athens (Redmi K100 Pro)
# Platform: Canoe / SM8850 (Snapdragon 8 Elite Gen 5)
# OS:       Android 16 / HyperOS 4.0  (swinfo.fingerprint=athens:16/OS4.0.0.8.XPICN)
#
# 原厂镜像实测参数 (从 target_payload 提取):
#   recovery.img  : ANDROID! header v4, kernel_size=0, ramdisk=LZ4 (02214c18),
#                   ramdisk 起点 offset 4096, ramdisk 约 28.4 MB
#   vendor_boot   : VNDRBOOT header v4, page_size 4096, vendor_ramdisk 21.8 MB,
#                   dtb 6.5 MB
#   boot.img      : kernel 42101248 bytes (未压缩 ARM64 Image, MZ 魔数)
#   dtbo          : "Qualcomm Technologies, Inc. Athens based on SM8850"
# =============================================================================

DEVICE_PATH := device/xiaomi/athens
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab

# --- 放宽源码树的严格检查 (GKI / Android16 设备必需) ---
ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_MISSING_REQUIRED_MODULES := true

# =========================================================
# 架构
# =========================================================
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := generic

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic

TARGET_SUPPORTS_64_BIT_APPS := true

# --- 平台 ---
PRODUCT_PLATFORM := canoe
TARGET_BOARD_PLATFORM := canoe
TARGET_BOARD_PLATFORM_GPU := qcom-adreno840
TARGET_BOOTLOADER_BOARD_NAME := canoe
TARGET_USES_HARDWARE_QCOM := true
QCOM_BOARD_PLATFORMS += canoe

TARGET_NO_BOOTLOADER := false
TARGET_USES_UEFI := true
TARGET_USES_REMOTEPROC := true

# =========================================================
# 内核 / boot header (GKI v4)
# =========================================================
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
BOARD_MKBOOTIMG_ARGS := --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_KERNEL_IMAGE_NAME := Image

# 原厂 recovery.img 的 kernel_size = 0 —— GKI 设备的 "ramdisk-only recovery"
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
BOARD_RAMDISK_USE_LZ4 := true
TARGET_NO_KERNEL_OVERRIDE := true

# 预编译内核 (仅在构建 bootimage 时使用)
BOARD_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
TARGET_PREBUILT_KERNEL := $(BOARD_PREBUILT_KERNEL)

# 原厂 vendor_boot cmdline (实测)
BOARD_KERNEL_CMDLINE := video=vfb:640x400,bpp=32,memsize=3072000 erofs.reserved_pages=64 swinfo.fingerprint=athens:16/OS4.0.0.8.XPICN:user androidboot.hardware=qcom loop.max_part=7 bootconfig

# =========================================================
# A/B 与 recovery
# =========================================================
AB_OTA_UPDATER := true
BOARD_USES_RECOVERY_AS_BOOT := false

# =========================================================
# 分区尺寸 (实测自 target_payload)
# =========================================================
BOARD_FLASH_BLOCK_SIZE := 262144          # BOARD_KERNEL_PAGESIZE * 64

BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296          # 96 MB
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296   # 96 MB
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600      # 100 MB
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608      # 8 MB
BOARD_DTBOIMG_PARTITION_SIZE := 33554432             # 32 MB
BOARD_CACHEIMAGE_PARTITION_SIZE := 0

# super: 动态分区实测合计 11.15 GiB -> 取 12 GiB
BOARD_SUPER_PARTITION_SIZE := 12884901888
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 12880707584     # super - 4 MB
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system system_ext product vendor vendor_dlkm system_dlkm odm mi_ext

# =========================================================
# 文件系统
# =========================================================
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_SYSTEM := system
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_PRODUCT := product
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_ODM := odm

TARGET_USERIMAGES_USE_F2FS := true
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USES_MKE2FS := true
BOARD_USES_METADATA_PARTITION := true

BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true

# =========================================================
# AVB
# =========================================================
BOARD_AVB_ENABLE := true
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

# =========================================================
# 加密 (原厂 first_stage_ramdisk/fstab.qcom 实测)
#   fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0
#   metadata_encryption=aes-256-xts:wrappedkey_v0
#   注意: Android 16 使用 Secretkeeper (Rust 实现), 主线橙狐无法解密 /data
# =========================================================
BOARD_USES_QCOM_FBE_DECRYPTION := true
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2

PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# =========================================================
# 屏幕 (原厂 dtbo 实测: nt37801 amoled cmd mode dsi csot panel with DSC)
#   1440 x 3200 @ 120Hz
# =========================================================
TARGET_SCREEN_WIDTH := 1440
TARGET_SCREEN_HEIGHT := 3200
TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
TW_THEME := portrait_hdpi
TW_FRAMERATE := 120
TW_NO_SCREEN_BLANK := true

TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_MAX_BRIGHTNESS := 16383
TW_DEFAULT_BRIGHTNESS := 8000
TW_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone75/temp"

# =========================================================
# TWRP 功能开关
# =========================================================
TW_DEFAULT_LANGUAGE := zh_CN
TW_EXTRA_LANGUAGES := true
TW_INCLUDE_NTFS_3G := true
TW_NO_EXFAT_FUSE := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_INCLUDE_7ZA := true
TW_INCLUDE_LPTOOLS := true
TW_EXCLUDE_APEX := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_USE_TOOLBOX := true
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
TW_OVERRIDE_SYSTEM_PROPS := "ro.build.fingerprint=ro.vendor.build.fingerprint;ro.build.version.incremental"

TARGET_RECOVERY_QCOM_RTC_FIX := true
RECOVERY_SDCARD_ON_DATA := true

# 振动 (AIDL)
TW_SUPPORT_INPUT_AIDL_HAPTICS := true
TW_SUPPORT_INPUT_AIDL_HAPTICS_FIX_OFF := true
TW_SUPPORT_INPUT_AIDL_HAPTICS_FQNAME := "IVibrator/vibratorfeature"

# 内核模块 (从原厂 vendor_boot 的 vendor_ramdisk 实测提取)
TW_LOAD_VENDOR_MODULES := "bq27z561.ko qti_battery_charger.ko xiaomi_touch.ko panel_event_notifier.ko msm_drm.ko adsp_loader_dlkm.ko"
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true

# =========================================================
# 日志 / 调试 (首次编译保留, 稳定后可关)
# =========================================================
TARGET_USES_LOGD := true
TWRP_INCLUDE_LOGCAT := true
TARGET_RECOVERY_DEVICE_MODULES += debuggerd
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/debuggerd
TARGET_RECOVERY_DEVICE_MODULES += strace
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/strace

# =========================================================
# VNDK
# =========================================================
BOARD_VNDK_VERSION := current

# =========================================================
# 额外 vendor 属性
# =========================================================
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop
