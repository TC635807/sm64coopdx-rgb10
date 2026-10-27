#!/usr/bin/env bash
# apply-patches.sh -- 把本仓的 3 个补丁打到 upstream sm64coopdx v1.5.1 源码树上
#
# 用法:
#   bash scripts/apply-patches.sh [源码目录]        # 默认当前目录
#
# 源码目录应该是 coop-deluxe/sm64coopdx 的 v1.5.1 checkout。
# 在 git 仓库里用 git apply（可 --reverse --check 判重），否则用 patch -p1。
set -euo pipefail

TARGET="${1:-.}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PATCHDIR="$HERE/../patches"

[ -d "$TARGET" ] || { echo "apply-patches: 源码目录不存在: $TARGET" >&2; exit 1; }
[ -d "$PATCHDIR" ] || { echo "apply-patches: 找不到补丁目录: $PATCHDIR" >&2; exit 1; }
[ -f "$TARGET/Makefile" ] || { echo "apply-patches: $TARGET 不像 sm64coopdx 源码树（缺 Makefile）" >&2; exit 1; }

# 版本提示（不硬性拦截，方便打在自己 fork 的其他版本上）
if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  DESC="$(git -C "$TARGET" describe --tags --always 2>/dev/null || true)"
  case "$DESC" in
    v1.5.1*) : ;;
    *) echo "apply-patches: 注意: 当前源码版本是 '$DESC'，补丁按 v1.5.1 生成" >&2 ;;
  esac
  USE_GIT=1
else
  USE_GIT=0
  echo "apply-patches: 非 git 源码树，改用 patch -p1"
fi

shopt -s nullglob
PATCHES=("$PATCHDIR"/*.patch)
shopt -u nullglob
[ ${#PATCHES[@]} -gt 0 ] || { echo "apply-patches: $PATCHDIR 下没有 .patch" >&2; exit 1; }

for p in "${PATCHES[@]}"; do
  name="$(basename "$p")"
  if [ "$USE_GIT" = 1 ]; then
    if git -C "$TARGET" apply --reverse --check "$p" >/dev/null 2>&1; then
      echo "  skip  $name（已应用）"
      continue
    fi
    if ! git -C "$TARGET" apply --check "$p" >/dev/null 2>&1; then
      echo "  FAIL  $name（上下文不匹配，源码版本不对？）" >&2
      exit 1
    fi
    git -C "$TARGET" apply "$p"
    echo "  apply $name"
  else
    if patch -d "$TARGET" -p1 --forward --dry-run -s < "$p" >/dev/null 2>&1; then
      patch -d "$TARGET" -p1 --forward -s < "$p"
      echo "  apply $name"
    else
      echo "  skip  $name（已应用或上下文不匹配）"
    fi
  fi
done

echo
echo "apply-patches: 完成。下一步："
echo "  cp /path/to/your.z64 $TARGET/baserom.us.z64"
echo "  bash scripts/build-cross.sh $TARGET"
