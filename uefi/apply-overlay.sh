#!/usr/bin/env bash
# 把 OnePlus 5T 的 UniXNU/DarwinBoot 集成覆盖到 edk2-msm8998 检出上。
#
# 用法:
#   ./device/uefi/apply-overlay.sh ../upstream/edk2-msm8998
#
# overlay 基于 lss717/edk2-msm8998 的 unixnu-cheeseburger 分支
# （commit 02a1ace07bdd7ae04fc51e5f462f30ac060c825d）里的 cheeseburger
# 集成，但目标是上游的 dumpling target。应用前建议先备份 edk2 目录。

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "用法: $0 <edk2-msm8998-dir>" >&2
  exit 2
fi

EDK2_DIR="$1"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY="$HERE/overlay"

if [ ! -d "$EDK2_DIR/Platforms/Msm8998Pkg" ]; then
  echo "看起来不是 edk2-msm8998 目录: $EDK2_DIR" >&2
  exit 1
fi

if [ ! -f "$EDK2_DIR/Platforms/Msm8998Pkg/Device/oneplus/dumpling/dumpling.dsc" ]; then
  echo "找不到 dumpling target，edk2 版本不对？" >&2
  exit 1
fi

echo "==> 覆盖 $OVERLAY -> $EDK2_DIR"
cp -a --backup=numbered "$OVERLAY/." "$EDK2_DIR/"

# 本工作区的 edk2 是用 codeload tarball 解出来的普通目录，没有 .git。
# 上游 build.sh 会无条件跑 git submodule update，在非 git 树里直接失败。
# 这里的 submodule 已经由 scripts/fetch-upstreams.sh 按固定 SHA 解压好，
# 所以把判断改成“文件确实缺失时才更新”。
BUILD_SH="$EDK2_DIR/build.sh"
if [ -f "$BUILD_SH" ]; then
  python3 - "$BUILD_SH" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
old = "if ! [ -f Common/edk2/edksetup.sh ] || ! [ -f ../edk2/edksetup.sh ]\n"
new = ("# OnePlus 5T workspace: submodules are plain directories fetched from codeload.\n"
       "if ! [ -f Common/edk2/edksetup.sh ] || ! [ -d Common/edk2-platforms/Platform ] || ! [ -f GPLDrivers/Library/simple-init/SimpleInit.dec ]\n")
if old in text:
    path.write_text(text.replace(old, new, 1))
    print("==> patched build.sh: skip git submodule update in non-git snapshot")
elif new in text:
    print("==> build.sh already patched")
else:
    print("==> warning: build.sh submodule guard not found; edit manually if build fails", file=sys.stderr)
PY
fi

# 新版 GCC（15+）默认 C23，Pccts 1.33 的旧式函数指针在 C23 下会报
# “too many arguments to function”。BaseTools 的其他文件还会把 warning
# 当 error。给 Pccts 的 makefile 加上 gnu89 和 -Wno-error。
PCTS_DIR="$EDK2_DIR/Common/edk2/BaseTools/Source/C/VfrCompile/Pccts"
HEADER_MAKEFILE="$EDK2_DIR/Common/edk2/BaseTools/Source/C/Makefiles/header.makefile"
if [ -f "$HEADER_MAKEFILE" ]; then
  python3 - "$HEADER_MAKEFILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
if "-Wno-error" not in text:
    text = text.replace("-Wall -Werror \\", "-Wall -Werror -Wno-error \\")
    path.write_text(text)
    print("==> patched BaseTools header.makefile: warnings are not fatal")
else:
    print("==> BaseTools header.makefile already patched")
PY
fi

# GCC 15 的 aarch64-linux-gnu-gcc 默认 gnu23；edk2 的 GCC5 工具链和
# simple-init 的 stdbool.h 都假设更早的 C 标准。固定成 gnu11。
for tools in "$EDK2_DIR/Common/edk2/BaseTools/Conf/tools_def.template" \
             "$EDK2_DIR/Common/edk2/Conf/tools_def.txt"; do
  [ -f "$tools" ] || continue
  python3 - "$tools" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
old = "DEFINE GCC5_AARCH64_CC_FLAGS         = DEF(GCC49_AARCH64_CC_FLAGS)"
new = "DEFINE GCC5_AARCH64_CC_FLAGS         = DEF(GCC49_AARCH64_CC_FLAGS) -std=gnu11"
if old in text and "-std=gnu11" not in text:
    path.write_text(text.replace(old, new, 1))
    print(f"==> patched {path.name}: GCC5 AARCH64 uses -std=gnu11")
else:
    print(f"==> {path.name}: already patched or pattern not found")
PY
done

if [ -d "$PCTS_DIR" ]; then
  python3 - "$PCTS_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
changed = []
for name in ("antlr/makefile", "dlg/makefile"):
    path = root / name
    if not path.is_file():
        continue
    text = path.read_text()
    if "-std=gnu89" in text:
        continue
    old = "BUILD_CFLAGS= $(COPT) -I. -I$(SET) -I$(PCCTS_H) -DUSER_ZZSYN"
    new = "BUILD_CFLAGS= $(COPT) -std=gnu89 -Wno-error -I. -I$(SET) -I$(PCCTS_H) -DUSER_ZZSYN"
    if old not in text:
        print(f"==> warning: {name}: BUILD_CFLAGS pattern not found", file=sys.stderr)
        continue
    path.write_text(text.replace(old, new, 1))
    changed.append(name)

if changed:
    print("==> patched Pccts host tools for GCC 15: " + ", ".join(changed))
else:
    print("==> Pccts host tools already patched or not found")
PY
fi

# 5T 的音量键在 PM8998 GPIO5/6，与一加 5 相同；但 common ButtonsDxe
# 在 5T 上不产生输入。先复用一加 5 的 PatchedBinaries/ButtonsDxe（带
# TLMM/PWR_ON 支持），把 common 路径下的二进制替换掉。若按键仍不工作，
# 下一步再做 5T 专用的 key-test/驱动。
PATCHED_BTN="$EDK2_DIR/Platforms/Msm8998Binaries/cheeseburger/PatchedBinaries/ButtonsDxe"
COMMON_BTN="$EDK2_DIR/Platforms/Msm8998Binaries/common/Binaries/ButtonsDxe"
if [ -d "$PATCHED_BTN" ] && [ -d "$COMMON_BTN" ]; then
  echo "==> 替换 common ButtonsDxe 为 cheeseburger PatchedBinaries 版本"
  for f in ButtonsDxe.efi ButtonsDxe.depex ButtonsDxe.inf; do
    cp -a --backup=numbered "$PATCHED_BTN/$f" "$COMMON_BTN/$f"
  done
fi

echo "==> 完成"
echo "下一步:"
echo "  cd $EDK2_DIR"
echo "  UNIXNU_TREE=<UniXNU-dir> bash build.sh --device dumpling --release RELEASE"
