# device/xiaomi/athens — OrangeFox Recovery 设备树

红米 K100 Pro (代号 **athens**) 的橙狐 Recovery 设备树。

## 来源

所有参数均从你硬盘上的全量包提取，零猜测：

| 参数 | 值 | 来源 |
|---|---|---|
| 内核 | 原始 ARM64 Image (MZ 魔数, 42MB) | `boot.img` @4096 |
| DTB | 6.5MB (vendor dtb) | `vendor_boot.img` |
| cmdline | `video=vfb:...swinfo.fingerprint=athens...` | `vendor_boot.img` |
| header_version | 4 (GKI v4) | boot/vendor_boot 头 |
| page_size | 4096 | boot 头 |
| 屏幕 | 1156×2510 | 公开参数 |
| recovery 分区 | 100 MiB | payload 分区表 |

## 目录结构

```
device/xiaomi/athens/
├── AndroidProducts.mk
├── BoardConfig.mk
├── athens.mk
├── device.mk
├── recovery.fstab
├── vendorsetup.sh
├── OrangeFoxConfig.mk
└── prebuilt/
    ├── kernel      (42MB, 原始内核)
    └── dt.img      (6.5MB, vendor DTB)
```

## 怎么编译（云端，免费）

这个设备树仓库只放代码 + 预编译内核。**真正编译在 GitHub Actions 跑，不用你本地有 Linux。**

1. **把这个目录**（`device/xiaomi/athens/`）推到一个**新仓库**，例如 `device_xiaomi_athens`
   ```bash
   cd device/xiaomi/athens
   git init -b main
   git add -A
   git commit -m "athens: OrangeFox device tree"
   git remote add origin https://github.com/<你的用户名>/device_xiaomi_athens.git
   git push -u origin main
   ```
   > 提示：用 GitHub **Personal Access Token (PAT)** 推，别用账号密码。

2. **Fork 构建器**：<https://github.com/LimeBlogs/OrangeFox-Recovery-Builder>

3. 在 fork 里 `Actions → OrangeFox - 构建 → Run workflow`，填：
   | 项 | 值 |
   |---|---|
   | OrangeFox 版本 | `12.1` |
   | OrangeFox设备树 | `https://github.com/<你>/device_xiaomi_athens` |
   | 设备树分支 | `main` |
   | 设备路径 | `device/xiaomi/athens` |
   | 设备代号 | `athens` |
   | 构建目标 | `recovery` |
   | 设备名称 | `Redmi K100 Pro` |

4. 编译完去 `Releases` 下载 `recovery.img`

5. 刷入（手机进 fastboot）：
   ```bash
   fastboot flash recovery recovery.img
   fastboot reboot recovery
   ```

## 已知限制

- **`/data` 解密**: Android 17 + Secretkeeper + TME，橙狐主线（12.1）无法解密用户数据。能进界面、能刷机、能备份 system/boot，但读不了 `/data`。
- **cmdline**: 若真机卡开机，优先排查 `BoardConfig.mk` 里的 `BOARD_KERNEL_CMDLINE`。
- **触摸**: 新平台触摸 IC 驱动若不在内置列表，可能需要 OTG 鼠标或补驱动。
- **AVB**: 刷完若红字，需 `fastboot --disable-verity --disable-verification flash vbmeta`，或刷 `vbmeta.img`（已禁用校验版）。
