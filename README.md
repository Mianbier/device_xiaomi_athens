# device/xiaomi/athens — OrangeFox Recovery 设备树

红米 K100 Pro（代号 **athens**）的橙狐 Recovery 设备树。

## 设备参数（全部从全量包实测，零猜测）

| 项 | 值 | 来源 |
|---|---|---|
| 代号 | athens | payload |
| 平台 | **Canoe / SM8850**（骁龙 8 Elite Gen 5） | dtbo：`Qualcomm Technologies, Inc. Athens based on SM8850` |
| 系统 | **Android 16 / HyperOS 4.0** | vendor_boot cmdline：`swinfo.fingerprint=athens:16/OS4.0.0.8.XPICN` |
| 屏幕 | **1440 × 3200 @120Hz** | dtbo 面板 `nt37801 amoled cmd mode dsi csot panel with DSC` |
| 内核 | 42,101,248 B 未压缩 ARM64 Image（`MZ` 魔数） | boot.img @4096 |
| DTB | 6.5 MB | vendor_boot.img |
| boot header | v4，page_size 4096 | recovery/boot/vendor_boot 头 |
| recovery.img | kernel_size=**0**，ramdisk=**LZ4**（`02214c18`） | 原厂 recovery.img |
| recovery 分区 | 100 MiB | payload |
| 动态分区合计 | 11.15 GiB（super 取 12 GiB） | 各分区 img 尺寸求和 |
| /metadata | **f2fs**（不是 ext4） | 原厂 fstab.qcom |
| UFS 控制器 | `1d84000.ufshc` | 原厂 fstab.qcom |

## 目录结构

```
device/xiaomi/athens/
├── AndroidProducts.mk      # PRODUCT_MAKEFILES + COMMON_LUNCH_CHOICES
├── Android.bp              # soong_namespace
├── Android.mk              # TARGET_DEVICE 门控
├── BoardConfig.mk
├── device.mk
├── fox_athens.mk           # OrangeFox OF_* 设置
├── twrp_athens.mk          # 顶层产品（文件名必须 == PRODUCT_NAME）
├── recovery.fstab
├── vendor.prop
├── vendorsetup.sh
└── prebuilt/
    ├── kernel              # 42MB 原始内核
    └── dt.img              # 6.5MB vendor DTB
```

> ⚠️ **构建系统关键约束**：`PRODUCT_MAKEFILES` 里若不写 `name:path` 形式，
> Android 会用「产品 mk 的文件名去掉 `.mk`」当产品名。所以必须叫
> `twrp_athens.mk` 且 `PRODUCT_NAME := twrp_athens`，两者必须完全一致，
> 否则 `lunch twrp_athens-eng` 会报
> `Can not locate config makefile for product "twrp_athens"`。

## 云端编译（不用本地 Linux）

1. 推送到新仓库 `device_xiaomi_athens`
2. Fork 构建器：<https://github.com/LimeBlogs/OrangeFox-Recovery-Builder>
3. Fork 里先点 **Actions → I understand my workflows, go ahead and enable them**
4. `Actions → OrangeFox - 构建 → Run workflow`：

   | 项 | 值 |
   |---|---|
   | OrangeFox 版本 | `12.1` |
   | OrangeFox设备树 | `https://github.com/<你>/device_xiaomi_athens` |
   | 设备树分支 | `main` |
   | 设备路径 | `device/xiaomi/athens` |
   | 设备代号 | `athens` |
   | 构建目标 | `recovery` |
   | 设备名称 | `Redmi K100 Pro` |

5. 产物在 `upload_artifacts` / Releases

## 刷入

```bash
adb reboot bootloader
fastboot flash recovery_a recovery.img
fastboot flash recovery_b recovery.img
fastboot reboot recovery
```

## 已知限制

- **`/data` 解密**：Android 16 使用 **Secretkeeper + TME**（Rust 实现），
  主线橙狐（12.1）无法解密用户数据。可进界面、可刷机、可备份 boot/system，
  但读不了 `/data`。要解密需移植对应 vendor 的 Rust keymint/gatekeeper 服务。
- **cmdline**：真机若卡开机，优先排查 `BoardConfig.mk` 的 `BOARD_KERNEL_CMDLINE`。
- **触摸**：新平台触摸 IC 驱动若不在 `TW_LOAD_VENDOR_MODULES`，可能需 OTG 鼠标。
- **AVB**：刷完若红字警告，需 `fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img`。
- **屏幕**：`TW_THEME := portrait_hdpi` 若显示比例不对，可试 `portrait_xhdpi` /
  `portrait_xxhdpi`，并同步调整 `fox_athens.mk` 的 `OF_SCREEN_H/W`。

## 维护者

WorkBuddy — Unofficial build
