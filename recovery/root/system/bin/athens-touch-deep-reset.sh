#!/system/bin/sh
#
# athens-touch-deep-reset.sh —— 强制把 FocalTech IC 从 RAW/THP 模式踢回正常上报
#
# 为什么需要它（R13 14.1 实测，证据见 diag/dec/kmsg_141_R13.txt）
# -----------------------------------------------------------------------------
#   症状:
#     * kmsg: `[FTS_TS_I][fts_irq_read_report:2286]: unknown touch event(5)`
#             5037 条 / 60 秒 = **83.8 / 秒**，没人碰屏幕也在刷
#     * `getevent -lt /dev/input/event7` 采样 9 秒 -> **0 条事件**
#       （TWRP pid 464 确实已打开 event7，fd 9 —— 问题不在 TWRP 侧）
#     * `/sys/class/touch/touch_dev/enable_touch_raw` 读回 = 0
#       （守卫写 26 次全部成功，kmsg 里能看到 `enable touch raw 0`）
#
#   结论: **"设值"成功了，但"生效"没有**。
#         IC 仍按 RAW 模式推帧 -> 驱动解析不出触点 -> MT 事件一个都不发。
#
#   为什么单纯轮询写 0 压不住:
#     * `fts_esdcheck_tp_reset` 在本轮日志里触发 10 次，每次 ESD 自愈 reset 后
#       IC 都会重新进入 RAW 模式；
#     * 守卫每 5 秒才压一次，远慢于 reset 的发生频率 → 一直被抢回去。
#
#   用户观察"上滑有概率成功"也因此得到解释：
#     reset 之后有短暂窗口 IC 会漏出几帧正常的 MT 事件，
#     刚好被 TWRP 读到 → 偶尔解锁成功。
#     => 不是锁屏逻辑坏，是**事件源间歇性可用**。
#
# 本脚本做的事（"深度复位"而不是"写一次 0"）
# -----------------------------------------------------------------------------
#   1) toggle 0 -> 1 -> 0
#      只写 0 时，驱动侧可能认为"值没变"而跳过下发；
#      toggle 能迫使驱动重新走一遍模式配置流程。
#   2) 双路径都写（myron 与 songyuan 的 sysfs 路径不同）
#   3) 复位前后读回校验，并把**真实**读回值写进日志
#      —— 上一版把 "touch_raw=0" 硬编码进日志字符串，掩盖了失败，这里杜绝。
#   4) 若存在 touch_dev_enable，做一次 0->1->0 让驱动走完整的 enable 流程
#
# 它只是"尽量修正"，不保证一定成功；失败也不返回非 0，
# 免得 oneshot 服务被反复重启。
#
# ⚠️ 绝不挂载 /system（会把 ramdisk 的 /system/bin/sh 覆盖掉）。

TAG=athens-touch-deep-reset
RLOG=/tmp/recovery.log

rlog() {
    echo "$TAG: $1" >> "$RLOG" 2>/dev/null
    /system/bin/log -t "$TAG" "$1" 2>/dev/null
}

# 双路径：不同机型/版本用不同的符号链接
P1=/sys/class/touch/touch_dev/enable_touch_raw
P2=/sys/devices/virtual/touch/touch_dev/enable_touch_raw
PE=/sys/class/touch/touch_dev/touch_dev_enable

w() {
    # $1 = 路径, $2 = 值
    [ -e "$1" ] || return 1
    echo "$2" > "$1" 2>/dev/null
    return 0
}

r() {
    # 读回；读不到就打印 "?"
    if [ -e "$1" ]; then
        cat "$1" 2>/dev/null | tr -d '\r\n'
    else
        printf '?'
    fi
}

rlog "start"

# -----------------------------------------------------------------------------
# 步骤 1：先读回当前状态（只记录，不判断）
# -----------------------------------------------------------------------------
rlog "before: raw(P1)=$(r $P1) raw(P2)=$(r $P2) enable=$(r $PE)"

# -----------------------------------------------------------------------------
# 步骤 2：enable_touch_raw 走一遍 toggle 0 -> 1 -> 0
#
#   关键点：中间那次写 1 不能被省掉。
#   只写 0 时驱动可能判定"值未变化"直接 return，配置根本没下发到 IC。
# -----------------------------------------------------------------------------
for p in "$P1" "$P2"; do
    w "$p" 0
    /system/bin/toybox sleep 1
    w "$p" 1
    /system/bin/toybox sleep 1
    w "$p" 0
    /system/bin/toybox sleep 1
    rlog "toggled $p -> 读回 $(r $p)"
done

# -----------------------------------------------------------------------------
# 步骤 3：让驱动走一次完整的 enable 流程
#   有些固件只有在 touch_dev_enable 变化时才会重新下发工作模式。
# -----------------------------------------------------------------------------
if [ -e "$PE" ]; then
    w "$PE" 0
    /system/bin/toybox sleep 1
    w "$PE" 1
    /system/bin/toybox sleep 1
    w "$PE" 0
    /system/bin/toybox sleep 1
    w "$PE" 1
    /system/bin/toybox sleep 1
    rlog "touch_dev_enable 循环完毕 -> 读回 $(r $PE)"
else
    rlog "touch_dev_enable 节点不存在，跳过"
fi

# -----------------------------------------------------------------------------
# 步骤 4：终态确认
# -----------------------------------------------------------------------------
RAW_FINAL=$(r $P1)
rlog "after: raw(P1)=$RAW_FINAL raw(P2)=$(r $P2) enable=$(r $PE)"

if [ "$RAW_FINAL" = "0" ]; then
    rlog "OK: enable_touch_raw 终态为 0（注意：读回为 0 不等于 IC 已生效，"
    rlog "    仍需用 getevent /dev/input/event7 实测是否有 MT 事件）"
else
    rlog "!! enable_touch_raw 终态为 $RAW_FINAL（期望 0）"
fi

# 不返回非 0，避免 oneshot 服务被反复拉起
exit 0
