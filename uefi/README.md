# 5T UEFI overlay

上游 `edk2-msm8998` 的 `dumpling` target 已经能启动 Windows/Linux，但它的
DSC/FDF **不包含** UniXNU、DarwinBoot 和 `BootMemoryDxe`。一加 5 的
`unixnu-cheeseburger` 分支把这些加进了 `cheeseburger` target，本目录把同样的
集成搬到 `dumpling`。

## 内容

```text
overlay/Platforms/Msm8998Pkg/Device/oneplus/dumpling/
  dumpling.dsc
  dumpling.fdf
  Applications/DumplingInfo/
  Drivers/DumplingBootMemoryDxe/
```

- `dumpling.dsc`：在上游 dumpling DSC 上追加 `[LibraryClasses]` 和 `[Components]`
- `dumpling.fdf`：删掉 `LinuxSimpleMassStorage`（内嵌 6.9 MiB Linux）和
  SimpleInit GUI，加入 SerialDxe、DumplingBootMemoryDxe、UniXNU、UniXNUDxe、DarwinBoot
- `DumplingInfo`：从 `CheeseburgerInfo` 改名；只构建，不放进 FV，由 UniXNU 从
  payload ESP 启动，用来打印 5T 的 RAM/GOP/GPT
- `DumplingBootMemoryDxe`：从 `CheeseburgerBootMemoryDxe` 改名；把
  `/chosen/linux,initrd-*` 描述的 initrd 发布成只读 BlockIo，供 FAT 驱动挂载 payload

## 应用

```sh
./device/uefi/apply-overlay.sh upstream/edk2-msm8998
```

`cp --backup=numbered` 会保留被覆盖文件的原件（`*.~1~`）。

## 构建环境补丁

`apply-overlay.sh` 还会做几处**本机构建环境**的补丁（不是 5T 硬件相关）：

- `build.sh`：源码快照不是 git 仓库，跳过 `git submodule update`（submodule 已按 SHA 解压好）
- `BaseTools/.../header.makefile`：GCC 15 的 warning 不再当 error
- `Pccts/{antlr,dlg}/makefile`：加 `-std=gnu89 -Wno-error`（Pccts 1.33 的旧式函数指针）
- `tools_def.template` / `tools_def.txt`：GCC5 AARCH64 固定 `-std=gnu11`（避免 GCC 15 默认 C23）
- `MdePkg/Include/{AsmMacroLib.h,Library/FdtLib.h}`：从 cheeseburger 计划里带来的兼容 shim

## 已验证

2026-11-09 在 CachyOS + GCC 16.2.1 + aarch64-linux-gnu-gcc 16.2.0 上成功构建：

```text
Build done: .../upstream/edk2-msm8998/boot-dumpling.img
FVMAIN [99%Full] 12702784 total, 12702728 used, 56 free
FVMAIN_COMPACT [17%Full] 6258688 total, 1078376 used, 5180312 free
```

FVMAIN 是 `NumBlocks = 0`（按内容定大小），99% 是正常的；外层 6 MiB FV 还有约 4.94 MiB 空间。
FVMAIN 里已确认包含 `UniXNU`、`UniXNUDxe`、`DarwinBoot`、`DumplingBootMemoryDxe`、`SerialDxe`。
`DumplingInfo` 只构建、不进 FV。

## 5T 真机验证（2026-11-09）

- [x] `fastboot boot` 加载 UEFI，UniXNU 菜单出现
- [x] `DumplingInfo.efi` 执行，打印 RAM/GOP/GPT：
  - RAM 7839 MiB / 51 descriptors
  - GOP `0x9D400000`, 1080×2160, stride 1080, fmt 1, size `0x8E6200`
  - `userdata 0x14F40..0x1C62FFA`
- [x] 音量上/下移动菜单高亮，电源键确认
- [x] 移除 `TerminalDxe` 后文字不再重复显示

### 两个真机修复

1. **`DumplingInfo` 返回 Not Found**
   - 原因：UniXNU 的 `path` 是相对 `\EFI\UniXNU` 解析的，不是 FAT 根目录。
   - 修复：`path = "DumplingInfo.efi"`，不要写 `EFI/UniXNU/DumplingInfo.efi`。

2. **音量/电源键不工作 + 文字显示两遍**
   - 按键：5T 的 FDF 原来用 `common/Binaries/ButtonsDxe`，在 5T 上不产生输入；
     换成 `cheeseburger/PatchedBinaries/ButtonsDxe`（带 TLMM/PWR_ON 支持）后正常。
     5T 与一加 5 的音量键都在 PM8998 GPIO5/6，所以这个二进制可以复用。
   - 显示：`GraphicsConsoleDxe` 和 `TerminalDxe` 同时挂在 ConOut 上，都往同一块
     framebuffer 画；从 dumpling FDF 移除 `TerminalDxe` 后只显示一遍。

## 还没做的事

- [ ] 把 5T 专用的 `ButtonsDxe` 补丁整理成 overlay 里的显式文件（目前是复制替换）
- [ ] 把 `UniXNU/plans/oneplus5-cheeseburger/patches/` 里的 UEFI 补丁按需移植到 dumpling
- [ ] 若 5T 的 FV 仍然超限，进一步裁剪 Shell、UiApp 等

## 参考

- 上游 dumpling：`upstream/edk2-msm8998/Platforms/Msm8998Pkg/Device/oneplus/dumpling/`
- cheeseburger 的 B 线集成：`upstream/edk2-msm8998/Platforms/Msm8998Pkg/Device/oneplus/cheeseburger/`
- 计划和实测记录：`upstream/UniXNU/plans/oneplus5-cheeseburger/`
