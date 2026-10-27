#!/usr/bin/env bash
# build-cross.sh -- 在 x86-64 Linux 上交叉构建 RGB10 用的 aarch64 产物
#
# 用法:
#   export PATH="$HOME/rgb10-cross/bin:$PATH"
#   bash scripts/build-cross.sh [源码目录]
#
# 需要:
#   - 源码目录 = upstream v1.5.1 + patches/ 已应用 + baserom.us.z64
#   - 交叉 wrapper 与 sysroot（见 docs/CROSS-BUILD.md）
#
# 可覆盖的环境变量:
#   SYSROOT    默认 $HOME/rgb10-sysroot
#   CROSS_BIN  默认 $HOME/rgb10-cross/bin（加入 PATH）
#   CROSS      默认 aarch64-linux-gnu-
#   JOBS       默认 $(nproc)
set -euo pipefail

SRC="${1:-.}"
SYSROOT="${SYSROOT:-$HOME/rgb10-sysroot}"
CROSS_BIN="${CROSS_BIN:-$HOME/rgb10-cross/bin}"
CROSS="${CROSS:-aarch64-linux-gnu-}"
JOBS="${JOBS:-$(nproc)}"

die() { echo "build-cross: $*" >&2; exit 1; }

[ -f "$SRC/Makefile" ] || die "$SRC 不像 sm64coopdx 源码树（缺 Makefile）"
[ -d "$SYSROOT" ] || die "sysroot 不存在: $SYSROOT（见 docs/CROSS-BUILD.md）"
[ -d "$CROSS_BIN" ] || die "交叉 wrapper 目录不存在: $CROSS_BIN（见 docs/CROSS-BUILD.md）"
command -v "${CROSS}gcc" >/dev/null 2>&1 || die "找不到 ${CROSS}gcc"

export PATH="$CROSS_BIN:$PATH"
export SYSROOT

[ -f "$SRC/baserom.us.z64" ] || die "缺 $SRC/baserom.us.z64（自备 US 版 ROM，md5 20b854b239203baf6c961b850a4a51a2）"
ROM_MD5="$(md5sum "$SRC/baserom.us.z64" | cut -d' ' -f1)"
[ "$ROM_MD5" = "20b854b239203baf6c961b850a4a51a2" ] || die "baserom.us.z64 不是 US 版（md5=$ROM_MD5）"

# 设备时钟常与 PC 差很多；源码 mtime 在“未来”会让 make 反复重建
echo "==> 归一化 mtime"
( cd "$SRC" && find . -exec touch -h {} + )

echo "==> make TARGET_RPI=1 machine=aarch64 CROSS=$CROSS -j$JOBS"
( cd "$SRC" && make TARGET_RPI=1 machine=aarch64 CROSS="$CROSS" -j"$JOBS" )

BIN="$SRC/build/us_pc/sm64coopdx.arm"
[ -f "$BIN" ] || die "构建结束但没有 $BIN"

echo
echo "==> 产物"
ls -lh "$BIN"
file "$BIN"
echo "==> 符号版本（设备 glibc 2.30 / libstdc++ 6.0.28 = GLIBCXX 3.4.28）"
objdump -T "$BIN" | grep -o 'GLIBC_[0-9.]*'   | sort -Vu | tail -1
objdump -T "$BIN" | grep -o 'GLIBCXX_[0-9.]*' | sort -Vu | tail -1
echo
echo "下一步: bash scripts/package-release.sh $BIN --version v1.0.0"
