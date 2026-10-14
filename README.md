# CyberTown

CyberTown 是一个 Android 优先的多人 AI 赛博小镇原型。每位测试者拥有一名居民，可以为居民设置目标；居民也会在玩家离线时按照小镇时段自主行动并留下日报。

## 仓库结构

- `client/`：Godot 4.7.2、Compatibility 渲染器、640×360 像素基准画布。
- `server/`：Java 21、Spring Boot 3.5.8、SQLite、Liquibase。
- `admin/`：Fantastic-admin 6.3.0 管理后台基础工程。
- `docs/`：产品边界、架构、API 与本地开发说明。

## 当前可运行能力

- 邀请码注册、恢复码找回、访问令牌刷新。
- 随机居民背景与外观种子，居民状态查询。
- 设置每日目标并读取当日日报。
- 06:00、12:00、18:00、22:00（Asia/Shanghai）四个离线行动时段。
- DeepSeek 不可用时仍可运行的确定性规则引擎。
- Godot 原生注册、找回、居民状态、目标和日报界面。
- 全屏地图、共享居民显示、位置同步和附近聊天气泡（10 秒限频，18 秒过期）。

## 快速开始

服务端：

```powershell
.\scripts\start-local-server.ps1
```

Godot 客户端：用 Godot 4.7.2 打开 `client/project.godot`。当前本机 API 使用 `http://127.0.0.1:18080/api`，避开已占用的 8080；在 Android 真机上需改为电脑在局域网中的地址。

服务端测试：

```powershell
cd server
.\mvnw.cmd test
```

管理后台已安装在 `admin/`。业务模块将在确定 Fantastic-admin 的目标应用后接入。

更多说明见 [本地开发文档](docs/development.md) 与 [API 文档](docs/api.md)。

多人气泡手动验收见 [共享小镇测试步骤](docs/shared-town-test.md)。
