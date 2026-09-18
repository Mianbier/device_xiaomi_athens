# ==========================================================
# BoardConfig.mk — Redmi K100 Pro (athens)
# OrangeFox Recovery (TWRP-based) device tree
# 生成依据: payload.bin 分区表 + boot/vendor_boot 头解析
# 平台: Qualcomm GKI v4 (header_version=4, page_size=4096)
# ==========================================================

DEVICE_PATH := device/xiaomi/athens

# ---------- 引导镜像 ----------
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_HEADER_VERSION := 4
BOARD_MKBOOTIMG_ARGS += --header_version 4
BOARD_KERNEL_OFFSET := 0x00000000
BOARD_RAMDISK_OFFSET := 0x00000000
BOARD_TAGS_OFFSET := 0x00000000
BOARD_DTBOCMDLINE :=

# 内核命令行: 取自 vendor_boot cmdline (已剔除 bootconfig)
# 注意: 若真机无法开机, 优先排查此 cmdline
BOARD_KERNEL_CMDLINE := video=vfb:640x400,bpp=32,memsize=3072000 erofs.reserved_pages=64 swinfo.fingerprint=athens:16/OS4.0.0.8.XPICN:user erofs.reserved_pages=64

# ---------- 预编译内核 / DTB ----------
# boot.img 中的原始 ARM64 Image (MZ 魔数, 自带无效内联 FDT)
# 真实 DTB 来自 vendor_boot, 由编译期追加到内核尾部
BOARD_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
TARGET_PREBUILT_KERNEL := $(BOARD_PREBUILT_KERNEL)
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTIMAGE := $(DEVICE_PATH)/prebuilt/dt.img

# ---------- 架构 ----------
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_CORTEX_A := false

# ---------- 平台 ----------
TARGET_BOARD_PLATFORM := athens
TARGET_BOARD_PLATFORM_GPU := qcom

# ---------- 分区大小 (来自 payload 分区表) ----------
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296      # boot   96 MiB
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600  # recovery 100 MiB
BOARD_CACHEIMAGE_PARTITION_SIZE := 0

# system-as-root (A/B)
BOARD_BUILD_SYSTEM_ROOT_IMAGE := true
BOARD_USES_RECOVERY_AS_BOOT := false

# ---------- Recovery fstab ----------
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"

# ---------- 杂项 ----------
BOARD_HAS_LARGE_FILESYSTEM_SUPPORT := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_USES_MKE2FS := true

# ---------- OrangeFox 配置 ----------
-include $(DEVICE_PATH)/OrangeFoxConfig.mk
