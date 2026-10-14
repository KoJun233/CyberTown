# 共享小镇手动测试

## 启动新版服务端

如果旧服务端还在运行，先在原服务端终端按 Ctrl+C 停止它。然后在项目根目录的 PowerShell 中执行：

```powershell
cd E:\Godot\project\CyberTown
.\scripts\start-local-server.ps1
```

脚本会构建并运行当前服务端，使用 18080 端口，关闭 AI 调用，并保留已有数据库。第一次 PC 测试数据库若存在，会继续使用 `server/target/cybertown-pc-test.db`；可用 `-DatabasePath` 显式指定其他数据库。不要删除旧数据库或运行 `mvn clean`，首次测试的账号数据可能保存在 `server/target/`。

它会创建两个一次性邀请码 `CYBER-NEIGHBOR-A`、`CYBER-NEIGHBOR-B`。已使用的邀请码不会被重新激活；若需要更多测试账号，重启时传入新名字：

```powershell
.\scripts\start-local-server.ps1 -InviteCodes 'CYBER-NEIGHBOR-C,CYBER-NEIGHBOR-D'
```

## 单窗口测试

在 Godot 中按 F5，原账号会继续登录。确认底部新增“附近说话”。输入一句话并发送，气泡应显示在自己的居民头顶，约 18 秒后消失。10 秒内再次发送，应在弹窗内显示等待提示。点击气泡所在位置，应仍能移动。

顶部应显示服务端日期/时间，而非固定 06:00；离线行动时段完成后，金币、精力、心情和居民位置会同步更新。

## 同一台电脑开两个账号

第一个窗口照常用 Godot F5 运行。另开一个 PowerShell，执行以下命令启动第二个游戏窗口；此窗口使用独立登录存档，保留第一个窗口的账号：

```powershell
Start-Process -FilePath 'E:\Godot\Godot.exe' -ArgumentList @(
    '--path', 'E:\Godot\project\CyberTown\client',
    '--', '--api-base-url=http://127.0.0.1:18080/api', '--session-name=neighbor'
)
```

第二个窗口首次注册时填写邀请码 `CYBER-NEIGHBOR-B`，另选一个用户名。已有原账号时不需要使用邀请码 A。

1. 两个窗口应能看到双方居民；自己的居民脚下有黄色圈。
2. 移动一个居民，另一个窗口应在约 3 秒后看到位置变化。
3. 将两名居民移动到中心广场附近；一个窗口发送气泡，两个窗口都应看到。
4. 将一名居民移到左侧、另一名移到右侧，确保距离超过 190 地图单位；等待位置同步后发送，远处窗口应看不到。
5. 调整窗口大小，居民之间的相对位置和气泡可见范围应保持一致。
6. 重启客户端，应恢复上次同步的位置，不需要再次输入恢复码。

如果服务暂时断开，地图上会提示同步失败；恢复服务后轮询会继续。视觉布局和实际点击体验由测试者手动验收。
