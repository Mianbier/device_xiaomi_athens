#!/system/bin/sh
#
# athens-diag.sh —— recovery 启动后把关键状态写进 recovery.log
#
# 为什么需要它
# -----------------------------------------------------------------------------
# 前几轮排查最痛的问题是：**日志抓回来时证据已经没了**。
# 典型例子：
#   * R13 的 /dev/kmsg 被 `unknown touch event` 以 83.8/s 的速度灌满，
#     整个环形缓冲区只剩最近 ~60 秒，FTS 驱动的 probe / 固件版本 / 服务启停
#     记录全被挤掉，只能靠猜。
#   * `/proc/mounts`、`init.svc.*`、VINTF manifest 可读性这些**必须同一时刻
#     快照**的信息，事后单独 adb 去抓时设备状态已经变了。
#
# 所以本脚本在开机后**一次性**把下面这些证据固化进 /tmp/recovery.log：
#   1) /proc/mounts 里 vendor / odm / metadata / data 的真实挂载行
#   2) 三个 vendor HAL 的 init 状态 + pid
#   3) VINTF manifest 的可读性（keystore2 找不到 KeyMint 的直接原因）
#   4) 触摸输入设备清单 + event 节点 → 设备名映射
#   5) enable_touch_raw 的真实读回值
#
# 它只读不写（除了往 recovery.log 追加），无循环、无 sleep、无副作用。

TAG=athens-diag
RLOG=/tmp/recovery.log

rlog() {
    echo "$TAG: $1" >> "$RLOG" 2>/dev/null
    /system/bin/log -t "$TAG" "$1" 2>/dev/null
}

rlog "==================== 启动快照 ===================="

# -----------------------------------------------------------------------------
# 1) 挂载表 —— 判断 /vendor /odm 到底有没有真挂上
# -----------------------------------------------------------------------------
rlog "--- /proc/mounts (vendor/odm/metadata/data) ---"
if [ -r /proc/mounts ]; then
    while read -r line; do
        case "$line" in
            *" /vendor "*|*" /odm "*|*" /metadata "*|*" /data "*)
                rlog "  mount: $line" ;;
        esac
    done < /proc/mounts
else
    rlog "  !! /proc/mounts 不可读"
fi

# -----------------------------------------------------------------------------
# 2) vendor HAL 状态
# -----------------------------------------------------------------------------
rlog "--- vendor HAL 状态 ---"
for s in vendor.keymint vendor.gatekeeper vendor.secretkeeper keystore2; do
    st="$(getprop init.svc.$s 2>/dev/null)"
    pid="$(getprop init.svc_debug_pid.$s 2>/dev/null)"
    rlog "  $s = ${st:-?} (pid ${pid:-?})"
done
rlog "  keystore.crash_count = $(getprop keystore.crash_count 2>/dev/null)"
rlog "  keymaster_ver        = $(getprop keymaster_ver 2>/dev/null)"
rlog "  athens.vendor.mounted= $(getprop athens.vendor.mounted 2>/dev/null)"

# -----------------------------------------------------------------------------
# 3) VINTF manifest 可读性 —— keystore2 崩不崩的关键
#
#    R13 实测 kmsg 里 198 条 VINTF parse error:
#      99x /odm/etc/vintf/manifest_athens.xml  (Too many symbolic links)
#      99x /system/manifest.xml                (No such file or directory)
#    这直接导致 servicemanager 建不出 HAL manifest -> keystore2 找不到
#    AIDL KeyMint -> SIGABRT。
# -----------------------------------------------------------------------------
rlog "--- VINTF manifest 可读性 ---"
for m in \
    /vendor/etc/vintf/manifest.xml \
    /vendor/etc/vintf/manifest_canoe.xml \
    /vendor/etc/vintf/manifest_athens.xml \
    /odm/etc/vintf/manifest.xml \
    /odm/etc/vintf/manifest_athens.xml \
    /system/manifest.xml ; do
    if [ -r "$m" ]; then
        sz="$(wc -c < "$m" 2>/dev/null)"
        rlog "  OK   $m ($sz B)"
    else
        rlog "  MISS $m"
    fi
done

# keymint 关键字是否真的出现在 manifest 里
rlog "--- manifest 里搜 keymint / keymaster ---"
for m in /vendor/etc/vintf/manifest*.xml /odm/etc/vintf/manifest*.xml; do
    [ -r "$m" ] || continue
    n=$(grep -c -i -E "keymint|keymaster|gatekeeper|secretkeeper" "$m" 2>/dev/null)
    rlog "  $m -> $n 处命中"
done

# -----------------------------------------------------------------------------
# 4) 输入设备清单
# -----------------------------------------------------------------------------
rlog "--- 输入设备 ---"
for d in /sys/class/input/event*; do
    [ -d "$d" ] || continue
    n="$(cat "$d/device/name" 2>/dev/null)"
    rlog "  $(basename "$d") = ${n:-?}"
done

# -----------------------------------------------------------------------------
# 5) 触摸 RAW 模式真实读回值
# -----------------------------------------------------------------------------
rlog "--- 触摸 RAW 模式 ---"
for p in /sys/class/touch/touch_dev/enable_touch_raw \
         /sys/devices/virtual/touch/touch_dev/enable_touch_raw ; do
    if [ -e "$p" ]; then
        rlog "  $p = $(cat "$p" 2>/dev/null)"
    else
        rlog "  MISS $p"
    fi
done
rlog "  vendor.touch.recovery.firmware_ready  = $(getprop vendor.touch.recovery.firmware_ready 2>/dev/null)"
rlog "  vendor.touch.recovery.firmware_failed = $(getprop vendor.touch.recovery.firmware_failed 2>/dev/null)"

rlog "==================== 快照结束 ===================="

exit 0
