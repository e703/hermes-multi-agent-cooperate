# 部署手册：自部署方案（全新环境）

> 本文档是真实部署层的 runbook，针对**全新环境自部署**场景。
> 部署人（你）只做两件事：装 Hermes + 跑一个脚本，其余交给 CLI agent。
> 命令已在 Hermes v0.19 + Blank Slate 下验证过。
> 部署前请先读 `architecture.md`（概念映射）和 `roles/`（角色 SOUL）。

---

## 部署总览

```
全新环境（无 Hermes）
  │
  ├─ 1. 安装 Hermes → Blank Slate → 配 model
  ├─ 2. git clone 本项目
  ├─ 3. 启动 hermes chat，让 agent 跑 scripts/setup.sh
  ├─ 4. 启动 gateway
  ├─ 5. 配 IM 通知（飞书/Telegram）
  └─ 6. 跑一次端到端验证
```

你只需要做 1 和 2 和 5 中提供 IM 凭证——其余都是 agent 的活。

---

## 前置条件

- 一台 Linux 机器，能联网。
- 有 Hermes 支持的某个 model 的 API key（如 OpenAI / Anthropic / 本地模型）。
- 有飞书和/或 Telegram 的 bot 凭证（第 5 步才需要，可跳过）。

---

## 第一步 — 安装 Hermes + Blank Slate

```bash
# 安装 Hermes
git clone https://github.com/nousresearch/hermes-agent.git ~/.hermes/hermes-agent
cd ~/.hermes/hermes-agent
make install

# 初始化（选择 Blank Slate）
hermes setup
```

在 `hermes setup` 过程中：

1. 选择 **Blank Slate** — 最小化起步。
2. 配置 model provider + API key（这是必须的，agent 和 worker 都靠它）。
3. 在 Blank Slate 的 walkthrough 中，选择"Start with everything disabled"跳过工具配置。
4. Profile 名称输入 **operator**（这是入口 profile）。

> 安装完成后校验：`hermes chat "你好"` 能正常回复。

---

## 第二步 — 克隆本项目

```bash
git clone https://github.com/<你的仓库>/hermes-multi-agent-cooperate.git ~/workspace/hermes-multi-agent-cooperate
cd ~/workspace/hermes-multi-agent-cooperate
```

---

## 第三步 — 跑部署脚本（agent 执行）

启动 CLI chat，让 agent 跑部署脚本：

```bash
hermes chat
```

在 chat 中输入：

```
请阅读 ~/workspace/hermes-multi-agent-cooperate/scripts/setup.sh，
然后执行 bash scripts/setup.sh。
```

setup.sh 会做 6 件事：

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1/6 | 启用 kanban 工具集 | Blank Slate 禁用了它，需要手动打开 |
| 2/6 | 创建 operator profile | 入口 profile，gateway 绑定至此 |
| 3/6 | 创建 5 个角色 profile | architect/ingestor/researcher/writer/reviewer |
| 4/6 | 创建共享技能目录 | 把参考文档作为技能加载 |
| 5/6 | 初始化 kanban 看板 | 创建 kanban.db |
| 6/6 | 创建订单目录模板 | 确保目录结构一致 |

**脚本幂等**：可重复运行，已存在的 profile 不会重复创建，但 SOUL.md 会覆盖更新。

### 验证结果

```bash
hermes profile list
# 应看到 6 个 profile：operator + 5 角色

hermes kanban list
# 看板就绪（空）

hermes kanban assignees
# 应看到 5 角色名字 + 计数为 0
```

---

## 第四步 — 启动 gateway

gateway 承载 dispatcher（自动派发任务）和 IM 监听（接收 Human 消息）。

```bash
hermes gateway start
```

确认 gateway 在运行：

```bash
hermes gateway status
# Active: active (running)
```

> dispatcher 默认跑在 gateway 里，不需要单独 daemon。gateway 启动后就会开始轮询 kanban 看板，自动派发 ready 任务。

---

## 第五步 — 配置 IM 通知（可选，但推荐）

这一步需要你提供 IM 平台的凭证。

### 飞书（已有配置参考）

```bash
# 写入 ~/.hermes/.env
#   FEISHU_APP_ID=<app_id>
#   FEISHU_APP_SECRET=<app_secret>

# 启用插件 + 重启 gateway
hermes plugins enable feishu-platform
hermes gateway restart
```

### Telegram（当前待办）

```bash
# 1. @BotFather 创建 bot，拿到 token
# 2. 写入 ~/.hermes/.env
#    TELEGRAM_BOT_TOKEN=<token>
# 3. 配置 gateway 连接
hermes gateway setup
# 4. 重启 gateway
hermes gateway restart
# 5. 验证
hermes send --list
```

### 配置 profile 路由

Human 在飞书/Telegram 发的消息要路由到 operator profile：

```yaml
# ~/.hermes/config.yaml
gateway:
  multiplex_profiles: true
  profile_routes:
    - name: human-to-operator
      platform: feishu
      profile: operator
    - name: human-to-operator-tg
      platform: telegram
      profile: operator
```

详细说明见 `human-gateway.md`。

---

## 第六步 — 端到端验证

用最小订单跑通整条链，确保所有环节正常工作。

### 创建订单目录

```bash
ORDER="/home/$(whoami)/workspace/orders/验证-最小订单-$(date +%Y%m%d)"
mkdir -p "$ORDER"/{00_intake,01_notes,02_research,03_expertise,04_drafts,05_deliver,meta}
echo "测试用最小订单" > "$ORDER/00_intake/需求.txt"
```

### 起任务链

```bash
# T1 — 大纲
T1=$(hermes kanban create "T1 大纲：测试订单" \
  --assignee architect --workspace "dir:$ORDER" --priority 3 \
  --body "你是 architect。阅读 00_intake/，产出 04_drafts/v0_outline.md。
要求：3-5 章结构，标注每章输入来源，列出待核定参数。
红线：不编造参数。完成后用 kanban_complete 提交。" \
  --json | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")

# 派发
hermes kanban dispatch
```

### 轮询完成

```bash
for i in $(seq 1 36); do
  S=$(hermes kanban show "$T1" | grep "status:" | awk '{print $2}')
  [ "$S" = "done" ] && echo "T1 完成" && break
  sleep 5
done
```

### 完整验收清单

- [ ] 6 个 profile 都在（`hermes profile list`）
- [ ] kanban 看板就绪（`hermes kanban list`）
- [ ] gateway 运行中（`hermes gateway status`）
- [ ] T1 大纲产出在 `04_drafts/v0_outline.md`
- [ ] dispatcher 自动 promote 子任务
- [ ] 飞书/Telegram 可收发消息（如配置了）

---

## 常见问题

| 症状 | 原因 | 解决 |
|------|------|------|
| 任务一直 `ready` 不动 | gateway 没跑 | `hermes gateway start` |
| `hermes tools enable kanban` 报错 | 语法不对或已启用 | `hermes tools enable --help` 查看 |
| `dispatch` 显示 `Spawned: 0` | 没有 ready 任务 | 查前置任务状态 |
| 任务 `running` 很久 | 联网检索任务 | 设 `--max-runtime`，看 `kanban log` |
| `Profile not found` | 拼写错或没建 | `hermes kanban assignees` 看有效 profile |
| gateway 启动失败 | 飞书/Telegram 凭证格式不对 | 检查 `.env` 格式 |

---

## 角色演进（不要一上来开五个）

低单量时 2 个 profile（operator + architect 自带轻审）即可；瓶颈出现再拆出 ingestor / researcher / reviewer。**不要在单订单路径跑通前就开五个 profile。** setup.sh 默认全开，但你可以先在 operator 的 SOUL.md 中注释掉不需要的角色。

## 监控命令速查

```bash
hermes kanban watch          # 实时事件流
hermes kanban list           # 看板总览
hermes kanban show <id>      # 任务详情 + comment + 事件
hermes kanban tail <id>      # 单任务事件流
hermes kanban log <id>       # worker 输出日志
hermes kanban runs <id>      # 尝试历史
hermes kanban assignees      # 有效 profile 列表
```

## 常见问题

### 切换 profile 后工具不可用

不同 profile 的 `disabled_toolsets` 配置独立。如果某个 profile 缺少工具：

```bash
hermes tools enable kanban
```

或检查 `~/.hermes/profiles/<profile>/config.yaml` 中的 `disabled_toolsets`。

### 重新部署

如果部署出错，清理后重来：

```bash
for p in architect ingestor researcher writer reviewer; do
  rm -rf ~/.hermes/profiles/$p
done
rm -f ~/.hermes/kanban.db
# 重新跑 setup.sh
```