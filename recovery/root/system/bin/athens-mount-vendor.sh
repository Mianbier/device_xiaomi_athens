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

# -----------------------------------------------------------------------------
# 判定 $mp 是否**真的**被挂载
#
# 为什么不能只用 [ -e "$PROBE" ]：
#   recovery ramdisk 里自带 /vendor /odm 桩目录，桩里的路径是**自指软链**
#   （例如 /odm/etc/vintf -> ../../etc/vintf -> 自己），
#   `ls /odm` 看起来"有内容"，`[ -e ... ]` 有时也会返回真，
#   于是脚本误报"已挂载"，跳过了真正的挂载 —— 这是 R10/R13 两版都踩到的坑：
#     athens-mount-vendor: /odm 已挂载且是真分区(...strongbox...xml 存在)   <- 假阳性
#     实际 /proc/mounts 里根本没有 /odm，/odm/etc/vintf 报
#     "Too many symbolic links encountered"
#
# 正确判据（三重）：
#   1) /proc/mounts 里必须有**精确**的一项 " <mp> "（第 2 字段完全等于 $mp）
#   2) 探针文件必须存在
#   3) 探针文件必须能用 readlink -f 解析出真实路径且不是软链
#      —— 自指软链会解析失败或解析到自身，从而被排除
# -----------------------------------------------------------------------------
is_really_mounted() {
    _mp="$1"; _probe="$2"

    # (1) /proc/mounts 精确匹配。用 awk 取第 2 字段做全等比较，
    #     避免 " /vendor " 这样模糊 grep 到 "/vendor_dlkm" 之类的误伤。
    if ! awk -v m="$_mp" '$2==m {found=1} END {exit found?0:1}' /proc/mounts 2>/dev/null; then
        return 1
    fi

    # (2)(3) 探针校验
    [ -n "$_probe" ] || return 0          # 没给探针，前一步已足够
    [ -e "$_probe" ] || return 1

    _real=$(readlink -f "$_probe" 2>/dev/null)
    if [ -z "$_real" ] || [ ! -e "$_real" ]; then
        return 1                          # 自指软链：解析不出来
    fi
    # 自指软链的另一种形态：解析结果等于探针路径本身但本身是软链
    if [ -L "$_probe" ]; then
        return 1
    fi
    return 0
}

mount_one() {
    # $1 = 挂载点, $2 = 探针文件（真分区里才有、ramdisk 桩里没有）, $3.. = 候选设备
    mp="$1"
    PROBE="$2"
    shift 2
    mkdir -p "$mp" 2>/dev/null

    # -------------------------------------------------------------------------
    # 已经挂上了？—— 但**必须验证挂的是不是真货**！（判据见 is_really_mounted）
    # -------------------------------------------------------------------------
    if is_really_mounted "$mp" "$PROBE"; then
        rlog "$mp 已挂载且是真分区（$PROBE 通过 readlink 校验）"
        return 0
    fi
    if awk -v m="$mp" '$2==m {found=1} END {exit found?0:1}' /proc/mounts 2>/dev/null; then
        rlog "$mp 在 /proc/mounts 里但探针校验失败（$PROBE）—— 当作桩处理"
    else
        rlog "$mp 不在 /proc/mounts 里（ramdisk 桩目录），开始真实挂载"
    fi

    for dev in "$@"; do
        [ -e "$dev" ] || continue
        for fs in erofs ext4; do
            if mount -t "$fs" -o ro,barrier=0 "$dev" "$mp" 2>/dev/null; then
                if is_really_mounted "$mp" "$PROBE"; then
                    rlog "挂载成功 $mp <- $dev ($fs)"
                    return 0
                fi
                rlog "$dev 挂上了但探针校验失败（$PROBE），换下一个"
                umount "$mp" 2>/dev/null
            fi
        done
    done

    rlog "!! 挂载失败 $mp (已试: $*)"
    return 1
}

rlog "start"

# ---- /vendor ----
# 探针：真分区里实测存在、ramdisk 桩里没有的文件（见 mount_one 里的说明）
mount_one /vendor /vendor/etc/vintf/manifest_canoe.xml \
    /dev/block/bootdevice/by-name/vendor \
    /dev/block/mapper/vendor_a \
    /dev/block/mapper/vendor_b \
    /dev/block/mapper/vendor \
    /dev/block/dm-8
V=$?

# ---- /odm ----
mount_one /odm /odm/etc/vintf/manifest/android.hardware.security.keymint3-service.strongbox.nxp.xml \
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
