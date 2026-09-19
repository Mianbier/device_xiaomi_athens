# =============================================================================
# vendorsetup.sh — OrangeFox / TWRP 构建环境设置
# Device: Xiaomi athens (Redmi K100 Pro) / Canoe / Android 16
#
# 注意: add_lunch_combo 在 Android 12.1+ 已废弃, 产品组合改由
#       AndroidProducts.mk 里的 COMMON_LUNCH_CHOICES 声明。
#
# 本文件由 build/envsetup.sh 自动 source (它会 find device/*/*/vendorsetup.sh),
# 所以这里是"构建期钩子"的官方入口 —— 我们用它来打源码补丁。
# =============================================================================

FDEVICE="athens"

fox_get_target_device() {
    local chkdev=$(echo "$BASH_SOURCE" | grep -w $FDEVICE)
    if [ -n "$chkdev" ]; then
        FOX_BUILD_DEVICE="$FDEVICE"
    else
        chkdev=$(set | grep BASH_ARGV | grep -w $FDEVICE)
        [ -n "$chkdev" ] && FOX_BUILD_DEVICE="$FDEVICE"
    fi
}

if [ -z "$1" -a -z "$FOX_BUILD_DEVICE" ]; then
    fox_get_target_device
fi

if [ "$1" = "$FDEVICE" -o "$FOX_BUILD_DEVICE" = "$FDEVICE" ]; then
    export LC_ALL="C.UTF-8"
    export ALLOW_MISSING_DEPENDENCIES=true

    # --- OrangeFox 构建信息 ---
    export FOX_VANILLA_BUILD=1
    export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
    export FOX_VIRTUAL_AB_DEVICE=1
    export TARGET_DEVICE_ALT="athens"

    # --- recovery 挂载点 ---
    export FOX_RECOVERY_SYSTEM_PARTITION="/dev/block/mapper/system"
    export FOX_RECOVERY_VENDOR_PARTITION="/dev/block/mapper/vendor"

    # --- 设置存放目录 (persist 分区) ---
    export FOX_SETTINGS_ROOT_DIRECTORY="/persist/OFRP"
    export FOX_ALLOW_EARLY_SETTINGS_LOAD=1
    export FOX_MISCELLANEOUS_ROOT_DIRECTORY="/sdcard"

    # --- Magisk 安装器放入 ramdisk ---
    export FOX_MOVE_MAGISK_INSTALLER_TO_RAMDISK=1

    # --- 内置工具 ---
    export FOX_REPLACE_BUSYBOX_PS=1
    export FOX_USE_BASH_SHELL=1
    export FOX_ASH_IS_BASH=1
    export FOX_REPLACE_TOOLBOX_GETPROP=1
    export FOX_USE_TAR_BINARY=1
    export FOX_USE_XZ_UTILS=1
    export FOX_USE_SED_BINARY=1
    export FOX_USE_NANO_EDITOR=1
    export FOX_USE_ZSTD_BINARY=1

    # --- 其它 ---
    export FOX_DELETE_AROMAFM=1
    export FOX_DELETE_INITD_ADDON=1
    export FOX_ENABLE_APP_MANAGER=1

    # =========================================================================
    # ★ 关键修复: 修掉 "recovery 卡死在 splash, 界面完全点不动" 的根因
    # -------------------------------------------------------------------------
    # 详见 device/xiaomi/athens/patch_keystore2_wait.py 顶部的完整分析。
    #
    # 一句话版: system/vold 里包装 keystore2 的那个类, 构造函数用的是
    #     AServiceManager_waitForService("android.system.keystore2...")
    # 那是 **无限阻塞**。recovery ramdisk 里没有 KeyMint HAL -> keystore2
    # 每 5 秒崩溃重启一次, 永远注册不上 -> recovery 主线程永久挂死在 futex_wait
    # -> 界面冻在 splash。改成 checkService + 最多 15 秒重试即可。
    #
    # 这里调用它 (BoardConfig.mk 里还有一道 $(shell) 兜底, 双保险)。
    # 脚本是幂等的, 重复执行不会重复打补丁, 也不会改 mtime。
    # =========================================================================
    ATHENS_TOP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)"
    if [ -n "$ATHENS_TOP" ] && [ -f "$ATHENS_TOP/device/xiaomi/athens/patch_keystore2_wait.py" ]; then
        ATHENS_TOP="$ATHENS_TOP" python3 "$ATHENS_TOP/device/xiaomi/athens/patch_keystore2_wait.py" \
            || echo "[athens] !! keystore2 补丁脚本返回非零, 但继续构建"
    else
        echo "[athens] !! 警告: 找不到补丁脚本或源码树根 ($ATHENS_TOP), 跳过 keystore2 等待补丁"
    fi

    echo "[athens] vendorsetup.sh applied (FOX_BUILD_DEVICE=$FOX_BUILD_DEVICE)"
fi
