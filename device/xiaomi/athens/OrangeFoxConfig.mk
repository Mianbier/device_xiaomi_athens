# ==========================================================
# OrangeFoxConfig.mk — 橙狐 Recovery 配置
# 模板来自 LimeBlogs/OrangeFox-Recovery-Builder (2026-01 中文版)
# ==========================================================

# 1. 基础信息
OF_MAINTAINER_PATCH_VERSION := 1
OF_MAINTAINER := WorkBuddy
OF_MAINTAINER_AVATAR := /dev/null

# 2. 屏幕与 UI 配置  (Redmi K100 Pro = 1156x2510 直屏)
OF_SCREEN_H := 2510
OF_STATUS_H := 65
OF_STATUS_INDENT_LEFT := 48
OF_STATUS_INDENT_RIGHT := 48
OF_CLOCK_POS := 1
OF_ALLOW_DISABLE_NAVBAR := 0

# 3. 核心功能
OF_USE_MAGISKBOOT := 1
OF_USE_MAGISKBOOT_FOR_ALL_PATCHES := 0
OF_NO_RELOAD_MAGISKBOOT := 1
OF_NO_TREBLE_COMPATIBILITY_CHECK := 1
OF_NO_MIUI_PATCH_WARNING := 1

# 4. Android 12+ 解密与防砖配置
OF_SKIP_METADATA_DECRYPTION_WAIT := 0
OF_DONT_PATCH_ENCRYPTED_DEVICE := 1
OF_KEEP_DM_VERITY := 1
OF_USE_MAGISKBOOT_COMPRESSED_WEBP := 0

# 5. 其他杂项
OF_ENABLE_LPTOOLS := 1
OF_QUICK_BACKUP_LIST := /boot;/data;
