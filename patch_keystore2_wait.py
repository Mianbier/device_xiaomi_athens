# -*- coding: utf-8 -*-
"""
[athens] 构建期源码补丁: 把 system/vold 里对 keystore2 的"无限等待"改成"有限等待"。

=============================================================================
故障现象
=============================================================================
recovery.img 刷入后能看到橙狐 splash, 但界面永远停在那一帧, 完全点不动。
真机 adb 取证:
  * recovery 主进程只有 1 个线程, 阻塞在 futex_wait (syscall 98)
  * utime 仅 52 tick -> 没有在算东西, 纯粹在等
  * logcat 反复打印:
        ServiceManager: Waited one second for
                        android.system.keystore2.IKeystoreService/default
  * keystore2 每 5 秒崩溃重启一轮 (keystore.crash_count 67 -> 87)
      原因: recovery ramdisk 里没有 KeyMint HAL, keystore2 起不来

=============================================================================
根因 (已在源码里逐行确认; fox_12.1 与 fox_14.1 代码同源, 完全相同)
=============================================================================
system/vold 里包装 keystore2 的那个类, 构造函数写的是:

    ::ndk::SpAIBinder binder(AServiceManager_waitForService(keystore2_service_name));

注意是 waitForService 而不是 checkService —— 前者是 **无限阻塞** 的。
keystore2 永远注册不上这个服务名, 于是 recovery 主线程永久挂住。

调用链 (每次开机必走, 与用户操作无关):

    twrp.cpp: process_recovery_mode()
      -> Decrypt_Page()                              (设备已加密 -> 弹解密页)
        -> PartitionManager.Decrypt_Device()
          -> android::keystore::Decrypt_DE()                     [Decrypt.cpp]
            -> fscrypt_initialize_systemwide_keys()              [FsCrypt.cpp:452]
              -> load_all_de_keys()                              [FsCrypt.cpp:395]
                -> retrieveKey()                                 [FsCrypt.cpp:423]
                  -> KeyStorage.cpp:  Keymaster/Keystore keymaster;
                    -> 构造函数 -> AServiceManager_waitForService -> ★永久阻塞★

上面这几条字符串 ("Attempting to initialize DE keys"、"fscrypt::load_all_de_keys"、
"Vold unable to connect to keystore2.") 都能在编出来的 recovery 二进制里搜到,
所以这条链确实被链接进了 recovery, 确实是它卡住的。

=============================================================================
修法 (零风险)
=============================================================================
换成 AServiceManager_checkService() + 有限次数重试 (最多 15 秒)。
这两个类都自带 operator bool(), 而 KeyStorage.cpp 里 **每一处** 构造点后面都
紧跟 "if (!keymaster) return false;" / "if (!keystore) return false;" 守卫,
所以拿不到服务只会让"解密失败", 绝不会卡死 UI。

=============================================================================
覆盖范围 (按内容匹配, 不写死路径)
=============================================================================
  fox_14.1 -> system/vold/Keystore.cpp    (类名 Keystore)
  fox_12.1 -> system/vold/Keymaster.cpp   (类名 Keymaster, 代码同源)
  system/vold/IdleMaint.cpp 用的是别的服务名, 不会被误伤。

环境变量:
  ATHENS_TOP = Android 源码树根目录 (即 device/ 的上一级)
未设置或找不到 system/vold 时直接安静退出, 绝不让构建失败。
"""

import os
import re
import sys

root = os.environ.get("ATHENS_TOP", "")
if not root or not os.path.isdir(root):
    print("[athens] ATHENS_TOP 无效, 跳过 keystore2 等待补丁")
    sys.exit(0)

vold_dir = os.path.join(root, "system", "vold")
if not os.path.isdir(vold_dir):
    print("[athens] 找不到 %s, 跳过 keystore2 等待补丁" % vold_dir)
    sys.exit(0)

HELPER = (
    "// [athens] ------------------------------------------------------------------\n"
    "// [athens] 有界等待 keystore2 (替换掉 AServiceManager_waitForService 的无限阻塞)\n"
    "// [athens] recovery 里没有 KeyMint HAL -> keystore2 起不来 -> 无限等会把\n"
    "// [athens] recovery 主线程永久挂死在 futex_wait, 界面冻在 splash 点不动。\n"
    "// [athens] 这里最多等 15 秒; 拿不到就返回 nullptr, 调用方有\n"
    "// [athens] \"if (!keymaster) return false;\" / \"if (!keystore) return false;\"\n"
    "// [athens] 守卫, 所以只会解密失败, 不会卡死界面。\n"
    "// [athens] ------------------------------------------------------------------\n"
    "static AIBinder* athens_wait_keystore2(const char* name) {\n"
    "    for (int i = 0; i < 15; ++i) {\n"
    "        AIBinder* b = AServiceManager_checkService(name);\n"
    "        if (b != nullptr) return b;\n"
    "        if (i == 0 || i == 4 || i == 14)\n"
    "            LOG(ERROR) << \"[athens] keystore2 not ready, attempt \" << (i + 1);\n"
    "        sleep(1);\n"
    "    }\n"
    "    LOG(ERROR) << \"[athens] keystore2 unavailable; continuing without it\";\n"
    "    return nullptr;\n"
    "}\n\n"
)

CALL = "AServiceManager_waitForService(keystore2_service_name)"
CALL_NEW = "athens_wait_keystore2(keystore2_service_name)"

matched = 0
patched = 0
skipped = 0

for base, dirs, files in os.walk(root):
    # 别去翻 out/ 和 prebuilts/ (几十万个文件, 又不可能命中)
    dirs[:] = [d for d in dirs if d not in (".repo", "out", ".git", "prebuilts", "prebuilt")]
    for fn in files:
        if not fn.endswith((".cpp", ".cc", ".cxx", ".h", ".hpp")):
            continue
        path = os.path.join(base, fn)
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                src = fh.read()
        except OSError:
            continue
        if "keystore2_service_name" not in src or "AServiceManager_waitForService" not in src:
            continue

        matched += 1
        rel = os.path.relpath(path, root)

        # 幂等: 打过就不再写文件 (也避免改动 mtime 干扰 ninja)
        if "athens_wait_keystore2" in src:
            skipped += 1
            print("[athens] 已打过补丁, 跳过: " + rel)
            continue

        if CALL not in src:
            print("[athens] !! 有 keystore2 但没有预期的 waitForService 调用, 跳过: " + rel)
            continue

        # 1) sleep() 需要 <unistd.h>
        if "#include <unistd.h>" not in src:
            m = re.search(r"^#include [^\n]*\n", src, re.M)
            if m:
                src = (src[:m.start()]
                       + "#include <unistd.h>  // [athens] for sleep()\n"
                       + src[m.start():])

        # 2) 在最后一个 #include 之后插入辅助函数。
        #    放全局作用域就够 —— 调用点在 namespace android::vold 内,
        #    非限定查找会找到 ::athens_wait_keystore2;
        #    而 LOG() 与 AIBinder 都已由文件自身的 include 提供
        #    (<android-base/logging.h> 和 Keystore.h -> <android/binder_manager.h>)。
        anchors = list(re.finditer(r"^#include [^\n]*\n", src, re.M))
        if not anchors:
            print("[athens] !! 找不到 #include 插入点, 跳过: " + rel)
            continue
        at = anchors[-1].end()
        src = src[:at] + "\n" + HELPER + src[at:]

        # 3) 换掉调用
        src = src.replace(CALL, CALL_NEW)

        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(src)
        patched += 1
        print("[athens] 已打补丁: " + rel)

print("[athens] keystore2 有界等待补丁: 命中 %d / 修改 %d / 已是最新 %d"
      % (matched, patched, skipped))
if matched == 0:
    print("[athens] !! 警告: 没找到任何 keystore2 等待代码, 源码布局可能变了")
