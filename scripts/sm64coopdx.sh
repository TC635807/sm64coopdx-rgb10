#!/bin/bash
# sm64coopdx.sh -- ArkOS / Ports 启动器 (Powkiddy RGB10, 480x320)
#
# EmulationStation 的 Ports 系统对每个 .sh 执行的是:
#     sudo perfmax %GOVERNOR% %ROM%; nice -n -19 /usr/local/bin/AltSDL.sh %ROM%; sudo perfnorm
# 也就是说:
#   * CPU/GPU/DMC governor 已经被 ES 的 perfmax 调到 %GOVERNOR%，退出后 perfnorm 会还原
#     -> 本脚本**不需要**再调 governor，重复调用反而可能和 ES 的 perfnorm 打架。
#   * AltSDL.sh 只会在 ~/.config/.DEFAULT_PORTS_SDL 存在时做 LD_PRELOAD
#     (本机该文件不存在 -> 直接 exec 本脚本)。
#   * 本脚本以 ark 用户运行；/roms 可写，sudo 免密。
#
# 本脚本负责: 切工作目录 -> 首次配置自愈 -> 跑游戏(日志重定向) -> 收尾
#            (重启 oga_events 恢复 ES 的按键处理 -> 清屏)。

GAMEDIR="/roms/ports/sm64coopdx"
PREF="${XDG_DATA_HOME:-$HOME/.local/share}/sm64coopdx"
BIN="$GAMEDIR/sm64coopdx"
LOG="$GAMEDIR/sm64coopdx-run.log"

die() {
  printf '\n[sm64coopdx] %s\n' "$1" > /dev/tty1 2>/dev/null
  echo "[sm64coopdx] $1" >&2
  sleep 8
  exit 1
}

cd "$GAMEDIR" 2>/dev/null || die "找不到游戏目录 $GAMEDIR"
# TARGET_RPI=1 构建的上游产物名是 build/us_pc/sm64coopdx.arm，两种都认
[ -x "$BIN" ] || { BIN="$GAMEDIR/sm64coopdx.arm"; }
[ -x "$BIN" ] || die "找不到可执行文件 $GAMEDIR/sm64coopdx[.arm] (chmod +x ?)"

# --- 配置自愈: 首次运行或用户删掉配置时, 用随包默认值恢复 ---
mkdir -p "$PREF" 2>/dev/null
if [ ! -f "$PREF/sm64config.txt" ] && [ -f "$GAMEDIR/sm64config.txt.default" ]; then
  cp -f "$GAMEDIR/sm64config.txt.default" "$PREF/sm64config.txt" 2>/dev/null \
    && echo "[sm64coopdx] restored default sm64config.txt into $PREF"
fi
# gamecontrollerdb.txt 由 controller_sdl_init() 用 fs_load_file() 从"写路径"读取
if [ ! -f "$PREF/gamecontrollerdb.txt" ] && [ -f "$GAMEDIR/gamecontrollerdb.txt" ]; then
  cp -f "$GAMEDIR/gamecontrollerdb.txt" "$PREF/gamecontrollerdb.txt" 2>/dev/null
fi

# 日志: 优先写在游戏目录（方便通过 SSH / 读卡器取回）, 不行就落 /tmp
: > "$LOG" 2>/dev/null || LOG="/tmp/sm64coopdx-run.log"
{
  echo "=== $(date '+%F %T') sm64coopdx start ==="
  echo "user=$(id -un) cwd=$(pwd)"
  echo "cpu_gov=$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null)"
  echo "gpu_gov=$(cat /sys/devices/platform/ff400000.gpu/devfreq/ff400000.gpu/governor 2>/dev/null)"
  echo "SDL_VIDEODRIVER=${SDL_VIDEODRIVER:-<unset>} LD_PRELOAD=${LD_PRELOAD:-<unset>}"
  echo "config=$PREF/sm64config.txt"
} >> "$LOG" 2>&1

# 游戏自己用 KMSDRM 接管屏幕，先把 tty1 清干净，避免残留文字
printf '\033c' > /dev/tty1 2>/dev/null

"$BIN" "$@" >> "$LOG" 2>&1
RET=$?

echo "=== $(date '+%F %T') sm64coopdx exit=$RET ===" >> "$LOG" 2>&1

# --- 收尾: ArkOS 端口的标准动作 ---
# 游戏运行时 ogage(oga_events) 可能被独占/被打断，重启它才能恢复 ES 的按键与热键
sudo systemctl restart oga_events >/dev/null 2>&1
printf '\033c' > /dev/tty1 2>/dev/null
exit 0
