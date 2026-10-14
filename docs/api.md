# HTTP API

基础路径为 `/api`，不带版本后缀。除认证和健康检查外，请求使用 `Authorization: Bearer <accessToken>`。

## 公开接口

### `GET /api/health`

返回应用状态与小镇时区。

### `POST /api/auth/register`

```json
{
  "inviteCode": "local-invite",
  "username": "player_01",
  "displayName": "小柚",
  "privacyAccepted": true
}
```

成功时返回账号、居民、一次性恢复码、访问令牌与刷新令牌。恢复码只在注册响应中展示，客户端必须提醒玩家保存。

### `POST /api/auth/recover`

```json
{"username":"player_01","recoveryCode":"XXXX-XXXX-XXXX"}
```

### `POST /api/auth/refresh`

```json
{"refreshToken":"..."}
```

刷新令牌旋转使用，旧令牌在成功刷新后失效。

## 需要登录

### `GET /api/me/resident`

返回当前账号对应的居民状态。

### `POST /api/goals`

```json
{
  "instruction": "今天多认识两位邻居",
  "constraints": ["不要工作到太晚", "能量低于 30 就休息"]
}
```

每日保留一份当前目标，重复提交会替换当天目标。指令最多 500 字，限制最多两条。

### `GET /api/reports/today`

返回当前小镇日的目标和已经完成的时段行动。

### `GET /api/town/snapshot`

返回共享小镇的 `residents`、当前账号附近的 `bubbles`、`serverTime`、`townDate`、`townTime`、`timeOfDay` 和自己的完整 `resident` 状态。时间由服务端按 Asia/Shanghai 计算。居民条目仅含 `id`、`displayName`、`appearanceSeed`、`posX`、`posY`、`current`，不暴露账号、令牌或恢复码。

所有客户端采用 640×360 地图坐标。气泡可见距离为发送居民与查看居民当前坐标间的 190 地图单位，按服务端距离过滤；禁封居民不出现在快照中。客户端每 3 秒同步一次。

### `POST /api/town/presence`

```json
{"x":120,"y":180}
```

只更新登录账号自己的居民，不接收客户端指定居民 ID。`x`、`y` 必须为有限数值，范围分别为 0–640 与 0–360；可移动区域收紧为 x 8–632、y 70–330。客户端上报移动中的实际坐标，服务端持久化并在快照中分发。当前原型尚未做建筑碰撞、移动速度校验和寻路。

### `POST /api/town/bubbles`

```json
{"message":"你好，邻居！"}
```

气泡最多 60 个字符，18 秒后过期，每位居民发送间隔至少 10 秒。发送成功返回 HTTP 201；频率限制返回 429；禁言账号发送返回 403，但仍能读取快照和移动。限制记录存于数据库，重启服务不会清除发送间隔。未登录或访问令牌过期返回 401，客户端会使用刷新令牌续期并重试一次。

开发环境的 OpenAPI JSON 位于 `/api/openapi`，Swagger UI 位于 `/api/docs`。
