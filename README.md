# UniXNU-dumpling（草稿）

OnePlus 5T（`dumpling`，MSM8998 / Snapdragon 835）的 UniXNU 设备仓库草稿。

> **UEFI + UniXNU + DumplingInfo 已在 5T 真机验证（2026-11-09）；XNU 尚未启动。**
> 本目录从 [`lss717/UniXNU-cheeseburger`](https://github.com/lss717/UniXNU-cheeseburger)
> 机械改名得到，板级值已经按 5T 实测更新；仍有少量 `TODO(measure)` 标记。

## 已确认的 5T 事实

| 项目 | 值 | 来源 |
| --- | --- | --- |
| SoC | Qualcomm MSM8998（Snapdragon 835），4×Kryo 280 Gold + 4×Silver | 官方规格 |
| GPU | Adreno 540 | 官方规格 |
| 屏幕 | 三星 S6E3FC1，1080×2160，24bpp，4-lane DSI | `edk2-msm8998` 的 `dumpling/panelcfg.asl` |
| 触摸 | Synaptics **S3320**，I2C5 地址 `0x20`，digitizer 高度 137 mm | Android `/proc/bus/input/devices`、`dumpling/cust_touch.asl` |
| UEFI | `edk2-msm8998` 官方有 `dumpling` target（ACPI ✅） | `edk2-porting/edk2-msm8998` |
| 机型 board-id | `<8 0 17801 43>` | mainline `msm8998-oneplus-dumpling.dts` |
| 按键 | 电源、音量上/下；无 Home 键 | 5T 硬件 |
| RAM | 8 GB 版本；UEFI 可见 **7839 MiB** / 51 descriptors | `DumplingInfo.efi` 2026-11-09 |
| UFS | 4096 B 逻辑块；LUN0 29,765,632 blocks / 116,272 MiB | `DumplingInfo.efi` + `getvar` |
| `userdata` | `0x14F40`..`0x1C62FFA`，29,679,803 blocks / 115,936 MiB | GPT 实测 |
| GOP | `0x9D400000`，1080×2160，stride 1080，fmt 1，size `0x8E6200` | `DumplingInfo.efi` |

## 仍待实测

- [ ] PMIC/PM8005 电源轨与 CPRh 表是否与一加 5 一致
- [ ] 面板初始化、背光、DSI 时序是否由 UEFI 完整处理（目前显示正常）
- [ ] 触摸坐标范围、报点方向、中断 GPIO
- [ ] 音量/电源键在 UniXNU 菜单中的输入映射

采集方式：把 `DumplingInfo.efi` 放进 payload 的 `EFI/UniXNU/`，从 UniXNU 菜单启动；
它会打印内存、GOP 和每个整盘的 GPT `userdata` 边界。

## 与 cheeseburger 的主要差异

| 项目 | 一加 5 | 一加 5T |
| --- | --- | --- |
| 屏幕 | 1080×1920 | **1080×2160** |
| 面板 | 三星（5.5"） | **S6E3FC1（6.01"）** |
| 触摸 digitizer | 122 mm 级 | **137 mm** |
| board-id | `<8 0 16859 23>` | **`<8 0 17801 43>`** |
| framebuffer 大小 | `0x7E9000` | **`0x8E6200`**（base `0x9D400000`） |
| 其余平台 | MSM8998、UFS 2.1、PM8998/PMI8998/PM8005、Adreno 540 | 基本相同，仍需逐项确认 |

## 目录

```text
board.toml                 板级配置（含 TODO(measure) 标记）
configs/dumpling_defconfig 内核配置草稿
scripts/                   从 cheeseburger 改名而来的构建/检查脚本
uefi/                      5T 的 edk2 overlay（UniXNU + DarwinBoot + DumplingBootMemoryDxe）
assets/ package/ patches/  占位目录
unixnu.lock                XNU/依赖的固定版本
```

`uefi/` 是本项目新增的部分：上游 `edk2-msm8998` 的 `dumpling` target 只做
Windows/Linux 启动，不包含 UniXNU/DarwinBoot。overlay 把 cheeseburger 的 B 线
集成搬到 dumpling，并删掉占空间的 `LinuxSimpleMassStorage` 和 SimpleInit GUI。

## 构建顺序

以下命令**在项目根目录**（`oneplus5t-xnu/`）执行：

```text
oneplus5t-xnu/
  upstream/UniXNU/
  upstream/edk2-msm8998/
  device/                 ← 本目录
```

### 1. 把 overlay 应用到 edk2

```sh
./device/uefi/apply-overlay.sh upstream/edk2-msm8998
```

### 2. 构建 5T UEFI

```sh
./scripts/build-uefi.sh
```

或手动：

```sh
cd upstream/edk2-msm8998
UNIXNU_TREE="$PWD/../UniXNU" bash build.sh --device dumpling --release RELEASE
```

产物：`boot-dumpling.img`（edk2 根目录）和 `workspace/uefi-dumpling.img.gz-dtb`。
2026-11-09 已在本机编译通过；FVMAIN 里包含 UniXNU/DarwinBoot/DumplingBootMemoryDxe。

### 3. 生成 payload 和 boot image

在 `device/` 下：

```sh
python3 scripts/make-bootimg.py \
  --payload out/dumpling/boot/payload.img \
  --out out/dumpling/boot/boot.img
```

payload 的生成依赖 UniXNU 的 `unixnu build` / macOS CI；首次 bring-up 可以先
复用一加 5 的 payload 结构，但必须替换成 5T 的 ADT。

### 4. 生成 5T 的 ADT

```sh
python3 scripts/make-dumpling-adt.py \
  --output out/dumpling/boot/kernel.macho.adt \
  --dram-size 0x200000000 --owned-memory-size 0x100000000 \
  --cpu-regs 0,1,2,3,0x100,0x101,0x102,0x103 --ipad-identity \
  --packed-data-ramdisk --trust-cache --gpu-addon \
  --root-match-volume-uuid 04769D26-2CA0-4825-B443-E2E5F88300F2
python3 scripts/check-adt.py --adt out/dumpling/boot/kernel.macho.adt \
  --require PackedRAMDisk --require TrustCache --require GpuAddon
```

`--dram-size` 对 6 GB 版本要改成实测值；`--owned-memory-size` 也要相应缩小。

### 5. 预检并启动

```sh
python3 scripts/check-dumpling.py
fastboot boot out/dumpling/boot/boot.img
```

`check-dumpling.py` 期望的是 B 线 boot image（kernel/ramdisk/tags 在
`0x10000000/0x12000000/0x18000000`）。上游 `build.sh` 生成的
`boot-dumpling.img` 三个地址都是 `0x10000000`，只用于 UEFI 冒烟，
不能通过这个检查。

`fastboot boot` 只把镜像加载到 RAM，不写分区；但后续写 APFS/HFS+ root 到
`userdata` 是破坏性操作。

## 当前状态

| 阶段 | 状态 |
| --- | --- |
| 上游仓库拉取 | ✅ 2026-11-09 |
| 设备仓库草稿 | ✅ 机械改名 + 5T 已知值 |
| 5T UEFI overlay | ✅ 初版，2026-11-09 编译通过 |
| ADT 生成/校验 | ✅ 2026-11-09 通过 |
| boot image 打包/预检 | ✅ dummy payload 冒烟通过 |
| **5T 真机 UEFI 启动** | ✅ 2026-11-09，UniXNU 菜单 + DumplingInfo 成功 |
| **5T 真机按键输入** | ✅ 音量上/下选择、电源键确认（patched ButtonsDxe） |
| 5T XNU 启动 | ⬜ 待测 |
| UFS/APFS/launchd | ⬜ 待测 |
| 触摸/显示/GPU | ⬜ 待测 |

## 警告

- 这是研究性 bring-up，不是日常可用系统；没有电话、WiFi、蓝牙、相机、音频、充电、休眠。
- 安全模型基本关闭（AMFI/沙盒/数据保护被绕过），不要放个人数据。
- 写 root 镜像会清掉 Android 的 `userdata`；先备份 `persist`、`modemst1/2`、`fsg`、`fsc`、
  `boot`、`recovery`、`abl`、`xbl`、`tz`、`keymaster` 和 GPT。
- 机械改名不改变硬件事实；所有 `TODO(measure)` 必须在 5T 上确认。
