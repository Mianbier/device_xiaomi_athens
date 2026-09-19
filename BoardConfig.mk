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

# =============================================================================
# ★ 构建期源码补丁 (双保险之一; 另一处在 vendorsetup.sh)
#
#   故障: recovery 刷入后能看到橙狐 splash, 但界面永远停在那里, 完全点不动。
#   根因: system/vold 里包装 keystore2 的那个类, 构造函数用的是
#             AServiceManager_waitForService("android.system.keystore2.IKeystoreService/default")
#         注意是 waitForService, 那是 **无限阻塞** 的。而 recovery ramdisk 里
#         没有 KeyMint HAL, keystore2 每 5 秒崩溃重启一次, 永远注册不上这个服务,
#         于是 recovery 主线程永久挂死在 futex_wait。
#         调用链: Decrypt_Page -> Decrypt_Device -> Decrypt_DE()
#                 -> fscrypt_initialize_systemwide_keys() -> retrieveKey()
#                 -> KeyStorage.cpp: Keystore/Keymaster 构造函数 -> ★阻塞★
#
#   修法: 解析本文件时就把源码改成 "checkService + 最多 15 秒重试"。
#         这两个类都有 operator bool(), 而每个构造点后面都紧跟
#         "if (!keystore) return false;" 守卫, 所以拿不到服务只会解密失败, 不会卡死。
#
#   脚本是幂等的(已打过就跳过, 不碰 mtime); 找不到源码树也安静退出, 绝不让构建失败。
#   完整分析见 device/xiaomi/athens/patch_keystore2_wait.py 文件头。
# =============================================================================
$(shell ATHENS_TOP="$$PWD" python3 $(DEVICE_PATH)/patch_keystore2_wait.py 1>&2)

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
# ⚠️ fox_12.1 的 config.mk 会校验此列表, 只接受它认识的动态分区名。
#    设备上真实存在的 system_dlkm / mi_ext 在 12.1 里不被承认, 必须剔除,
#    否则报: BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST contains invalid
#    partition name system_dlkm mi_ext
#    (TWRP 运行时靠 lpdump 读真实 super 布局, 所以照样能挂载这两个分区)
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system system_ext product vendor vendor_dlkm odm

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
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_ODM := odm
# 注: system_dlkm / mi_ext 在 fox_12.1 中不被构建系统承认, 故不声明其
#     BOARD_*IMAGE_FILE_SYSTEM_TYPE / TARGET_COPY_OUT_*, 否则会被当作未知分区处理。

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
# 注: 不设 TW_SCREEN_BLANK_ON_BOOT。
#     它与 TW_NO_SCREEN_BLANK 语义冲突, 而且开机就把屏幕熄灭, 在触摸还没
#     调好的阶段会直接表现为"全黑 = 像是没启动"。先保证屏幕常亮。

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
# -----------------------------------------------------------------------------
# TW_EXCLUDE_DEFAULT_USB_INIT := true  —— 必须为 true, 但不是"什么都不做"
#
#   橙狐自带的 bootable/recovery/etc/init.recovery.usb.rc 用的是**老式**
#   /sys/class/android_usb/android0 接口 (f_functions / f_ffs / enable)。
#   SM8850 的 UDC 只支持 configfs, 那套节点根本不存在, 所以默认那份在本机
#   是无效的, 必须排除。
#
#   ⚠️ 排除之后**必须**由设备树自己补一份 configfs 版本的:
#       recovery/root/init.recovery.usb.rc
#   两者都缺的话 (本设备树修复前的情况), init.rc 里
#       import /init.recovery.usb.rc
#   找不到文件, recovery 下 adb / MTP / fastbootd 会全部不通。
# -----------------------------------------------------------------------------
TW_EXCLUDE_DEFAULT_USB_INIT := true
TARGET_RECOVERY_USB_RC := $(DEVICE_PATH)/recovery/root/init.recovery.usb.rc
# 用户态 fastboot (fastbootd) —— 与 recovery/root/init.recovery.usb.rc 里的
# sys.usb.config=fastboot 规则配套
TW_INCLUDE_FASTBOOTD := true
TW_USE_TOOLBOX := true
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
TW_OVERRIDE_SYSTEM_PROPS := "ro.build.fingerprint=ro.vendor.build.fingerprint;ro.build.version.incremental"

TARGET_RECOVERY_QCOM_RTC_FIX := true
RECOVERY_SDCARD_ON_DATA := true

# =========================================================
# 输入 / 触摸  (原厂触摸 IC = FocalTech FT3685G, 驱动在 vendor_dlkm)
#   与同平台 SM8850/canoe 的 myron(K90 Pro Max) / songyuan(K100 Pro Max)
#   已验证配置对齐。
# =========================================================
TW_CUSTOM_TOUCH_DEVICE := "/dev/input/event7"
# uinput-xiaomi 是小米的虚拟输入设备, 会被 TWRP 误判为触摸屏 -> 必须排除
TW_INPUT_BLACKLIST := "hbtp_vm:uinput-xiaomi"

# 振动
TW_SUPPORT_INPUT_AIDL_HAPTICS := true
TW_SUPPORT_INPUT_AIDL_HAPTICS_FIX_OFF := true
TW_SUPPORT_INPUT_AIDL_HAPTICS_FQNAME := "IVibrator/vibratorfeature"
TW_NO_HAPTICS := false

# =========================================================
# 内核模块
#   来源: /vendor/lib/modules -> /vendor_dlkm/lib/modules
#   顺序按依赖链排列 (base QMI/GLINK/PDR/RPROC -> ADSP/Q6 -> PCIe/USB/网络
#   -> WLAN -> PMIC/panel/touch/flash/haptics -> secure invoke)
#   触摸链: gh_irq_lend.ko -> panel_event_notifier.ko -> xiaomi_touch.ko
#           -> focaltech_touch_3685g.ko
#   注: athens 用 focaltech_touch_3685g.ko (songyuan 是 _1 变体, 不可混用)
# =========================================================
TW_LOAD_VENDOR_MODULES := "bq27z561.ko qmi_helpers.ko qcom_glink.ko qcom_glink_smem.ko qcom_smd.ko rproc_qcom_common.ko qcom_pdr_msg.ko pdr_interface.ko qcom_sysmon.ko qcom_q6v5.ko qcom_ramdump.ko qcom_va_minidump.ko qcom_pil_info.ko qcom_q6v5_pas.ko q6_pdr_dlkm.ko q6_notifier_dlkm.ko snd_event_dlkm.ko gpr_dlkm.ko spf_core_dlkm.ko adsp_loader_dlkm.ko q6_dlkm.ko pcie-pdc.ko pci-msm-drv.ko mhi.ko wcd_usbss_i2c.ko usb_f_gsi.ko dwc3-msm.ko repeater.ko redriver.ko ipam.ko gsim.ko rmnet_mem.ko smem-mailbox.ko cfg80211.ko mac80211.ko wlan_firmware_service.ko cnss_prealloc.ko cnss_utils.ko cnss_nl.ko cnss_plat_ipc_qmi_svc.ko cnss2.ko qca_cld3_peach_v2.ko qca_cld3_wcn7750.ko qti_pmic_glink.ko qti_battery_charger.ko panel_event_notifier.ko gh_irq_lend.ko xiaomi_touch.ko focaltech_touch_3685g.ko swr_dlkm.ko mca_sysfs.ko mca_event.ko mca_log.ko mca_parse_dts.ko mca_charge_mievent.ko mca_protocol_class.ko mca_protocol_qc_class.ko mca_platform_bc12_class.ko mca_platform_buckchg_class.ko mca_strategy_class.ko mca_adsp_glink.ko mca_qcom_subpmic_proxy.ko leds-qcom-flash.ko leds-qpnp-vibrator-ldo.ko qcom-hv-haptics.ko swr_haptics_dlkm.ko smcinvoke_dlkm.ko qsee_ipc_irq_bridge.ko stm_st54se_gpio.ko stm_nfc_i2c.ko"
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
TW_LOAD_PREBUILT_MODULES_AT_FIRST := true

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
# 额外 vendor 属性
# =========================================================
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# 注: 不设 BOARD_VNDK_VERSION —— 本设备树不构建任何 vendor 模块,
#     而 fox_12.1 的 VNDK 快照不一定齐全, 设了反而可能报错。
#     (参考同分支可用树 marble 也未设置)
