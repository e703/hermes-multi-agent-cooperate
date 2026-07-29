# 人机入口：Human 通过 Telegram / 飞书介入

> Human 不是 Profile，是唯一拥有最终决策权的人。**gateway 绑定的是 operator profile**，
> 不是"human 角色"——Human 是消息的发送方，operator 是接收方。
> 本文件说明 Human 如何通过即时通讯平台给团队下任务、看进度、在闸门节点审批。

---

## 架构关系

```
    Human（真人）
       │
       ├─ 飞书 / Telegram 发消息
       │
       ▼
    gateway（跑在 operator profile 上）
       │
       ├─ 接收消息 → 进入 operator 的 chat 会话
       ├─ dispatcher 自动派发 kanban 任务给各角色
       │
       ▼
    AI 团队（5 个角色，kanban worker）
       architect / ingestor / researcher / writer / reviewer
```

gateway 不是跑在"human 角色"上——human 没有 profile。gateway 跑在
**operator profile** 上，operator 是团队的入口，接收 Human 的消息后启动
kanban 任务链。

---

## 1. 安装 gateway

首次使用需要安装 systemd 服务：

```bash
hermes gateway install
# 回答 Y 启动服务，Y 开机自启

# SSH 环境必须启用 linger，否则退出终端后 gateway 会停
sudo loginctl enable-linger $(whoami)

# 重启使配置生效
systemctl --user restart hermes-gateway-operator.service
```

服务名称格式：`hermes-gateway-<profile名称>.service`。

---

## 2. 下任务：消息 → kanban 任务链

Human 在 Telegram / 飞书 给 operator profile 发消息描述订单需求。
gateway 监听消息，operator 收到后启动 kanban 任务链。

如果想让"发消息"自动建单，可以做一个收件脚本（cron 或 webhook），把消息解析成
`hermes kanban create` 调用。当前推荐手动：Human 发需求 → operator 在终端 `hermes kanban create` 起链。

---

## 3. 看进度：看板 + 实时流

Human 可以随时查看团队进度：

```bash
hermes kanban list          # 看板总览：各任务状态
hermes kanban watch         # 实时事件流（谁在跑、谁完成、谁 block）
hermes kanban show <id>     # 单任务详情 + comment + 事件历史
hermes kanban stats         # 按状态/负责人统计
```

如果不想盯终端，可以让关键事件推送到你的 IM。

---

## 4. 闸门审批：block → comment → unblock

任务在 G1（大纲）和 G2（终审）闸门处会 `block`（阻塞），等 Human 决策。

```bash
# 看哪个任务在等你
hermes kanban list          # 状态显示 blocked 的就是闸门

# 批注意见（比如修改大纲）
hermes kanban comment <task_id> "大纲第3章补充机房物理环境要求"

# 放行
hermes kanban unblock <task_id>
```

---

## 5. 完成通知：任务跑完推送到 IM

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

---

## 6. Telegram 配置（当前待办）

gateway 已在跑，但还没配 Telegram bot。配置步骤：

```bash
# 1. @BotFather 创建 bot，拿到 token
# 2. 写入 ~/.hermes/.env
#    TELEGRAM_BOT_TOKEN=<token>
# 3. 重启 gateway
systemctl --user restart hermes-gateway-operator.service
# 4. 验证
hermes send --list          # 应出现 telegram 目标
```

配好后，Human 在 Telegram 给 bot 发消息，operator profile 就能收到（通过 gateway 转发）。

---

## 7. 飞书配置参考（已完成，备查）

```bash
# 凭证写入 ~/.hermes/.env
#   FEISHU_APP_ID=<app_id>
#   FEISHU_APP_SECRET=<app_secret>
# 启用插件 + 重启
hermes plugins enable feishu-platform
systemctl --user restart hermes-gateway-operator.service
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

## 8. Profile 路由配置（多平台 → operator）

如果同时使用飞书和 Telegram，可以配置 profile_routes 让所有消息都路由到 operator：

```yaml
# ~/.hermes/config.yaml
gateway:
  multiplex_profiles: true
  profile_routes:
    - name: human-to-operator-feishu
      platform: feishu
      profile: operator
    - name: human-to-operator-telegram
      platform: telegram
      profile: operator
```

添加后重启 gateway：

```bash
systemctl --user restart hermes-gateway-operator.service
```

详见 `docs/profile-routing.md`。

---

## 通知 vs 工作流：分清两件事

- **工作流**（kanban 任务链）在终端里跑，有没有 IM 通知都不影响它完成。
- **通知**（IM 推送）是并行的事——让你不用盯终端就能知道进度。
- 如果 IM 没配好，**不要让 pipeline 停下来等通知**。先让流水线跑完，通知是锦上添花。

## gateway 重启方式

```bash
systemctl --user restart hermes-gateway-operator.service    # 重启
systemctl --user status hermes-gateway-operator.service     # 查看状态
```

## 可用发送目标速查

```bash
hermes send --list          # 列出所有可用 target
hermes send --list feishu   # 只看飞书
hermes send --list telegram # 只看 Telegram
```

target 格式：`平台`（发到 home channel）/ `平台:chat_id` / `平台:chat_id:thread_id`。