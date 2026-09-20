#!/system/bin/sh
#
# athens-mount-vendor.sh —— 在 recovery 里挂载 /vendor 与 /odm
#
# 为什么需要它
# -----------------------------------------------------------------------------
# recovery 下 `/vendor` / `/odm` 默认**不会**被挂载（实测 /proc/mounts 里没有）。
# 后果（完整故障链）：
#   1) /vendor/etc/init/*.rc 从未被 import
#   2) vendor HAL 服务（KeyMint / Gatekeeper / Weaver）根本没注册
#   3) keystore2 绑不上 KeyMint -> SIGSEGV 崩溃循环（实测 crash_count 破 100）
#      —— 崩溃循环还会持续烧 CPU，机身明显发烫
#   4) TWRP 读不到 /vendor/etc/vintf/manifest_canoe.xml
#      -> 只能兜底猜 keymaster 版本 4.x
#   5) Unable to decrypt metadata encryption -> /data 解密失败
#
# 实测确认（本设备上验证过）：
#   * `mount -t erofs -o ro /dev/block/dm-8 /vendor` 成功
#   * 挂上后 /vendor/bin/hw/android.hardware.security.onekeymint-service-qti
#     能正常启动并进入 futex_wait（健康），且无 SELinux 拒绝
#   -> 所以"挂载 + 起 HAL"这条路是通的，只是没人去做
#
# 本脚本只做挂载，**没有循环、没有 sleep**，不存在空转风险。
# 成功后置 athens.vendor.mounted=1，由 init.rc 据此启动 HAL 服务。
#
# ⚠️ 绝对不要在这里挂载 /system！
#    recovery 的 /system 就是 ramdisk，挂真实分区会覆盖 /system/bin/sh，
#    直接把 adb shell 弄废（已踩过一次）。

TAG=athens-mount-vendor
RLOG=/tmp/recovery.log

rlog() {
    echo "$TAG: $1" >> "$RLOG" 2>/dev/null
    /system/bin/log -t "$TAG" "$1" 2>/dev/null
}

mount_one() {
    # $1 = 挂载点, $2.. = 候选设备路径
    mp="$1"
    shift
    mkdir -p "$mp" 2>/dev/null

    # 已经挂上了就直接成功
    if grep -q " $mp " /proc/mounts 2>/dev/null; then
        rlog "$mp 已挂载"
        return 0
    fi

    for dev in "$@"; do
        [ -e "$dev" ] || continue
        for fs in erofs ext4; do
            if mount -t "$fs" -o ro,barrier=0 "$dev" "$mp" 2>/dev/null; then
                rlog "挂载成功 $mp <- $dev ($fs)"
                return 0
            fi
        done
    done

    rlog "!! 挂载失败 $mp (已试: $*)"
    return 1
}

rlog "start"

# ---- /vendor ----
# 候选顺序：TWRP 建好的 by-name 链接 -> mapper 的 a/b 槽 -> 裸 dm 设备
mount_one /vendor \
    /dev/block/bootdevice/by-name/vendor \
    /dev/block/mapper/vendor_a \
    /dev/block/mapper/vendor_b \
    /dev/block/mapper/vendor \
    /dev/block/dm-8
V=$?

# ---- /odm ----
mount_one /odm \
    /dev/block/bootdevice/by-name/odm \
    /dev/block/mapper/odm_a \
    /dev/block/mapper/odm_b \
    /dev/block/mapper/odm \
    /dev/block/dm-1
O=$?

# 只要 /vendor 挂上了就置标志位（/odm 失败不阻断，StrongBox 才需要它）
if [ "$V" = 0 ]; then
    setprop athens.vendor.mounted 1
    rlog "athens.vendor.mounted=1 (odm_rc=$O)"
    exit 0
fi

setprop athens.vendor.mounted 0
rlog "!! 未能挂载 /vendor，HAL 不会启动"
exit 1
