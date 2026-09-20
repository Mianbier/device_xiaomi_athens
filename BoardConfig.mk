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
# 屏幕
#
#   真实分辨率 1156 x 2510 @ 120Hz (cmd mode + DSC)
#     证据 1: /sys/class/drm/card0-DSI-1/modes -> "1156x2510x120cmd"
#     证据 2: 触摸 IC ABS_MT_POSITION_X/Y max = 115599 / 250999 (x100)
#     证据 3: recovery.log -> "width: 1156, height: 2510" (DRM mode hdisplay/vdisplay)
#
#   ⚠️ 之前写的 1440 x 3200 是错的。
#      TARGET_SCREEN_WIDTH/HEIGHT 只被 gui/libguitwrp_defaults.go 用来
#      "自动挑主题", 我们显式设了 TW_THEME, 所以它被绕过 —— 但为了
#      和同平台机型一致、也为了将来不被别的逻辑读到, 必须写真实值。
#
#   同平台 (SM8850/canoe) 四个机型 (myron/annibale/nezha/songyuan)
#   全部写成各自面板的真实分辨率 + TARGET_SCREEN_DENSITY := 480。
# =========================================================
TARGET_SCREEN_WIDTH := 1156
TARGET_SCREEN_HEIGHT := 2510
# -----------------------------------------------------------------------------
# ⚠️ 绝对不要设 TARGET_SCREEN_DENSITY ！
#
#   R9 那一版两个构建 (14.1 run 35479116109 / 12.1 run 35479575426) 都在 98%
#   挂在同一步, 报错:
#
#       FAILED: out/target/product/athens/vendor/build.prop
#       error: found duplicate sysprop assignments:
#       ro.sf.lcd_density=480
#       ro.sf.lcd_density=560
#
#   原因: TARGET_SCREEN_DENSITY 是 **AOSP build/make 层**的变量, 会被写进
#         ADDITIONAL_VENDOR_PROPERTIES 生成 ro.sf.lcd_density;
#         而 device.mk:109 已经用 PRODUCT_PROPERTY_OVERRIDES 设了
#         ro.sf.lcd_density=560。
#         同一个属性被赋值两次 -> post_process_props 直接判死。
#         (注意: 即使两边值相同也会报, 它检查的是属性名重复)
#
#   教训: 同平台参考机型 (myron/annibale/nezha/songyuan) 写了
#         TARGET_SCREEN_DENSITY := 480, 是因为它们的 device.mk **没有**再设
#         ro.sf.lcd_density。我们有了, 就不能再写 —— 照抄参考树前必须先
#         确认自己没有等价设置。
#
#   验真方法也要修正: TARGET_SCREEN_DENSITY 这类 AOSP 变量**不在**
#   bootable/recovery 里接线, 只 grep recovery 树会得出"没接线"的错误结论。
# -----------------------------------------------------------------------------
# TARGET_SCREEN_DENSITY := 480
TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
TW_THEME := portrait_hdpi
TW_NO_SCREEN_BLANK := true

# -----------------------------------------------------------------------------
# TW_SCREEN_BLANK_ON_BOOT := true
#
#   ⚠️ 诚实说明: 这个开关在橙狐 14.1 里**没有接线**。
#      全树只有 gui/gui.cpp:895 的 `#ifdef TW_SCREEN_BLANK_ON_BOOT`,
#      没有任何 Android.mk / Android.bp / *.go 定义这个宏 —— 所以它目前是空操作。
#
#      保留它的理由只有一个: 同平台 4/4 机型 (myron/annibale/nezha/songyuan)
#      全都写了这一行。如果哪天橙狐在 recovery 树之外补上接线, 我们就能跟
#      已验证配置保持一致。它对当前构建无副作用。
#
#   gui/gui.cpp:895 的原意 (供将来接线后参考):
#       blankTimer.blank();  blankTimer.resetTimerAndUnblank();
#   即"立刻灭一次再立刻点亮", 是这几块 QCOM cmd-mode 面板的开机初始化怪癖补偿。
#   因为已经开了 TW_NO_SCREEN_BLANK, blank() 不会走 gr_fb_blank(),
#   只把背光写 0 然后马上恢复, 不存在"开机黑屏"风险。
#
#   真正会造成「黑屏且唤不醒」的是屏幕超时 (blankTimer.checkForTimeout):
#   它把背光写 0, 而触摸又不能用就唤不醒。所以先修触摸。
#   若触摸一时修不好, 可用 TW_NO_SCREEN_TIMEOUT := true 临时保命
#   (这个开关**是**接了线的: Android.mk:252)。
# -----------------------------------------------------------------------------
TW_SCREEN_BLANK_ON_BOOT := true

# -----------------------------------------------------------------------------
# TW_NO_SCREEN_TIMEOUT := true  —— 【本次 bring-up 临时保险，触摸确认后删掉】
#
#   这个开关**是接了线的**: Android.mk:252 `ifneq ($(TW_NO_SCREEN_TIMEOUT),)`
#   -> `-DTW_NO_SCREEN_TIMEOUT`。定义后 gui/blanktimer.cpp 的
#   checkForTimeout() 整个函数体被编译掉, 屏幕永不自动熄灭。
#
#   为什么要临时开:
#       14.1 上一版触摸完全不能用, 而屏幕超时会把背光写 0 —— 于是屏幕变黑
#       且唤不醒 (processInput 里 KEY_POWER 被显式排除在 unblank 之外,
#       只有音量键能唤醒), 用户无法判断 recovery 到底起没起来。
#       这是已经发生过两次的失败模式。
#
#   触摸确认可用后, 把这一行删掉即可恢复正常息屏。
# -----------------------------------------------------------------------------
TW_NO_SCREEN_TIMEOUT := true

# -----------------------------------------------------------------------------
# TW_FRAMERATE := 120  —— 不要写, 在 OrangeFox 14.1 里它是死配置
#
#   全树检索确认: TW_FRAMERATE 只出现在
#       gui/objects.hpp:56-57   #ifndef TW_FRAMERATE / #define TW_FRAMERATE 30
#       gui/gui.cpp:645         1.0 / TW_FRAMERATE * 1000000000
#       gui/animation.cpp:129
#   没有任何 Android.mk / Android.bp / *.go (Soong 插件) 把它变成 CFLAG。
#   所以实际生效值恒为 30 FPS, 写 120 只是让人误以为跑在 120Hz。
# -----------------------------------------------------------------------------
# TW_FRAMERATE := 120

TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_MAX_BRIGHTNESS := 16383
# 同平台机型用 950 (约 6%); 8000 (约 49%) 在暗环境刺眼, 且 PWM 低亮度区间
# 有些面板会闪。跟随同平台取 950。
TW_DEFAULT_BRIGHTNESS := 950
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
# 输入 / 触摸
#   触摸 IC = FocalTech FT3685G (spi19.0), 驱动 focaltech_touch_3685g.ko
#   + xiaomi_touch.ko, 都在 vendor_dlkm。
#
# -----------------------------------------------------------------------------
# ⚠️ 下面两个开关在 OrangeFox 14.1 里**根本没有接线**, 写了也不生效:
#
#   TW_CUSTOM_TOUCH_DEVICE
#       全树 grep 零命中 —— 这个变量在 bootable/recovery 里不存在。
#
#   TW_INPUT_BLACKLIST
#       minuitwrp/events.cpp:241 有 #ifdef TW_INPUT_BLACKLIST 分支,
#       但没有任何 Android.mk / Android.bp / Soong 插件 (*.go) 会定义它。
#       编译时走的永远是 #ifndef 那一路, 只硬编码屏蔽 bma250 / bma150。
#       (minuitwrp/libminuitwrp_defaults.go 只处理像素格式、旋转、
#        TW_TARGET_USES_QCOM_BSP、TW_HAPTICS_TSPDRV、haptics shared_libs,
#        没有 BLACKLIST。)
#
#       另外就算将来接上了, 分隔符也必须是 \x0a 而不是 ':' ——
#       events.cpp:249 是 strtok(bl, "\n")。
#
#   结论: 排除 uinput-xiaomi 不能靠这个开关。真正要做的是
#         "让 FocalTech 保持普通坐标上报模式", 见
#         recovery/root/init.recovery.qcom.rc 里的 touch-raw-guard 服务。
# -----------------------------------------------------------------------------
# TW_CUSTOM_TOUCH_DEVICE := "/dev/input/event7"
# TW_INPUT_BLACKLIST := "hbtp_vm\x0auinput-xiaomi"

# 振动
#
#   同平台 4/4 机型 (myron/annibale/nezha/songyuan) 都把这三行**注释掉**。
#   原因 (myron 的 init.recovery.qcom.rc 原话):
#       "Recovery drives qcom-hv-haptics directly through input
#        force-feedback.  Do not start Xiaomi AIDL vibrator HAL; it can
#        mask direct haptics fallback."
#   而且 libminuitwrp_defaults.go:176 只在 TW_SUPPORT_INPUT_AIDL_HAPTICS
#   为 true 时往 libminuitwrp 里挂 android.hardware.vibrator-V2-ndk/-cpp
#   两个 shared_lib, 并不会定义 -DUSE_QTI_AIDL_HAPTICS (全树无此定义点),
#   所以 events.cpp 里那段 AIDL 振动代码其实是死代码。
#   recovery 直接走 qcom-hv-haptics 的 input FF 通道即可。
# -------------------------------------------------------------
# TW_SUPPORT_INPUT_AIDL_HAPTICS := true
# TW_SUPPORT_INPUT_AIDL_HAPTICS_FIX_OFF := true
# TW_SUPPORT_INPUT_AIDL_HAPTICS_FQNAME := "IVibrator/vibratorfeature"
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
