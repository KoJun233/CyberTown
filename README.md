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
- 温暖像素小镇、中文纸张面板、Sunnyside 角色待机与多方向行走动画。
- 以地图为主的居民卡和统一居民手帐，集中查看近况、编辑目标、阅读日报；目标建议、限制条件回填和未保存提醒。
- 点击地面行走、WASD / 方向键移动，以及建筑和水域避障寻路；主页面仅保留手帐、聊天与菜单入口。
- 共享居民显示、位置同步和附近聊天气泡（10 秒限频，18 秒过期）。
- 统一的注册、恢复码保存和找回界面，断网重试保留当前登录状态。

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

新版界面预览、交互说明和验证记录见 [UI 与小镇交互改版](docs/ui-redesign.md)。
