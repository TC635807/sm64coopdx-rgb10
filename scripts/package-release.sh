#!/usr/bin/env bash
# package-release.sh -- 把构建产物打包成 ArkOS Ports 目录结构（Release 用）
#
# 用法:
#   bash scripts/package-release.sh build/us_pc/sm64coopdx.arm [--version v1.0.0] [--source-root DIR]
#
# 输出:
#   dist/sm64coopdx-rgb10-<version>.tar.gz
#   dist/SHA256SUMS.txt
#
# 包内结构:
#   sm64coopdx-rgb10-<version>/
#   ├── sm64coopdx.sh          -> 复制到 /roms/ports/
#   └── sm64coopdx/            -> 复制到 /roms/ports/sm64coopdx/
#       ├── sm64coopdx
#       ├── dynos/ lang/ mods/ palettes/
#       ├── sm64config.txt.default
#       └── gamecontrollerdb.txt
set -euo pipefail

BIN=""
VERSION="v1.0.0"
SRCROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --version)    VERSION="$2"; shift 2 ;;
    --source-root) SRCROOT="$2"; shift 2 ;;
    -h|--help)    sed -n '2,22p' "$0"; exit 0 ;;
    -*)           echo "package-release: unknown option $1" >&2; exit 1 ;;
    *)            BIN="$1"; shift ;;
  esac
done

die() { echo "package-release: $*" >&2; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIGDIR="$HERE/../config"

[ -n "$BIN" ] || die "用法: bash scripts/package-release.sh <sm64coopdx.arm> [--version v1.0.0]"
[ -f "$BIN" ] || die "二进制不存在: $BIN"
[ -f "$CONFIGDIR/sm64config.txt" ] || die "缺 $CONFIGDIR/sm64config.txt"
[ -f "$HERE/sm64coopdx.sh" ] || die "缺 $HERE/sm64coopdx.sh"

if [ -z "$SRCROOT" ]; then
  SRCROOT="$(cd "$(dirname "$BIN")/../.." && pwd)"
fi
[ -d "$SRCROOT/lang" ] || die "$SRCROOT 不像源码树（缺 lang/），用 --source-root 指定"

NAME="sm64coopdx-rgb10-$VERSION"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
PKG="$STAGE/$NAME"

mkdir -p "$PKG/sm64coopdx"
echo "==> 复制二进制"
cp -f "$BIN" "$PKG/sm64coopdx/sm64coopdx"
chmod 755 "$PKG/sm64coopdx/sm64coopdx"

echo "==> 复制运行时数据（dynos / lang / mods / palettes）"
for d in dynos lang mods palettes; do
  if [ -d "$SRCROOT/$d" ]; then
    cp -a "$SRCROOT/$d" "$PKG/sm64coopdx/"
  else
    echo "    warn: 源码树没有 $d/，跳过" >&2
  fi
done

echo "==> 复制启动器与默认配置"
cp -f "$HERE/sm64coopdx.sh" "$PKG/sm64coopdx.sh"
chmod 755 "$PKG/sm64coopdx.sh"
cp -f "$CONFIGDIR/sm64config.txt" "$PKG/sm64coopdx/sm64config.txt.default"
[ -f "$CONFIGDIR/gamecontrollerdb.txt" ] && cp -f "$CONFIGDIR/gamecontrollerdb.txt" "$PKG/sm64coopdx/gamecontrollerdb.txt"

cat > "$PKG/README.txt" <<'EOF'
sm64coopdx for Powkiddy RGB10 (ArkOS)
====================================

安装：
  1. sm64coopdx.sh            -> /roms/ports/
  2. sm64coopdx/ 整个目录      -> /roms/ports/sm64coopdx/
  3. 自备 US 版 ROM (md5 20b854b239203baf6c961b850a4a51a2)
     -> ~/.local/share/sm64coopdx/baserom.us.z64
  4. EmulationStation -> Ports -> sm64coopdx

注意：
  - 必须以 ark 用户启动（ES Ports 机制默认如此），不要用 root。
  - 首次启动会自动把 sm64config.txt.default 复制到用户目录。
  - 本包不含 ROM；Super Mario 64 版权归 Nintendo。

完整说明与构建方法: https://github.com/TC635807/sm64coopdx-rgb10
EOF

mkdir -p "$HERE/../dist"
OUT="$HERE/../dist/$NAME.tar.gz"
echo "==> 打包 $OUT"
tar --sort=name --owner=0 --group=0 --numeric-owner -czf "$OUT" -C "$STAGE" "$NAME"

( cd "$HERE/../dist" && sha256sum "$NAME.tar.gz" > SHA256SUMS.txt )

echo
echo "==> 完成"
ls -lh "$OUT" "$HERE/../dist/SHA256SUMS.txt"
cat "$HERE/../dist/SHA256SUMS.txt"
