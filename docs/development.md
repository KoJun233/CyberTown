# 本地开发

## 已固定版本

- Godot 4.7.2 stable，Compatibility 渲染器。
- Oracle JDK 21。
- Spring Boot 3.5.8。
- Node.js 24.19.0 与 pnpm 11.19.0。
- Fantastic-admin 6.3.0 stable。
- Android Platform 35/36、Build Tools 35.0.1/36.0.0、NDK r28b、CMake 3.10.2。Godot 4.7.2 的预编译模板目标为 Android SDK 36。
- Android Studio 2026.1.3.7（Quail 3）。

## 服务端

复制 `.env.example` 中的值到当前 shell 环境，不要提交真实密钥。首次启动必须提供 `CYBERTOWN_BOOTSTRAP_INVITE_CODE`，服务端会把它哈希后写入数据库。

```powershell
cd server
$env:SERVER_PORT='18080'
$env:CYBERTOWN_BOOTSTRAP_INVITE_CODE='local-invite'
.\mvnw.cmd spring-boot:run
```

不设置 `DEEPSEEK_API_KEY` 或保持 `CYBERTOWN_AI_ENABLED=false` 时，当前原型只运行确定性模拟器，适合本地开发。需要联调 DeepSeek 时同时设置密钥并把该开关改为 `true`；模型输出仅能选择行动，不能直接修改游戏数值。

## 客户端

当前本机桌面调试使用 `127.0.0.1:18080`，避开已被其他程序占用的 8080。Android 真机无法用 `127.0.0.1` 访问电脑，需要把 `cybertown/api_base_url` 改为同一局域网内电脑的 IPv4 地址，并允许 Windows 防火墙对应端口的入站连接。

```powershell
& 'E:\Godot\Godot.exe' --headless --path client --editor --quit
& 'E:\Godot\Godot.exe' --headless --path client --quit-after 2
```

本地端口被占用时，可以只为本次运行覆盖 API 地址：

```powershell
& 'E:\Godot\Godot.exe' --path client -- --api-base-url=http://127.0.0.1:18080/api
```

## 管理后台

```powershell
cd admin
pnpm install --frozen-lockfile
pnpm dev
```

后台采用多应用 monorepo。CyberTown 业务模块只会落到选定的一个 `admin/apps/<app>` 中，不会修改框架内建组件。

## Git

远端 `origin` 指向 `https://github.com/KoJun233/CyberTown.git`。本地可以提交里程碑，但推送远端前需要再次明确确认。真实密钥、SQLite 数据库、构建产物和依赖目录均已忽略。
