# =============================================================================
# fox_athens.mk — OrangeFox (OF_*) 专属设置
# Device: Xiaomi athens (Redmi K100 Pro) / Canoe / Android 16
#
# 由 twrp_athens.mk 通过 inherit-product-if-exists 引入。
#
# -----------------------------------------------------------------------------
# 屏幕真实分辨率 = 1156 x 2510 @ 120Hz (cmd mode, DSC)
#
#   两处独立实测互相印证:
#     1) DRM connector modes:  /sys/class/drm/card0-DSI-1/modes
#            -> 1156x2510x120cmd (另有 185/165/144/90/60)
#     2) 触摸 IC 坐标空间:  ABS_MT_POSITION_X max=115599, Y max=250999
#            -> 除以 100 = 1156.00 x 2510.00
#
#   ⚠️ 之前这里写 1440 x 3200 是错的 (来自 dtbo 里另一块面板的 timing)。
#      后果 (recovery.log 实测):
#          I:Scaling theme width 1.070370x and height 0.784375x
#        宽度按 1080 (主题基准) 算, 高度却按 OF_SCREEN_H=3200 算,
#        两个轴缩放差 37%, 主题被非等比拉扯, 而且
#          slider_y_l = %screen_original_h%-176 = 3024
#        远超屏幕高度 2510, 大量控件被定位到屏幕外。
#
#   取值约定参照同平台可用机型:
#        vayu    : OF_SCREEN_H := 2400  (面板 1080x2400, 等于面板高度)
#        myron   : OF_SCREEN_H := 2374  (面板 1200x2608)
# =============================================================================

OF_MAINTAINER := WorkBuddy
OF_MAINTAINER_PATCH_VERSION := 1
OF_MAINTAINER_AVATAR := /dev/null

# --- 锁屏：必须给可点击的按钮，不能只靠上滑 ---
#   实测故障：按电源键 -> blanktimer.toggleBlank() -> 弹出锁屏覆盖层
#   (gui/gui.cpp:453, 注意它**不受** TW_NO_SCREEN_TIMEOUT 保护)。
#   锁屏默认要"上滑"解锁，而本机的**拖拽手势是坏的**（触摸 IC 的 RAW 上报
#   会打断连续移动，只留下点击）-> 用户被卡在锁屏进不去 recovery。
#
#   OF_USE_LOCKSCREEN_BUTTON=1 会让锁屏显示一个**可点击**的解锁按钮
#   (data.cpp 里置 lock_btn=1，主题据此渲染按钮)。
#   点击在本机是好的，这样就有绕开坏掉手势的入口。
OF_USE_LOCKSCREEN_BUTTON := 1

# --- 屏幕 / 状态栏 ---
OF_SCREEN_H := 2510
OF_SCREEN_W := 1156
# 状态栏高度按比例给 (myron 141 @ 2608 -> 2510 约 136, 取整 140)
OF_STATUS_H := 140
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
