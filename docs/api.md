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

开发环境的 OpenAPI JSON 位于 `/api/openapi`，Swagger UI 位于 `/api/docs`。
