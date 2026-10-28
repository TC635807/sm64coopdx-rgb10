# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 风格，版本号遵循 [SemVer](https://semver.org/lang/zh-CN/)。

## [v1.0.1] - 2026-10-28

修复「玩起来就退不出去」的问题。

### Added

- **退出热键**：任意界面长按 `Select` + `Start` 1.5 秒 → 干净退出回 EmulationStation（`game_exit()`，正常保存配置）。
- `patches/0004-rgb10-quit-hotkey-and-menu-layout.patch`。

### Fixed

- 主菜单 `Quit` 按钮在 480×320 屏幕上被裁掉（logo + 4 个按钮放不下），导致只能断电重启。
  现在释放空 header、缩小 logo，`Host` / `Join` / `Options` / `Quit` 四项全部可见可点。

### Changed

- 退出逻辑由输入回调改为「置标志 + 主循环消费」，避免在 SDL 输入回调里直接拆掉 SDL/GFX。

## [v1.0.0] - 2026-10-27

首个可运行版本：sm64coopdx v1.5.1 在 Powkiddy RGB10（ArkOS 2.0）上完成 aarch64 + GLES2 移植。

### Added

- 交叉编译产物 `sm64coopdx.arm`（aarch64 ELF，GLIBC ≤ 2.29 / GLIBCXX ≤ 3.4.26），可运行于 RK3326 + Mali-G31。
- ArkOS Ports 启动器 `sm64coopdx.sh`：切换工作目录、首次配置自愈、日志落盘、退出后重启 `oga_events` 恢复 ES 按键。
- 一键部署脚本 `deploy.sh`：解包、归位、修 exFAT 权限、归一化 mtime、装启动器 / 配置 / ROM、自检。
- 默认手柄配置：D-pad 移动、L1 + X/Y/A/B = C 摇杆上/左/右/下，L1 按下时屏蔽 ABXY 原动作。
- 3 个可复现补丁：GLSL ES 严格性、CoopNet libstdc++ 兼容 shim、RGB10 手柄映射。
- Release 用的 Ports 目录包（含 binary、dynos、lang、mods、palettes）。

### Fixed

- 设备端原生编译 OOM（`virtual memory exhausted`）→ 改为 PC 交叉编译。
- 交叉产物启动即 SIGSEGV：交叉工具链 crt1.o 与设备 glibc 2.30 不匹配导致 C++ 静态构造未执行 → 强制使用设备 crt。
- Mali 上 fragment shader 编译失败（GLSL ES 1.00 不允许 int/float 隐式转换）。
- D-pad 在游戏内不识别、无法转动视角 → SDL 层按键合成补丁。

### Known issues

- 仅验证 US 版 ROM；联机未在设备上实测（验证环境无公网出口）。
- 菜单无中文；大型 mod / 高模 dynos 可能因内存不足失败。
- `key_z` 同时绑定 X 键与 R2 轴，L1+X 时可能误触 Z（可手工改配置）。
