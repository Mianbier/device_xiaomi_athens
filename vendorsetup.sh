# =============================================================================
# vendorsetup.sh — OrangeFox / TWRP 构建环境设置
# Device: Xiaomi athens (Redmi K100 Pro) / Canoe / Android 16
#
# 注意: add_lunch_combo 在 Android 12.1+ 已废弃, 产品组合改由
#       AndroidProducts.mk 里的 COMMON_LUNCH_CHOICES 声明。
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

    echo "[athens] vendorsetup.sh applied (FOX_BUILD_DEVICE=$FOX_BUILD_DEVICE)"
fi
