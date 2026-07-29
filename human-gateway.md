# 人机入口：Human 通过 Telegram / 飞书介入

> Human 不是 Profile，是唯一拥有最终决策权的人。本文件说明 Human 如何通过
> 即时通讯平台给团队下任务、看进度、在闸门节点审批。

---

## 当前环境状态

| 平台 | 状态 | 说明 |
|------|------|------|
| 飞书（Feishu） | ✅ 已连接一个会话 | `feishu:oc_faa153d662ec4ae5ddcddf1be612ac4a`，插件已启用 |
| Telegram | ⏳ 待配置 | gateway 在跑，但未配置 bot token |

> 这两个状态是 2026-07-28 查到的真实情况，部署时以 `hermes send --list` 实时输出为准。

---

## 1. 下任务：消息 → kanban 任务链

Human 在 Telegram / 飞书 给 alan profile 发消息描述订单需求。gateway 监听消息，
alan 收到后启动 kanban 任务链（见 `deployment.md` 第三步）。

如果想让"发消息"自动建单，可以做一个收件脚本（cron 或 webhook），把消息解析成
`hermes kanban create` 调用。当前推荐手动：Human 发需求 → 在终端 `hermes kanban create` 起链。

## 2. 看进度：看板 + 实时流

Human 可以随时查看团队进度：

```bash
hermes kanban list          # 看板总览：各任务状态
hermes kanban watch         # 实时事件流（谁在跑、谁完成、谁 block）
hermes kanban show <id>     # 单任务详情 + comment + 事件历史
hermes kanban stats         # 按状态/负责人统计
```

如果不想盯终端，可以让关键事件推送到你的 IM。

## 3. 闸门审批：block → comment → unblock

任务在 G1（大纲）和 G2（终审）闸门处会 `block`（阻塞），等 Human 决策。

```bash
# 看哪个任务在等你
hermes kanban list          # 状态显示 blocked 的就是闸门

# 批注意见（比如修改大纲）
hermes kanban comment <task_id> "大纲第3章补充机房物理环境要求"

# 放行
hermes kanban unblock <task_id>
```

## 4. 完成通知：任务跑完推送到 IM

两种方式：

### 方式 A：主动推送（推荐，最直接）

任务完成后，用 `hermes send` 把结果推到你的 IM：

```bash
# 推到飞书（已配置的会话）
hermes send -t feishu:oc_faa153d662ec4ae5ddcddf1be612ac4a \
  "✅ T3 证据包已完成，🟢5 🟡2 🔴0，路径：$ORDER/02_research/证据包.md"

# 推到 Telegram（配置后）
hermes send -t telegram:-1003300933525 "T5 审校通过，等终审"
```

### 方式 B：订阅任务事件（自动 ping）

订阅单个任务的终结事件，completed/gave_up/timed_out 时自动 ping：

```bash
# 订阅到飞书
hermes kanban notify-subscribe <task_id> --platform feishu \
  --chat-id oc_faa153d662ec4ae5ddcddf1be612ac4a

# 订阅到 Telegram（配置后）
hermes kanban notify-subscribe <task_id> --platform telegram \
  --chat-id -1003300933525
```

查订阅：`hermes kanban notify-list`；取消：`hermes kanban notify-unsubscribe <task_id> --platform ...`。

## 5. Telegram 配置（当前待办）

gateway 已在跑，但还没配 Telegram bot。配置步骤：

```bash
# 1. @BotFather 创建 bot，拿到 token
# 2. 写入 .env
#    TELEGRAM_BOT_TOKEN=<token>
# 3. 配置 gateway 连接
hermes gateway setup        # 交互式选 Telegram，填 token
# 4. 重启 gateway
hermes gateway restart
# 5. 验证
hermes send --list          # 应出现 telegram 目标
```

配好后，Human 在 Telegram 给 bot 发消息，alan profile 就能收到。

## 6. 飞书配置参考（已完成，备查）

```bash
# 凭证写入 ~/.hermes/.env
#   FEISHU_APP_ID=<app_id>
#   FEISHU_APP_SECRET=<app_secret>
# 启用插件 + 重启
hermes plugins enable feishu-platform
hermes gateway restart
# 发消息
hermes send -t feishu:<chat_id> "消息内容"
```

### 飞书环境变量参考

| 变量 | 必需 | 用途 |
|------|------|------|
| `FEISHU_APP_ID` | 是 | 应用身份 |
| `FEISHU_APP_SECRET` | 是 | 应用密钥 |
| `FEISHU_VERIFICATION_TOKEN` | webhook 模式才需 | 请求鉴权 |
| `FEISHU_ENCRYPT_KEY` | webhook 模式才需 | 载荷加密 |
| `FEISHU_CONNECTION_MODE` | 否（默认 websocket） | `websocket` 或 `webhook` |
| `FEISHU_ALLOWED_USERS` | 否 | 白名单 |
| `FEISHU_GROUP_POLICY` | 否（默认 allowlist） | `allowlist` 或 `allow_all` |

---

## 通知 vs 工作流：分清两件事

- **工作流**（kanban 任务链）在终端里跑，有没有 IM 通知都不影响它完成。
- **通知**（IM 推送）是并行的事——让你不用盯终端就能知道进度。
- 如果 IM 没配好，**不要让 pipeline 停下来等通知**。先让流水线跑完，通知是锦上添花。

## 可用发送目标速查

```bash
hermes send --list          # 列出所有可用 target
hermes send --list feishu   # 只看飞书
hermes send --list telegram # 只看 Telegram
```

target 格式：`平台`（发到 home channel）/ `平台:chat_id` / `平台:chat_id:thread_id`。
