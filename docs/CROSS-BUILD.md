# 交叉构建（x86-64 PC → RGB10 aarch64）

为什么不在设备上编译：见 [`PORTING-FIXES.md` 问题 1](PORTING-FIXES.md)。结论是设备 893 MB 内存 + 无 swap 无法编译单文件 10–40 MB 的生成代码，
所以用 PC 交叉编译，设备只运行。

## 工具链总览

| 组成 | 位置（本机示例） | 说明 |
|---|---|---|
| 交叉编译器 | `gcc-12-aarch64-linux-gnu` / `g++-12-aarch64-linux-gnu` | Ubuntu 源安装 |
| sysroot | `~/rgb10-sysroot`（约 3.1 GB） | 头文件 + 目标运行库 |
| wrapper | `~/rgb10-cross/bin/aarch64-linux-gnu-{gcc,g++,cpp,sdl2-config}` | 自动带 `--sysroot` / `-I` / `-L`，并修正 crt 路径 |
| 源码树 | `~/sm64coopdx-build` | upstream v1.5.1 + 3 个补丁 + `baserom.us.z64` |

### sysroot 怎么来

1. **头文件（eoan 19.10 arm64 开发包）**：包地址与校验在 [`toolchain/eoan-arm64-dev.list`](../toolchain/eoan-arm64-dev.list)、
   [`toolchain/debs.sha256`](../toolchain/debs.sha256)。
   ```bash
   mkdir -p ~/rgb10-sysroot/debs && cd ~/rgb10-sysroot/debs
   grep -v '^#' ../../path/to/eoan-arm64-dev.list | while read name url sha; do
     curl -LO "$url"; echo "$sha  $(basename "$url")" | md5sum -c -
   done
   for d in *.deb; do dpkg -x "$d" ~/rgb10-sysroot; done
   ```
2. **SDL2 2.30 头文件**：eoan 自带的 SDL2 2.0.10 头缺 `preciseX / preciseY`（`gfx_sdl.c:262` 编译失败），
   换成与设备运行库同代的 SDL2 **2.30.0** 头（noble `libsdl2-dev` 解包 + 设备上的 `_real_SDL_config.h`）。
3. **运行库**：从设备同步真实运行库（不是交叉包的库）：
   ```bash
   rsync -aL ark@<设备IP>:/usr/lib/aarch64-linux-gnu/ ~/rgb10-sysroot/usr/lib/aarch64-linux-gnu/
   rsync -aL ark@<设备IP>:/usr/local/lib/aarch64-linux-gnu/ ~/rgb10-sysroot/usr/local/lib/aarch64-linux-gnu/
   ```
   关键库：glibc 2.30、libstdc++ 6.0.28、SDL2 2.30.10、libMali、libcurl、zlib。

### wrapper 的作用

`~/rgb10-cross/bin/aarch64-linux-gnu-gcc` / `g++` 大致等价于：

```bash
exec /usr/bin/aarch64-linux-gnu-g++-12 \
  --sysroot=$HOME/rgb10-sysroot \
  -B$HOME/rgb10-sysroot/usr/lib/aarch64-linux-gnu \
  -I$HOME/rgb10-sysroot/usr/include \
  -L$HOME/rgb10-sysroot/usr/lib/aarch64-linux-gnu \
  -nostdinc++ -isystem $HOME/rgb10-sysroot/usr/include/c++/9 \
  -isystem $HOME/rgb10-sysroot/usr/include/aarch64-linux-gnu/c++/9 \
  "$@"
```

- `-B<sysroot>/usr/lib/aarch64-linux-gnu`：**必须**。强制使用设备 glibc 2.30 的 `crt1.o / Scrt1.o`，
  否则 C++ 静态构造不执行（见 [`PORTING-FIXES.md` 问题 2](PORTING-FIXES.md)）。
- `-nostdinc++` + libstdc++-9 头：避免 g++12 的新头文件与 glibc 2.30 混用。
- `aarch64-linux-gnu-cpp` wrapper 指向真正的 `cpp-12`：`gcc -E` 会把 `.mk` 当链接输入，导致 `level_headers.h` 为空。
- `aarch64-linux-gnu-sdl2-config` 的 `--libs` 输出 `-lSDL2 -lrt`：glibc 2.30 的 `shm_open` 还在 librt。

## 构建

```bash
export PATH="$HOME/rgb10-cross/bin:$PATH"
cd ~/sm64coopdx-build          # upstream v1.5.1 + 补丁 + baserom.us.z64

# 设备时钟与源码 mtime 不一致时，先把 mtime 压平，避免 make 反复重建
find . -exec touch -h {} +

make TARGET_RPI=1 machine=aarch64 CROSS=aarch64-linux-gnu- -j$(nproc)
```

或者用脚本（等价）：

```bash
bash scripts/build-cross.sh ~/sm64coopdx-build
```

产物：`build/us_pc/sm64coopdx.arm`（`TARGET_RPI=1` 的上游命名，strip 后约 52 MB）。

## 过程中解决的 5 个兼容问题

| # | 问题 | 解决 |
|---|---|---|
| 1 | eoan SDL2 2.0.10 头缺 `preciseX / preciseY` | 换 SDL2 2.30.0 头（noble / ports 包） |
| 2 | `gcc -E` 处理 `.mk` 失败 → `level_headers.h` 0 字节 → level 声明缺失 | cpp wrapper 改用真正的 `cpp-12` |
| 3 | g++12 自带 libstdc++12 头与 glibc 2.30 混用 | `-nostdinc++` + sysroot 的 libstdc++-9 头，链接设备 libstdc++ 6.0.28 |
| 4 | 预编译 `libcoopnet-arm64.a` 引用 GCC11 新增的 `std::__throw_bad_array_new_length()` | 新增 `data/coopnet_stdcxx_shim.cpp`（补丁 0002） |
| 5 | glibc 2.30 的 `shm_open` 在 librt（2.34+ 才并入 libc） | 链接参数补 `-lrt`（通过 `sdl2-config` shim） |

## 产物兼容性校验

```bash
BIN=build/us_pc/sm64coopdx.arm
file $BIN                        # ELF 64-bit LSB, ARM aarch64
readelf -l $BIN | grep interpreter   # /lib/ld-linux-aarch64.so.1

# 需要的 GLIBC / GLIBCXX 版本上限（设备：glibc 2.30 / libstdc++ 6.0.28 = GLIBCXX 3.4.28）
objdump -T $BIN | grep -o 'GLIBC_[0-9.]*'   | sort -Vu | tail -1
objdump -T $BIN | grep -o 'GLIBCXX_[0-9.]*' | sort -Vu | tail -1
readelf -d $BIN | grep NEEDED
```

本项目产物的实测结果：

- GLIBC 符号最高 **2.29**（设备 glibc 2.30 ✓）
- GLIBCXX 符号最高 **3.4.26**（设备 libstdc++ 6.0.28 提供到 3.4.28 ✓）
- NEEDED：`libGLESv2.so` / `libSDL2-2.0.so.0` / `librt.so.1` / `libdl.so.2` / `libz.so.1` / `libcurl.so.4` /
  `libstdc++.so.6` / `libm.so.6` / `libgcc_s.so.1` / `libpthread.so.0` / `libc.so.6` —— 设备全部具备

## 打包

```bash
bash scripts/package-release.sh build/us_pc/sm64coopdx.arm --version v1.0.0
# 生成 dist/sm64coopdx-rgb10-v1.0.0.tar.gz（binary + dynos/lang/mods/palettes + 启动器 + 默认配置）
```

## 备注：哪些东西不入库

`src/`（upstream 源码 + ROM）、`toolchain/debs*`、`toolchain/sdl2-2.30/`、`artifacts/`、`dist/` 都在 `.gitignore` 里，
只保留可复现所需的**补丁、脚本与工具链元数据**。
