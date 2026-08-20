# 架构说明

```text
Godot Android client
        |
        | HTTPS /api + bearer token
        v
Spring Boot authoritative server ---- SQLite (WAL)
        |                                  |
        | constrained planning             | facts, actions, events, audits
        v                                  |
DeepSeek API <---- budget/frequency guard--+
        ^
        |
Fantastic-admin operations console
```

## 权威边界

服务端是账号、居民状态、行动结果和时间推进的唯一权威。客户端负责输入与表现，不能直接写入金币、能量、心情或事件。AI 输出必须通过 JSON 结构校验和业务规则校验后才能落库。

## 时间推进

小镇时区固定为 `Asia/Shanghai`。计划时段为 06:00、12:00、18:00、22:00，对应 `MORNING`、`AFTERNOON`、`EVENING`、`NIGHT`。同一居民、日期、时段只能生成一次行动。

## AI 降级

目标模型为 DeepSeek `deepseek-v4-flash`，请求明确发送 `thinking.type=disabled` 并启用 JSON 输出。任何无密钥、未启用 AI、超预算、超频、超时、非 JSON 或规则冲突都必须切换到服务端规则引擎，保证居民仍会行动。模型只能选择五种行动之一，数值和事实仍由服务端计算。模型调用按居民和日期记账，硬上限为每日 4 次，月度成本上限默认 200 元。

服务端引入 Spring AI Alibaba 1.1.2.2 作为后续多居民事件编排框架。当前单居民行动选择使用 Spring AI 的 OpenAI 兼容模型适配器，因为它能显式透传 DeepSeek V4 所需的 `thinking` 开关；这与 Spring AI Alibaba 官方 DeepSeek 示例采用 Spring AI 模型适配器的方式一致。

## 数据与扩展

原型使用 SQLite 与 WAL，写连接池限制为单写者。迁移由 Liquibase 管理。若测试规模超出单镇 20 人或写冲突成为瓶颈，可保持 API 与领域模型不变并迁移到 PostgreSQL。
