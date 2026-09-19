#!/system/bin/sh
#
# athens-touch-fw-load.sh — Redmi K100 Pro (athens) 触摸固件加载
#
# 由 init.recovery.qcom.rc 在 twrp.modules.loaded=true 时拉起。
#
# 背景:
#   focaltech_touch_3685g.ko 自带一份 fallback 固件, 但它的 THP 帧布局与
#   athens 的 FT3685G 面板不一致, 会导致触摸"看起来像死了一样"或坐标反向。
#   必须加载 ODM 里的原厂固件 focaltech_ts_fw_athens.bin (148220 字节)。
#
#   另外驱动默认可能处于 raw/THP 上报模式, 该模式下坐标事件会被 THP 消费掉,
#   TWRP 直接读 /dev/input/eventX 就什么也收不到。所以要写
#   enable_touch_raw = 0, 让驱动按普通 fts_ts 坐标上报。
#
# 本脚本只读系统自带节点, 不注入任何合成触摸事件。

TAG=athens-touch-fw
FW_NAME=focaltech_ts_fw_athens.bin
FW_SIZE=148220
FW_PATH_PARAM=/sys/module/firmware_class/parameters/path
TOUCH_DEV_SYSFS=/sys/class/misc/xiaomi-touch/dev
TOUCH_DEV=/dev/xiaomi-touch
TOUCH_CLASS=/sys/class/touch
TOUCH_ROOT=/sys/devices/virtual/touch
TOUCH_NODE=$TOUCH_ROOT/touch_dev
ABNORMAL_EVENT=$TOUCH_NODE/abnormal_event
TOUCH_RAW=$TOUCH_NODE/enable_touch_raw
RLOG=/tmp/recovery.log

rlog() {
    echo "athens-touch-fw-load: $1" >> "$RLOG" 2>/dev/null
    /system/bin/log -t "$TAG" "$1" 2>/dev/null
}

setprop vendor.touch.recovery.firmware_ready 0
setprop vendor.touch.recovery.firmware_failed 0
rlog "start (fw=$FW_NAME expect=$FW_SIZE)"

retry=0
while [ "$retry" -lt 20 ]; do
    # --- 1) 找固件: 优先 recovery ramdisk 自带副本, 再看已挂载的 odm/vendor ---
    FW_DIR=
    for candidate in /odm/firmware /vendor/firmware /odm/etc/firmware; do
        file="$candidate/$FW_NAME"
        [ -r "$file" ] || continue
        size="$(wc -c < "$file" 2>/dev/null)"
        if [ "$size" = "$FW_SIZE" ]; then
            FW_DIR="$candidate"
            break
        fi
        rlog "reject $file (size=$size, want $FW_SIZE)"
    done

    # --- 2) 找 force-upgrade 节点 ---
    FW_NODE=
    for candidate in /sys/bus/spi/devices/*/fts_force_upgrade; do
        [ -e "$candidate" ] || continue
        FW_NODE="$candidate"
        break
    done

    devno="$(cat "$TOUCH_DEV_SYSFS" 2>/dev/null)"
    major="${devno%:*}"
    minor="${devno#*:}"

    if [ -n "$FW_DIR" ] && [ -n "$FW_NODE" ] && [ -w "$FW_PATH_PARAM" ] && \
       [ -w "$FW_NODE" ] && [ -n "$devno" ] && [ "$major" != "$devno" ] && \
       [ -d "$TOUCH_NODE" ]; then

        # recovery 的 ueventd 可能漏掉这个后创建的 misc 节点, 用内核导出的
        # major/minor 自己补一个, 不硬编码设备号。
        if [ ! -e "$TOUCH_DEV" ]; then
            mknod "$TOUCH_DEV" c "$major" "$minor" 2>/dev/null || true
        fi
        if [ ! -c "$TOUCH_DEV" ]; then
            rlog "cannot create $TOUCH_DEV ($devno), retry $retry"
            retry=$((retry + 1))
            sleep 1
            continue
        fi
        chown system:system "$TOUCH_DEV"
        chmod 0666 "$TOUCH_DEV"

        chown root:root "$TOUCH_CLASS" "$TOUCH_ROOT" "$TOUCH_NODE" 2>/dev/null
        chmod 0755 "$TOUCH_CLASS" "$TOUCH_ROOT" "$TOUCH_NODE" 2>/dev/null
        for attr in "$TOUCH_NODE"/*; do
            [ -f "$attr" ] || continue
            chown -f system:system "$attr" 2>/dev/null
            chmod -f 0664 "$attr" 2>/dev/null
        done
        if ! chown system:system "$ABNORMAL_EVENT" 2>/dev/null || \
           ! chmod 0664 "$ABNORMAL_EVENT" 2>/dev/null; then
            rlog "cannot prepare $ABNORMAL_EVENT, retry $retry"
            retry=$((retry + 1))
            sleep 1
            continue
        fi

        # 面板/触摸相关属性 (ODM 自带脚本, 存在才跑)
        if [ -r /odm/etc/init.panel_info.sh ]; then
            /system/bin/sh /odm/etc/init.panel_info.sh >> "$RLOG" 2>&1
        fi

        # firmware_class.path 是全局的, 用完要还原, 否则会影响 IPA/CNSS 的
        # 固件查找。
        old_fw_path="$(cat "$FW_PATH_PARAM" 2>/dev/null)"
        load_ok=0
        if echo "$FW_DIR" > "$FW_PATH_PARAM" && echo "$FW_NAME" > "$FW_NODE"; then
            load_ok=1
        fi
        echo "$old_fw_path" > "$FW_PATH_PARAM" 2>/dev/null || true

        if [ "$load_ok" = 1 ]; then
            # 关掉 raw/THP 上报, 让 TWRP 能直接读到坐标事件
            [ -w "$TOUCH_RAW" ] && echo 0 > "$TOUCH_RAW"
            rlog "OK: $TOUCH_DEV ($devno) + $FW_DIR/$FW_NAME ($FW_SIZE bytes), touch_raw=0"
            setprop vendor.touch.recovery.firmware_ready 1
            exit 0
        fi
    fi

    retry=$((retry + 1))
    sleep 1
done

rlog "FAILED: firmware=$FW_DIR node=$FW_NODE dev=$TOUCH_DEV devno=$devno retry=$retry"
setprop vendor.touch.recovery.firmware_failed 1
exit 1
