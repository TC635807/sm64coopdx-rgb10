# 移植问题与修复记录

目标：sm64coopdx **v1.5.1** → Powkiddy RGB10 / ArkOS 2.0（RK3326 · aarch64 · Mali-G31 · glibc 2.30）。
记录 4 个真问题：现象、证据、根因、修复、验证。对应补丁在 [`patches/`](../patches/)。

| 补丁 | 内容 |
|---|---|
| [`0001-gles2-glsl-es-100-strictness.patch`](../patches/0001-gles2-glsl-es-100-strictness.patch) | Mali 的 GLSL ES 1.00 严格类型检查 |
| [`0002-coopnet-stdcxx-compat.patch`](../patches/0002-coopnet-stdcxx-compat.patch) | 预编译 libcoopnet 对 GCC11 符号的依赖 |
| [`0003-rgb10-controller-mapping.patch`](../patches/0003-rgb10-controller-mapping.patch) | RGB10 单摇杆手柄的按键合成 |

---

## 问题 1：设备端原生编译必然 OOM（放弃该路线）

- **现象**：设备上 `make -j1` 编译到 `bin/custom_font.c` 时 `cc1` 单进程 RSS 791 MB，报 `virtual memory exhausted`；
  `bin/custom_textures.c` 及自定义字体的 `.inc.c` 单文件达 10–40 MB。
- **环境**：893 MB 可用内存、无 swap、SD 卡存储。
- **结论**：原生编译不可行，改为 PC 交叉编译，设备只负责运行。工具链见 [`CROSS-BUILD.md`](CROSS-BUILD.md)。

## 问题 2：交叉产物启动即 SIGSEGV（C++ 静态构造未执行）

- **现象**：游戏启动、处理完 dynos / mods 后，在 `level_reset_globals() → dynos_smlua_clear_gfx_command_cache()` 崩溃。
- **证据链**：
  1. gdb-multiarch 加载未 strip 二进制 + core dump，backtrace 显示 `free()` 循环里 `sGfxCommandCache` 迭代器为野指针；
  2. core 中 `sGfxCommandCache` 全 0（`_M_node_count = 0`）——C++ 静态构造函数没有运行；
  3. 最小复现：交叉编译一个带全局 `std::map` 构造的程序，设备上输出 `map_size=0`（应为 1）。
- **根因**：交叉链接时 `crt1.o` / `Scrt1.o` 来自交叉工具链自带的新版 glibc（2.4x），而运行库是设备的 glibc 2.30。
  glibc 2.34+ 的 `crt1.o` 不再向 `__libc_start_main` 传 init 指针 → 旧 libc 不执行 `.init_array` → **所有 C++ 全局构造被跳过**。
- **修复**：给交叉 gcc / g++ wrapper 加 `-B<sysroot>/usr/lib/aarch64-linux-gnu/`，强制使用设备 glibc 2.30 的 crt 文件。
- **验证**：最小测试输出 `map_size=1`，游戏越过崩溃点进入主菜单。
- **经验**：交叉编译时 crt 与 libc 必须来自目标 rootfs；只加 `--sysroot` 不够，crt 搜索路径仍可能命中交叉包。

## 问题 3：Mali 的 GLSL ES 1.00 严格性导致 shader 编译失败

- **现象**：`Fragment shader compilation failed / 0:94: S0001: Type mismatch in arithmetic operation between float and int`，随后 `FATAL ERROR`。
- **定位**：在 `gfx_opengl.c` 的失败分支临时打印完整 fragment shader，确认第 94 行是 `(uShaderFlagValues[4] - 2)`（float 减 int），
  第 101 行是 `texel.rgb * levels`（vec3 乘 int）。GLSL ES 1.00 与 Mali 编译器不允许 int/float 隐式转换。
- **修复**（`src/pc/gfx/gfx_opengl.c` 两处）：
  - `(uShaderFlagValues[4] - 2)` → `(uShaderFlagValues[4] - 2.0)`
  - `int levels = int(max(1.0, uShaderFlagValues[6]));` → `float levels = max(1.0, uShaderFlagValues[6]);`
- **验证**：shader 编译通过，正常进入主菜单（见 [`img/device-menu.jpg`](img/device-menu.jpg)）。
- **经验**：GLES2 移植要按 GLSL ES 1.00 严格模式检查所有 int / float 混用，桌面 GL 驱动通常会放行。

## 问题 4：单摇杆手柄的 C 摇杆映射（需求，非 bug）

- **需求**：RGB10 只有一组 ABXY + 单摇杆。希望「方向键 = 移动角色；按住 L1 + A/B/X/Y = C 摇杆（相机），且按住 L1 时 ABXY 原动作被覆盖」。
- **限制**：sm64coopdx 的绑定系统每个动作只有 3 个并列槽位（键盘 / 手柄按钮 / 轴），**没有修饰键 / 组合键概念**，纯配置无解。
- **修复**（`src/pc/controller/controller_sdl.c` 的 `controller_sdl_read()` 末尾，约 25 行）：
  - 把 `U_JPAD / D_JPAD / L_JPAD / R_JPAD` 从 `pad->button` 剔除；左摇杆居中时把 D-pad 方向写入 `pad->stick_x/y`
    （方向键 = 移动，且不会同时转相机）；
  - 当 `L_TRIG` 按住时：屏蔽 `A/B/X/Y` 位，按 X → `U_CBUTTONS`、Y → `L_CBUTTONS`、A → `R_CBUTTONS`、B → `D_CBUTTONS` 合成 C 摇杆输入。
- **配置配合**（`config/sm64config.txt`）：
  - `key_cup / cdown / cleft / cright` 的手柄列设为 `ffff`（改由补丁合成）；
  - `key_x / key_y` 补上手柄按钮 `0x1002 / 0x1003`；
  - `key_dup / ddown / dleft / dright` 绑 D-pad 按钮 `0x100b–0x100e`。
- **遗留**：`key_z` 同时绑了 X 键（`0x1002`）与 R2 轴（`0x101b`），按住 L1+X 时可能同时触发 Z；介意可删掉 X 列。

---

## 其他已解决的兼容点

详见 [`CROSS-BUILD.md`](CROSS-BUILD.md)：

| 问题 | 修复 |
|---|---|
| eoan SDL2 2.0.10 头缺 `preciseX / preciseY` | 换 SDL2 2.30.0 头（与设备运行库同代） |
| `gcc -E` 处理 `.mk` 失败 → `level_headers.h` 为空 | cpp wrapper 改用真正的 `cpp-12` |
| g++12 自带 libstdc++12 头与 glibc 2.30 混用 | `-nostdinc++` + sysroot 的 libstdc++-9 头，链接设备 libstdc++ 6.0.28 |
| 预编译 `libcoopnet-arm64.a` 引用 GCC11 新符号 `std::__throw_bad_array_new_length()` | 新增 `data/coopnet_stdcxx_shim.cpp`（补丁 0002） |
| glibc 2.30 的 `shm_open` 在 librt（2.34+ 才并入 libc） | 链接参数补 `-lrt` |
| 设备时钟与源码 mtime 不一致导致 make 反复重建 | `find ... -exec touch -h {} +` |

## 最终验证

- 实机主菜单：英文界面，FPS 52（`frame_limit 60` + vsync）—— [`img/device-menu.jpg`](img/device-menu.jpg)
- 实机城堡外景 —— [`img/device-castle.jpg`](img/device-castle.jpg)
- 实机关卡内（Bob-omb Battlefield）—— [`img/device-gameplay.jpg`](img/device-gameplay.jpg)
- 启动日志无崩溃、无 shader 错误；`gamecontrollerdb.txt` 加载 247 条手柄映射。
