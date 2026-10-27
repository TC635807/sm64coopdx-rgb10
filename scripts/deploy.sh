#!/bin/bash
# deploy.sh -- 在 Powkiddy RGB10 (ArkOS) 上安装 sm64coopdx Ports 包
#
# ★ 这个脚本在**设备上**运行（不会启动游戏）。PC 侧先把文件 scp 到 /tmp。
#
# 用法（PC 侧）:
#   scp sm64coopdx-rgb10-v1.0.0.tar.gz ark@169.254.224.64:/tmp/
#   scp -r scripts config ark@169.254.224.64:/tmp/port/
#   ssh ark@169.254.224.64 'bash /tmp/port/scripts/deploy.sh \
#        --tarball /tmp/sm64coopdx-rgb10-v1.0.0.tar.gz --rom /tmp/baserom.us.z64'
#
# 安装结果:
#   /roms/ports/sm64coopdx.sh                     <- ES Ports 菜单入口
#   /roms/ports/sm64coopdx/{sm64coopdx,dynos,lang,mods,palettes}
#   ~/.local/share/sm64coopdx/sm64config.txt      <- 游戏真正读的配置
#   ~/.local/share/sm64coopdx/gamecontrollerdb.txt
#   ~/.local/share/sm64coopdx/baserom.us.z64      <- ROM（游戏在这里找）
#
# 只写 $PREFIX（默认 /roms/ports）与 ~/.local/share/sm64coopdx；不碰 /usr、网络。
#
# 选项:
#   --tarball PATH    Release 包（默认 /tmp/sm64coopdx-rgb10-v1.0.0.tar.gz）
#   --rom PATH        baserom.us.z64（不给就按 同目录/游戏目录/tmp 顺序找）
#   --force-config    覆盖已有 sm64config.txt / gamecontrollerdb.txt
#   --no-config       不装配置
#   --prefix DIR      换安装根（自测用，默认 /roms/ports）
#   --dry-run         只打印动作

set -u

PREFIX="/roms/ports"
PREF="${XDG_DATA_HOME:-$HOME/.local/share}/sm64coopdx"
SRCDIR="$(cd "$(dirname "$0")" && pwd)"
CONFIGDIR="$SRCDIR/../config"
[ -d "$CONFIGDIR" ] || CONFIGDIR="$SRCDIR"

TARBALL="/tmp/sm64coopdx-rgb10-v1.0.0.tar.gz"
ROM=""
FORCE_CONFIG=0
SKIP_CONFIG=0
DRY=0

die()  { echo "deploy: ERROR: $*" >&2; exit 1; }
info() { echo "deploy: $*"; }
run()  { if [ "$DRY" = 1 ]; then echo "  [dry] $*"; else "$@"; fi; }

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)       PREFIX="$2"; shift 2 ;;
    --tarball)      TARBALL="$2"; shift 2 ;;
    --rom)          ROM="$2"; shift 2 ;;
    --force-config) FORCE_CONFIG=1; shift ;;
    --no-config)    SKIP_CONFIG=1; shift ;;
    --dry-run)      DRY=1; shift ;;
    -h|--help)      sed -n '2,30p' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

GAMEDIR="$PREFIX/sm64coopdx"
LAUNCHER="$PREFIX/sm64coopdx.sh"
STAGE="$GAMEDIR/.stage.$$"

# ---------------------------------------------------------------- 前置检查
if [ "$PREFIX" = "/roms/ports" ]; then
  [ -d /roms/ports ] || die "没找到 /roms/ports —— 这个脚本要在 RGB10 (ArkOS) 上跑"
else
  info "自测模式: --prefix $PREFIX（不写 /roms/ports）"
  run mkdir -p "$PREFIX" || die "建不了 $PREFIX"
fi
[ -f "$TARBALL" ] || die "找不到安装包: $TARBALL（用 --tarball 指定）"
[ -f "$CONFIGDIR/sm64config.txt" ] || die "$CONFIGDIR 下缺 sm64config.txt"
[ -f "$SRCDIR/sm64coopdx.sh" ] || die "$SRCDIR 下缺 sm64coopdx.sh"

info "tarball = $TARBALL ($(du -h "$TARBALL" 2>/dev/null | cut -f1))"
info "game    = $GAMEDIR"
info "pref    = $PREF"

# ---------------------------------------------------------------- 1. 解包
# 先解到 staging，再归位到 GAMEDIR：压缩包顶层结构可能是 sm64coopdx/
# 或 sm64coopdx-rgb10-v1.0.0/sm64coopdx/，直接解会互相覆盖。
info "解包到 staging ..."
run mkdir -p "$GAMEDIR"
if [ "$DRY" = 1 ]; then
  echo "  [dry] mkdir -p $STAGE"
  echo "  [dry] tar -xzf $TARBALL -C $STAGE"
else
  mkdir -p "$STAGE" || die "建不了 staging $STAGE"
  if ! tar --warning=no-timestamp -xzf "$TARBALL" -C "$STAGE" 2>"$STAGE/.tar.log"; then
    sed 's/^/  tar: /' "$STAGE/.tar.log" >&2
    rm -rf "$STAGE"
    die "解包失败"
  fi
  rm -f "$STAGE/.tar.log"
fi

if [ "$DRY" = 0 ]; then
  BINPATH="$(find "$STAGE" -maxdepth 6 -type f -name sm64coopdx 2>/dev/null | head -1)"
  [ -n "$BINPATH" ] || BINPATH="$(find "$STAGE" -maxdepth 6 -type f -name 'sm64coopdx.arm' 2>/dev/null | head -1)"
  [ -n "$BINPATH" ] || { rm -rf "$STAGE"; die "安装包里没有 sm64coopdx / sm64coopdx.arm"; }
  TOP="$(dirname "$BINPATH")"
  info "二进制位置: $TOP  ->  归位到 $GAMEDIR"
  cp -a "$TOP"/. "$GAMEDIR"/ || { rm -rf "$STAGE"; die "归位失败（$TOP -> $GAMEDIR）"; }
  rm -rf "$STAGE"
  if [ ! -f "$GAMEDIR/sm64coopdx" ] && [ -f "$GAMEDIR/sm64coopdx.arm" ]; then
    mv -f "$GAMEDIR/sm64coopdx.arm" "$GAMEDIR/sm64coopdx" && info "重命名 sm64coopdx.arm -> sm64coopdx"
  fi
  [ -f "$GAMEDIR/sm64coopdx" ] || die "归位后 $GAMEDIR/sm64coopdx 仍不存在"

  # exFAT 没有 unix 权限位，tar 还原不了，必须显式 chmod
  info "设置权限（exFAT 无权限位，必须显式 chmod）..."
  chmod 755 "$GAMEDIR/sm64coopdx"
  chmod -R u+rwX,go+rX "$GAMEDIR" 2>/dev/null

  # 设备时钟与 PC 可能差很多（源码 mtime 在“未来”会让 make 反复重建），统一压平
  info "归一化 mtime（防止以后在设备上 make 时反复重建）..."
  find "$GAMEDIR" -exec touch -h {} + 2>/dev/null
fi

# ---------------------------------------------------------------- 2. 启动器
info "安装启动器 -> $LAUNCHER"
run cp -f "$SRCDIR/sm64coopdx.sh" "$LAUNCHER"
run chmod 755 "$LAUNCHER"

# ---------------------------------------------------------------- 3. 配置 + 手柄 db
run mkdir -p "$PREF"
run cp -f "$CONFIGDIR/sm64config.txt" "$GAMEDIR/sm64config.txt.default"
[ -f "$CONFIGDIR/gamecontrollerdb.txt" ] && run cp -f "$CONFIGDIR/gamecontrollerdb.txt" "$GAMEDIR/gamecontrollerdb.txt"

if [ "$SKIP_CONFIG" = 0 ]; then
  if [ -f "$PREF/sm64config.txt" ] && [ "$FORCE_CONFIG" = 0 ]; then
    info "已存在 $PREF/sm64config.txt，保留（要覆盖加 --force-config）"
  else
    run cp -f "$CONFIGDIR/sm64config.txt" "$PREF/sm64config.txt"
    info "写入配置 $PREF/sm64config.txt"
  fi
fi

if [ -f "$CONFIGDIR/gamecontrollerdb.txt" ]; then
  if [ -f "$PREF/gamecontrollerdb.txt" ] && [ "$FORCE_CONFIG" = 0 ]; then
    info "已存在 $PREF/gamecontrollerdb.txt，保留"
  else
    run cp -f "$CONFIGDIR/gamecontrollerdb.txt" "$PREF/gamecontrollerdb.txt"
    info "写入手柄映射 $PREF/gamecontrollerdb.txt"
  fi
fi

# ---------------------------------------------------------------- 4. ROM
# main_rom_handler(): 扫 写路径 + exe 目录 下的 *.z64，校验 md5(US=20b854b239203baf6c961b850a4a51a2)，
# 再复制成 $PREF/baserom.us.z64。直接放到 $PREF 可以省掉每次启动的 8MB 复制。
if [ ! -f "$PREF/baserom.us.z64" ]; then
  if [ -z "$ROM" ]; then
    for c in "$SRCDIR/baserom.us.z64" "$GAMEDIR/baserom.us.z64" "/tmp/baserom.us.z64"; do
      [ -f "$c" ] && ROM="$c" && break
    done
  fi
  if [ -n "$ROM" ] && [ -f "$ROM" ]; then
    info "安装 ROM: $ROM -> $PREF/baserom.us.z64"
    run cp -f "$ROM" "$PREF/baserom.us.z64"
  else
    echo "deploy: WARNING: 没找到 baserom.us.z64（用 --rom 指定）" >&2
    echo "deploy:          没有 ROM 游戏会停在 ROM setup 画面" >&2
  fi
else
  info "ROM 已存在: $PREF/baserom.us.z64"
fi

# ---------------------------------------------------------------- 5. 自检
echo
info "==== 安装结果 ===="
if [ "$DRY" = 0 ]; then
  ls -la "$GAMEDIR" | head -20
  echo "--- launcher ---"; ls -la "$LAUNCHER"
  echo "--- pref ---";     ls -la "$PREF" 2>/dev/null | head -12
  echo "--- binary ---"
  (file "$GAMEDIR/sm64coopdx" 2>/dev/null || echo "(no file(1))")
  echo "--- 关键项 ---"
  for d in dynos lang mods palettes; do
    [ -d "$GAMEDIR/$d" ] && echo "  ok   $d/" || echo "  MISS $d/"
  done
  [ -f "$PREF/sm64config.txt" ]       && echo "  ok   config"          || echo "  MISS config"
  [ -f "$PREF/gamecontrollerdb.txt" ] && echo "  ok   gamecontrollerdb" || echo "  MISS gamecontrollerdb"
  [ -f "$PREF/baserom.us.z64" ]       && echo "  ok   baserom.us.z64"  || echo "  MISS baserom"
fi
echo
info "下一步: EmulationStation -> Ports -> sm64coopdx。日志: $GAMEDIR/sm64coopdx-run.log"
