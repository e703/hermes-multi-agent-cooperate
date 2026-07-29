# 部署手册：自部署方案（全新环境）

> 本文档是真实部署层的 runbook，针对**全新环境自部署**场景。
> 部署人（你）只做两件事：装 Hermes + 跑一个脚本，其余交给 CLI agent。
> 命令已在 Hermes v0.19 + Blank Slate + deepseek-v4-flash 下实测验证过。
> 部署前请先读 `architecture.md`（概念映射）和 `roles/`（角色 SOUL）。

---

## 部署总览

```
全新环境（无 Hermes）
  │
  ├─ 1. 安装 Hermes → Blank Slate → 配 model
  ├─ 2. 确认当前 profile → 创建 operator（如不是）→ 切换
  ├─ 3. git clone 本项目
  ├─ 4. 跑 scripts/setup.sh
  ├─ 5. 安装并启动 gateway
  ├─ 6. 配 IM 通知（飞书/Telegram，可选）
  └─ 7. 跑一次端到端验证
```

你只需要做 1 和 2 和 6 中提供 IM 凭证——其余都是脚本的活。

---

## 前置条件

- 一台 Linux 机器，能联网。
- 有 sudo 权限（用于 `loginctl enable-linger`，gateway 保持后台运行）。
- 有 Hermes 支持的某个 model 的 API key（如 OpenAI / Anthropic / 本地模型）。
- 有飞书和/或 Telegram 的 bot 凭证（第 6 步才需要，可跳过）。

---

## 第一步 — 安装 Hermes + Blank Slate

```bash
# 安装依赖
sudo apt update 

# 安装 Hermes
 curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh |bash

# 初始化（选择 Blank Slate）
hermes setup
```

在 `hermes setup` 过程中：

1. 选择 **Blank Slate** — 最小化起步。
2. Step 1 — Provider & Model：配置 model provider + API key（**必须的**，agent 和 worker 都靠它）。
3. Step 2 — Terminal Backend：选 `local`（默认）。
4. 遇到 "How far do you want to go?"：选 `Start with everything disabled — finish now`。

> ⚠️ 注意：Blank Slate 不会提示你输入 profile 名称，默认创建 `default`。第 2 步我们会手动创建 `operator`。

> 安装完成后校验：`hermes chat "你好"` 能正常回复。

---

## 第二步 — 创建 operator profile 并切换

Blank Slate 默认创建的是 `default` profile，我们需要创建 `operator` 作为入口并切换过去：

```bash
# 创建 operator profile（从 default 克隆）
hermes profile create operator --clone --no-alias \
  --description "团队入口：接收 Human 订单、启动 kanban 任务链、监控进度；不亲自做研究/写作/审校。"

# 切换到 operator
hermes profile use operator

# 验证 ◆ 在 operator 上
hermes profile list
```

预期输出中 `◆` 标记应在 `operator` 这一行：

```
 Profile          Model                        Gateway
 ───────────────    ───────────────────────────    ───────────
  default         deepseek-v4-flash            stopped
 ◆operator        deepseek-v4-flash            stopped
```

---

## 第三步 — 克隆本项目

```bash
git clone https://github.com/<你的仓库>/hermes-multi-agent-cooperate.git ~/workspace/hermes-multi-agent-cooperate
cd ~/workspace/hermes-multi-agent-cooperate
```

---

## 第四步 — 跑部署脚本

直接跑，不需要进 hermes chat：

```bash
bash scripts/setup.sh
```

setup.sh 会做 5 件事：

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1/5 | 验证 kanban 可用 | kanban 是 Hermes 内置功能，非工具集 |
| 2/5 | 创建 operator SOUL.md | 写入入口 profile 的灵魂文件 |
| 3/5 | 创建 5 个角色 profile | architect/ingestor/researcher/writer/reviewer |
| 4/5 | 创建共享技能目录 | 把参考文档作为技能加载 |
| 5/5 | 初始化 kanban 看板 | 创建 kanban.db |

**脚本幂等**：可重复运行，已存在的 profile 不会重复创建，但 SOUL.md 会覆盖更新。

### 验证结果

```bash
hermes profile list
# 应看到 7 个 profile：default + operator + 5 角色

hermes kanban list
# 看板就绪（空）

hermes kanban assignees
# 应看到 5 角色名字 + 计数为 0
```

---

## 第五步 — 安装并启动 gateway

gateway 承载 dispatcher（自动派发任务）和 IM 监听（接收 Human 消息）。

```bash
# 安装 gateway 系统服务
hermes gateway install
# 回答 Y 启动服务，Y 开机自启

# 确认 linger 已启用（SSH 环境必须，否则退出终端后 gateway 会停）
sudo loginctl enable-linger $(whoami)

# 重启 gateway 使配置生效
systemctl --user restart hermes-gateway-operator.service

# 确认 gateway 在运行
hermes gateway status
# Active: active (running)
```

> ⚠️ 如果 `hermes gateway install` 时 linger 启用失败，手动执行 `sudo loginctl enable-linger <用户名>`。

> dispatcher 默认跑在 gateway 里，不需要单独 daemon。gateway 启动后就会开始轮询 kanban 看板，自动派发 ready 任务。

---

## 第六步 — 配置 IM 通知（可选，但推荐）

这一步需要你提供 IM 平台的凭证。

### 飞书

```bash
# 写入 ~/.hermes/.env
#   FEISHU_APP_ID=<app_id>
#   FEISHU_APP_SECRET=<app_secret>

# 启用插件 + 重启 gateway
hermes plugins enable feishu-platform
systemctl --user restart hermes-gateway-operator.service
```

### Telegram

```bash
# 1. @BotFather 创建 bot，拿到 token
# 2. 写入 ~/.hermes/.env
#    TELEGRAM_BOT_TOKEN=<token>
# 3. 重启 gateway
systemctl --user restart hermes-gateway-operator.service
# 4. 验证
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

添加后重启 gateway：`systemctl --user restart hermes-gateway-operator.service`

详细说明见 `human-gateway.md`。

---

## 第七步 — 端到端验证

用最小订单跑通整条链，确保所有环节正常工作。

### 创建订单目录

```bash
ORDER="$HOME/workspace/orders/验证-最小订单-$(date +%Y%m%d)"
mkdir -p "$ORDER"/{00_intake,01_notes,02_research,03_expertise,04_drafts,05_deliver,meta}
echo "测试用最小订单，验证五角色协作流水线" > "$ORDER/00_intake/需求.txt"
```

### T1 — 大纲

```bash
T1=$(hermes kanban create "T1 大纲：验证订单" \
  --assignee architect --workspace "dir:$ORDER" --priority 3 \
  --body "你是 architect。阅读 00_intake/需求.txt，产出 04_drafts/v0_outline.md。
要求：3-5 章结构，标注每章输入来源，列出待核定参数。
红线：不编造参数。完成后用 kanban_complete 提交，summary 写大纲路径。" \
  --json | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")

hermes kanban dispatch
```

### 轮询 T1 完成

```bash
for i in $(seq 1 36); do
  S=$(hermes kanban show "$T1" | grep "status:" | awk '{print $2}')
  echo "T1: $S"
  [ "$S" = "done" ] && echo "✅ T1 完成" && break
  sleep 5
done
```

### T2 ∥ T3 — 并行子任务

```bash
T2=$(hermes kanban create "T2 资料包" --assignee ingestor \
  --parent "$T1" --workspace "dir:$ORDER" \
  --body "你是 ingestor。读 00_intake/，产出 01_notes/资料包.md。
提取事实与硬约束，原件没有的参数用[待现场核定]占位。
完成后 kanban_complete。" --json | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")

T3=$(hermes kanban create "T3 证据包" --assignee researcher \
  --parent "$T1" --workspace "dir:$ORDER" --max-runtime 30m \
  --body "你是 researcher。按大纲章节联网检索，产出 02_research/证据包.md。
每条数据标注置信度(🟢🟡🔴)，末尾附置信度汇总表。完成后 kanban_complete。" \
  --json | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")

hermes kanban dispatch
```

### 轮询 T2+T3

```bash
echo "⏳ T2 和 T3（5-6 分钟）正在跑..."
for i in $(seq 1 120); do
  S2=$(hermes kanban show "$T2" 2>/dev/null | grep "status:" | awk '{print $2}')
  S3=$(hermes kanban show "$T3" 2>/dev/null | grep "status:" | awk '{print $2}')
  echo "T2: $S2  T3: $S3"
  [ "$S2" = "done" ] && [ "$S3" = "done" ] && echo "✅ T2+T3 都完成" && break
  sleep 10
done
```

### T4 — 初稿

```bash
T4=$(hermes kanban create "T4 初稿" --assignee writer \
  --parent "$T2" --parent "$T3" --workspace "dir:$ORDER" \
  --body "你是 writer。融合 01_notes/ 和 02_research/ 产出 04_drafts/v1_draft.md。
只用🟢数据，🟡🔴禁用。完成后 kanban_complete。" \
  --json | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")
# dispatcher 自动在 T2+T3 done 后 promote T4
```

### 完整验收清单

- [ ] 7 个 profile 都在（`hermes profile list`）
- [ ] ◆ 在 operator 上
- [ ] kanban 看板就绪（`hermes kanban list`）
- [ ] gateway 运行中（`hermes gateway status` 显示 running）
- [ ] T1 大纲产出在 `04_drafts/v0_outline.md`
- [ ] T2 资料包产出在 `01_notes/资料包.md`
- [ ] T3 证据包产出在 `02_research/证据包.md`，含置信度汇总表
- [ ] T4 初稿产出在 `04_drafts/v1_draft.md`
- [ ] dispatcher 自动 promote 子任务（T4 在 T2+T3 完成后才启动）
- [ ] 飞书/Telegram 可收发消息（如配置了）

---

## 常见问题

| 症状 | 原因 | 解决 |
|------|------|------|
| 任务一直 `ready` 不动 | gateway 没跑 | `hermes gateway status`，跑 `systemctl --user restart hermes-gateway-operator.service` |
| `dispatch` 显示 `Spawned: 0` | 没有 ready 任务 | 查前置任务状态 `hermes kanban show <父任务>` |
| 任务 `running` 很久 | 联网检索任务（T3 慢） | 设 `--max-runtime`，看 `hermes kanban log <id>` |
| `Profile not found` | 拼写错或没建 | `hermes kanban assignees` 看有效 profile |
| gateway 启动失败 | 凭证格式不对或 linger 未启用 | 检查 `.env` 格式，`sudo loginctl enable-linger $(whoami)` |
| `hermes profile switch` 报错 | 命令是 `use` 不是 `switch` | `hermes profile use <name>` |
| `hermes tools enable kanban` 报错 | kanban 是内置功能，不是工具集 | 不需要手动启用，直接 `hermes kanban init` 验证 |

---

## 角色演进（不要一上来开五个）

低单量时 2 个 profile（operator + architect 自带轻审）即可；瓶颈出现再拆出 ingestor / researcher / reviewer。**不要在单订单路径跑通前就开五个 profile。** setup.sh 默认全开，但你可以在 operator 的 SOUL.md 中注释掉不需要的角色。

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

## 切换 profile

```bash
hermes profile use <name>    # 切换到指定 profile
hermes profile list          # 看 ◆ 标记确认
```

## 重新部署

如果部署出错，清理后重来：

```bash
for p in architect ingestor researcher writer reviewer; do
  rm -rf ~/.hermes/profiles/$p
done
rm -f ~/.hermes/kanban.db
# 重新跑 setup.sh
```
