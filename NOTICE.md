# NOTICE

## 上游项目

本仓库是 [coop-deluxe/sm64coopdx](https://github.com/coop-deluxe/sm64coopdx) 在 Powkiddy RGB10 / ArkOS 上的移植与打包工程，
基于上游 **v1.5.1** 源码。所有游戏逻辑、渲染、联机代码版权归上游作者与贡献者所有；本仓库仅包含以补丁形式记录的移植改动、
构建/部署脚本、配置文件、文档，以及作者自己拍摄的实机照片。

上游仓库当前没有附带 LICENSE 文件。本仓库不对上游代码重新授权，也不改变上游的授权状态。

## ROM 与游戏素材

本项目**不提供** Super Mario 64 的 ROM，也不提供从 ROM 提取的游戏素材（贴图、模型、音乐、音效）。

- 构建与运行需要你自己合法拥有的 Super Mario 64 US 版卡带 dump（`baserom.us.z64`）。
- 二进制在构建过程中会把 ROM 素材编译进去，因此 Release 预编译包**只适合已经拥有正版 ROM 的用户**做本机测试 / 研究使用；
  请勿将其用于任何商业用途或公开再分发。
- Super Mario 64 及相关角色、素材的版权归 Nintendo 所有。本项目与 Nintendo 无任何关联，也未获其授权或认可。

如果版权方认为本仓库中的任何内容不当，请通过 Issue 联系，我们会立即处理。

## 第三方组件

| 组件 | 用途 | 来源 |
|---|---|---|
| sm64coopdx v1.5.1 | 上游游戏 / 联机框架 | https://github.com/coop-deluxe/sm64coopdx |
| libcoopnet（预编译 `libcoopnet-arm64.a`） | CoopNet 联机传输层 | 上游 `lib/coopnet/` |
| SDL2 2.30 | 窗口 / 输入 / KMSDRM 后端 | https://github.com/libsdl-org/SDL |
| libMali（设备自带） | OpenGL ES 2.0 驱动 | ArkOS 系统镜像 |
| ArkOS 2.0 | 设备系统与 Ports 启动机制 | https://github.com/christianhaitian/arkos |
| gamecontrollerdb.txt | 手柄映射数据库 | https://github.com/mdqinc/SDL_GameControllerDB |

## 免责声明

本工程按「现状」提供，不附带任何明示或暗示的担保。因使用本工程导致的设备损坏、数据丢失或账号问题，作者不承担责任。
刷机、改机有风险，请自行评估并做好备份。
