# -*- coding: utf-8 -*-
"""把 recovery 的屏幕超时默认值从 60 秒改成「永不超时」，同时**保留解锁路径**。

为什么要打这个补丁
-----------------------------------------------------------------------------
gui/blanktimer.cpp 里 `TW_NO_SCREEN_TIMEOUT` 这个宏同时保护**两个**函数：

    checkForTimeout()        —— 屏幕超时：(sleepTimer-2)秒变暗 -> sleepTimer 秒熄屏 + 弹锁屏
    resetTimerAndUnblank()   —— ★ 解锁 / 熄屏恢复

所以「用 TW_NO_SCREEN_TIMEOUT 来避免超时」是**错的**：它确实让屏幕永不超时，
但把解锁路径也一起编译没了 —— 锁屏一旦弹出（电源键 -> toggleBlank()，
该函数不受这个宏保护）就再也退不出来，用户被永久卡死。本项目实测踩过。

而 ifndef 分支（即不定义该宏）的默认值是 60 秒：

    #else
      mPersist.SetValue("tw_screen_timeout_secs", "60");
      mPersist.SetValue("tw_no_screen_timeout", "0");
    #endif

注意这里是 **mPersist**，即**每次开机都强制写回 60** ——
用户在「设置 -> 屏幕超时 -> 永不」里改了也会被覆盖，等于改不了。

本补丁的做法
-----------------------------------------------------------------------------
把上面那一行改成 "0"，且不定义 TW_NO_SCREEN_TIMEOUT：

  * sleepTimer = 0 -> `if (sleepTimer && diff.tv_sec > sleepTimer)` 恒假
    -> **永不超时**（等价于 TW_NO_SCREEN_TIMEOUT 的效果）
  * TW_NO_SCREEN_TIMEOUT 未定义 -> **resetTimerAndUnblank() 保留**
    -> **能解锁**，就算按电源键弹了锁屏也能退出来

两个好处同时拿到，这正是 TW_NO_SCREEN_TIMEOUT 做不到的。

⚠️ 只改 `mPersist.SetValue(..., "60")` 这一条：
   #ifdef 分支里的 `mConst.SetValue("tw_screen_timeout_secs", "0")` 不能碰
   （那个分支本来就是 0，而且它同时把解锁编译没了）。

安全性
-----------------------------------------------------------------------------
* 幂等：已打过就跳过，不改 mtime，不重复追加
* 找不到源码树 / 找不到目标行：安静退出（exit 0），**绝不让构建失败**
"""

import os
import sys

root = os.environ.get("ATHENS_TOP", "")
if not root:
    sys.exit(0)

OLD = 'mPersist.SetValue("tw_screen_timeout_secs", "60");'
NEW = ('// [athens] 默认 60 -> 0: 永不超时。\n'
       '  // [athens] 注意不能改用 TW_NO_SCREEN_TIMEOUT —— 它把 resetTimerAndUnblank()\n'
       '  // [athens] (解锁) 一起编译没了, 锁屏弹出后会永久卡死。这里用 0 值达到\n'
       '  // [athens] "永不超时" 的效果, 同时保留解锁路径。\n'
       '  mPersist.SetValue("tw_screen_timeout_secs", "0");')

RELPATH = os.path.join("bootable", "recovery", "data.cpp")


def main():
    path = os.path.join(root, RELPATH)
    if not os.path.isfile(path):
        print("[athens] 屏幕超时补丁: 找不到 %s, 跳过" % RELPATH)
        return 0

    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            src = f.read()
    except Exception as e:
        print("[athens] 屏幕超时补丁: 读取失败 %r, 跳过" % (e,))
        return 0

    if NEW in src:
        print("[athens] 屏幕超时补丁: 命中 1 / 修改 0 / 已是最新 1")
        return 0

    if OLD not in src:
        print("[athens] 屏幕超时补丁: 未找到目标行 (可能源码已变), 跳过")
        return 0

    new_src = src.replace(OLD, NEW, 1)
    try:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_src)
    except Exception as e:
        print("[athens] 屏幕超时补丁: 写入失败 %r, 跳过" % (e,))
        return 0

    print("[athens] 屏幕超时补丁: 命中 1 / 修改 1 / 已是最新 0")
    return 0


if __name__ == "__main__":
    sys.exit(main())
