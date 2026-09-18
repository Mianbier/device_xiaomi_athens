# =============================================================================
# fox_athens.mk — OrangeFox (OF_*) 专属设置
# Device: Xiaomi athens (Redmi K100 Pro) / Canoe / Android 16
#
# 由 twrp_athens.mk 通过 inherit-product-if-exists 引入。
# 屏幕: 1440 x 3200 @ 120Hz (原厂 dtbo 实测)
# =============================================================================

OF_MAINTAINER := WorkBuddy
OF_MAINTAINER_PATCH_VERSION := 1
OF_MAINTAINER_AVATAR := /dev/null

# --- 屏幕 / 状态栏 ---
OF_SCREEN_H := 3200
OF_SCREEN_W := 1440
OF_STATUS_H := 160
OF_STATUS_INDENT_LEFT := 60
OF_STATUS_INDENT_RIGHT := 60
OF_HIDE_NOTCH := 1
OF_CLOCK_POS := 0
OF_ALLOW_DISABLE_NAVBAR := 0
OF_OPTIONS_LIST_NUM := 9

# --- 手电筒 / LED ---
OF_USE_GREEN_LED := 1
OF_FLASHLIGHT_ENABLE := 1
OF_FL_PATH1 := /sys/class/leds/white:flash-1/brightness
OF_FL_PATH2 := /sys/class/leds/yellow:flash-0/brightness

# --- A/B + 独立 recovery 分区 ---
OF_AB_DEVICE_WITH_RECOVERY_PARTITION := 1
OF_RECOVERY_AB_FULL_REFLASH_RAMDISK := 1

# --- magiskboot ---
OF_USE_MAGISKBOOT := 1
OF_USE_MAGISKBOOT_FOR_ALL_PATCHES := 0
OF_NO_RELOAD_MAGISKBOOT := 1
OF_USE_MAGISKBOOT_COMPRESSED_WEBP := 0

# --- 备份 ---
OF_QUICK_BACKUP_LIST := /boot;/data;
OF_SKIP_MULTIUSER_FOLDERS_BACKUP := 1
OF_BACKUP_EXCLUSIONS := /data/fonts

# --- 兼容性检查 ---
OF_NO_TREBLE_COMPATIBILITY_CHECK := 1
OF_NO_MIUI_PATCH_WARNING := 1
OF_IGNORE_LOGICAL_MOUNT_ERRORS := 1
OF_BIND_MOUNT_SDCARD_ON_FORMAT := 1
OF_FORCE_CASEFOLDING := 1
OF_UNBIND_SDCARD_F2FS := 1
OF_FORCE_DATA_FORMAT_F2FS := 1

# --- 加密 / dm-verity ---
# Android 16 用 Secretkeeper (Rust), 主线橙狐无法解密 /data
# 保持 dm-verity 不破坏, 避免刷机后无法开机
OF_KEEP_DM_VERITY := 1
OF_DONT_PATCH_ENCRYPTED_DEVICE := 1
OF_SKIP_METADATA_DECRYPTION_WAIT := 0
OF_ADVANCED_SECURITY := true

# --- 工具 ---
OF_ENABLE_LPTOOLS := 1
OF_ENABLE_ALL_PARTITION_TOOLS := 1
OF_DISABLE_OTA_MENU := 1

# --- 动态分区 ---
FOX_USE_DMSETUP := 1
