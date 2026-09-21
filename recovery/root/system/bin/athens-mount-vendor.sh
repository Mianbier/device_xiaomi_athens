#!/system/bin/sh
#
# athens-mount-vendor.sh —— 在 recovery 里挂载 /vendor 与 /odm
#
# 为什么需要它
# -----------------------------------------------------------------------------
# recovery 下 `/vendor` / `/odm` 默认**不会**被挂载（实测 /proc/mounts 里没有）。
# 后果（完整故障链，R13 实测确认）：
#   1) /odm 没挂 -> servicemanager 读不到 /odm/etc/vintf/manifest_athens.xml
#      kmsg 实测 99 次: VINTF parse error: Too many symbolic links
#   2) servicemanager 建不出完整 HAL manifest
#   3) keystore2 找不到 AIDL KeyMint 服务
#      kmsg 实测: init: Service 'keystore2' (pid 1251) received signal 6  (SIGABRT)
#   4) TWRP 拿不到解密密钥 -> Unable to mount '/data'
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
#   （/odm/etc/vintf 绕回自己），`ls /odm` 看起来"有内容"，
#   `[ -e ... ]` 在某些解析路径下也会返回真 -> 假阳性 -> 跳过真正的挂载。
#   这是 R10/R13 两版都踩到的坑：
#     athens-mount-vendor: /odm 已挂载且是真分区(...)     <- 假阳性
#     实际 /proc/mounts 里根本没有 /odm，
#     /odm/etc/vintf 报 "Too many symbolic links encountered"
#
# 正确判据（三重）：
#   1) /proc/mounts 里必须有**精确**一项，第 2 字段完全等于 $mp
#      （用 awk 全等比较，避免 " /vendor " 模糊匹配到 /vendor_dlkm）
#   2) 至少一个探针文件存在
#   3) 该探针能用 readlink -f 解析出真实路径，且它本身不是软链
#      —— 自指软链会在这里被排除
#
# $2 是**空格分隔的探针列表**，任意一个通过即算成功。
# 用列表是因为单个探针太脆弱：上一版用 StrongBox 的 nxp.xml 做唯一探针，
# 万一该机型 odm 里没有这个文件，就会把"挂载成功"误判成失败。
# -----------------------------------------------------------------------------
is_really_mounted() {
    _mp="$1"; _probes="$2"

    # (1) /proc/mounts 精确匹配
    if ! awk -v m="$_mp" '$2==m {found=1} END {exit found?0:1}' /proc/mounts 2>/dev/null; then
        return 1
    fi

    # 没给探针，前一步已足够
    [ -n "$_probes" ] || return 0

    # (2)(3) 任意一个探针通过即可
    for _p in $_probes; do
        [ -e "$_p" ] || continue
        # 自指软链：本身是软链 -> 判为桩
        [ -L "$_p" ] && continue
        _real=$(readlink -f "$_p" 2>/dev/null)
        [ -n "$_real" ] && [ -e "$_real" ] || continue
        return 0
    done
    return 1
}

# 尝试把一个设备挂到 $mp 并校验；成功返回 0
try_dev() {
    _mp="$1"; _probes="$2"; _dev="$3"
    [ -e "$_dev" ] || return 1
    for _fs in erofs ext4; do
        if mount -t "$_fs" -o ro,barrier=0 "$_dev" "$_mp" 2>/dev/null; then
            if is_really_mounted "$_mp" "$_probes"; then
                rlog "挂载成功 $_mp <- $_dev ($_fs)"
                return 0
            fi
            # 挂上了但不是目标分区（或探针全不匹配）—— 立刻退掉，换下一个
            umount "$_mp" 2>/dev/null
        fi
    done
    return 1
}

mount_one() {
    # $1 = 挂载点, $2 = 空格分隔的探针列表, $3.. = 分区名（用于生成候选路径）
    mp="$1"
    PROBES="$2"
    shift 2
    mkdir -p "$mp" 2>/dev/null

    if is_really_mounted "$mp" "$PROBES"; then
        rlog "$mp 已挂载且是真分区（探针通过 readlink 校验）"
        return 0
    fi
    if awk -v m="$mp" '$2==m {found=1} END {exit found?0:1}' /proc/mounts 2>/dev/null; then
        rlog "$mp 在 /proc/mounts 里但探针校验失败 —— 当作桩处理"
    else
        rlog "$mp 不在 /proc/mounts 里（ramdisk 桩目录），开始真实挂载"
    fi

    # -------------------------------------------------------------------------
    # 阶段 1：按分区名生成候选路径（快、精确）
    #
    #   ⚠️ 不要硬编码 dm-N！
    #   上一版 /odm 直接写死 /dev/block/dm-1，纯粹是猜的 ——
    #   实测 /vendor 是靠 dm-8 挂上的（前面 by-name/mapper 候选全落空），
    #   说明这台机器的 dm 编号无法预先推断。所以这里改成扫描。
    # -------------------------------------------------------------------------
    tried=""
    for name in "$@"; do
        for cand in \
            "/dev/block/bootdevice/by-name/$name" \
            "/dev/block/by-name/$name" \
            "/dev/block/mapper/$name" \
            "/dev/block/mapper/${name}_a" \
            "/dev/block/mapper/${name}_b" ; do
            [ -e "$cand" ] || continue
            case " $tried " in *" $cand "*) continue ;; esac
            tried="$tried $cand"
            if try_dev "$mp" "$PROBES" "$cand"; then return 0; fi
        done
    done

    # -------------------------------------------------------------------------
    # 阶段 2：暴力扫描所有 dm / mapper 设备
    #
    #   动态分区（super）里的逻辑分区在 recovery 里未必有 by-name 链接，
    #   mapper 名字也未必等于分区名。既然已经有探针做最终校验，
    #   把剩下的 dm 设备挨个试一遍是安全的：
    #     - 只读挂载
    #     - 探针不匹配就立刻 umount
    #   代价是几次失败的 mount 调用，可忽略。
    # -------------------------------------------------------------------------
    rlog "$mp 阶段1 未命中，开始暴力扫描 dm/mapper 设备"
    for dev in /dev/block/dm-* /dev/block/mapper/*; do
        [ -e "$dev" ] || continue
        case " $tried " in *" $dev "*) continue ;; esac
        tried="$tried $dev"
        if try_dev "$mp" "$PROBES" "$dev"; then return 0; fi
    done

    rlog "!! 挂载失败 $mp (共试过: $tried)"
    return 1
}

rlog "start"

# ---- /vendor ----
# 探针：真分区里才有的文件。给多个是因为单个太脆弱。
mount_one /vendor \
    "/vendor/etc/vintf/manifest_canoe.xml /vendor/build.prop /vendor/etc/vintf/manifest.xml" \
    vendor

# ---- /odm ----
# manifest_athens.xml 这个路径来自 R13 的 VINTF 报错原文，确认它应该在真 /odm 里。
# build.prop 作为兜底（任何 odm 都有）。
mount_one /odm \
    "/odm/etc/vintf/manifest_athens.xml /odm/build.prop /odm/etc/vintf/manifest.xml" \
    odm

V=0
is_really_mounted /vendor "/vendor/etc/vintf/manifest_canoe.xml /vendor/build.prop /vendor/etc/vintf/manifest.xml" || V=1
O=0
is_really_mounted /odm "/odm/etc/vintf/manifest_athens.xml /odm/build.prop /odm/etc/vintf/manifest.xml" || O=1

# 只要 /vendor 挂上了就置标志位（/odm 失败不阻断启动，但会在日志里明说）
if [ "$V" = 0 ]; then
    setprop athens.vendor.mounted 1
    rlog "athens.vendor.mounted=1 (odm_rc=$O)"
    exit 0
fi

setprop athens.vendor.mounted 0
rlog "!! 未能挂载 /vendor，HAL 不会启动"
exit 1
