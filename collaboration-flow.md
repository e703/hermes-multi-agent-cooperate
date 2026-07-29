# 协作流程：一个完整订单的端到端流转

> 以"专业文档交付"为场景，展示一个订单从需求到交付的完整流程。
> 每一步标注对应的 kanban 命令。角色：architect / ingestor / researcher / writer / reviewer。

---

## 流程总览

```
[需求 / 客户原件 / 专家补充]
        │
        ▼
   T1  architect (大纲 + 拆解 + 验收标准)
        │
  【闸门 G1：人批大纲】  ← Human 审批，block → unblock
        │
   ┌────┴────┐
   ▼         ▼
  T2         T3
ingestor    researcher
资料包       证据包(🟢🟡🔴)
   │         │
   └────┬────┘
        │  (dispatcher 自动等 T2+T3 都完成才 promote T4)
        ▼
   专家包 (Human 注入 03_expertise/)
        │
        ▼
   T4  writer (三包+模板 → v1 初稿, 内嵌溯源)
        │
        ▼
   T5  reviewer 阶段一: 事实核查 (独立验证关键断言)
        │  ├─ 不通过 → return_to_writer → T4 写 v2 → R2 复查
        │  └─ 通过
        ▼
   T5  reviewer 阶段二: 发布前检查 (清单/依赖/元数据)
        │
  【闸门 G2：人终审】  ← Human 签字，block → unblock
        │
        ▼
     05_deliver/ (交付客户)
```

---

## 逐步骤详解

### T1 — architect 出大纲

- **角色**：architect
- **输入**：`00_intake/` 客户原件
- **输出**：`04_drafts/v0_outline.md`（结构化大纲 + 验收标准 + 红线）
- **命令**：
  ```bash
  T1=$(hermes kanban create "T1 大纲：<topic>" \
    --assignee architect --workspace "dir:$ORDER" --priority 3 \
    --body "你是 architect。阅读 00_intake/，产出 04_drafts/v0_outline.md。
    要求：章节结构、每章输入来源、验收标准、红线、待核定参数清单。
    红线：不伪引标准、不编造参数。完成后用 kanban_complete 提交。" \
    --json | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")
  hermes kanban dispatch
  ```

### 闸门 G1 — Human 审批大纲

- T1 完成后，architect 在 summary 里通知 Human。
- Human 审阅大纲，如需修改用 `hermes kanban comment` 批注，确认后放行下游。
- **放行**：创建 T2/T3 并 dispatch，或用 `hermes kanban promote` 手动推进。

### T2 ∥ T3 — 资料包 + 证据包（并行）

- **T2 ingestor**（资料包，读原件，不联网，~1 min）
- **T3 researcher**（证据包，联网检索，带置信度，5-10 min）
- **关键**：两者是 `--parent T1` 的并行子任务，dispatch 会同时 spawn 两个 worker。
  ```bash
  T2=$(hermes kanban create "T2 资料包" --assignee ingestor \
    --parent "$T1" --workspace "dir:$ORDER" --body "..." --json | jq -r .id)
  T3=$(hermes kanban create "T3 证据包" --assignee researcher \
    --parent "$T1" --workspace "dir:$ORDER" \
    --max-runtime 30m --body "..." --json | jq -r .id)
  hermes kanban dispatch   # 同时 spawn T2 和 T3
  ```
- **注意**：T3 是联网检索任务，比 T2 慢 10-20 倍。设 `--max-runtime` 防跑飞，
  轮询间隔放宽到 10s。

### T4 — writer 写初稿（等 T2 + T3 都完成）

- **依赖**：`--parent T2 --parent T3`，dispatcher 在两者都 done 后才 promote T4。
- **合成顺序**：专家包 → 资料包 → 证据包 → 模板。只用 🟢 数据。
- **输出**：`04_drafts/v1_draft.md`
  ```bash
  T4=$(hermes kanban create "T4 初稿" --assignee writer \
    --parent "$T2" --parent "$T3" --workspace "dir:$ORDER" \
    --body "..." --json | jq -r .id)
  ```

### T5 — reviewer 审校（两阶段）

- **依赖**：`--parent T4`
- **阶段一·事实核查**：独立验证关键断言，不通过则 `return_to_writer`。
- **闭环**：writer 修 v2（头部列已关闭 issue ID）→ reviewer R2 只查这些 ID + 红线抽查。
- **输出**：`04_drafts/review_report_rN.md`，verdict = approve_for_G2 时进入 G2。
  ```bash
  T5=$(hermes kanban create "T5 审校" --assignee reviewer \
    --parent "$T4" --workspace "dir:$ORDER" \
    --body "..." --json | jq -r .id)
  ```

### 闸门 G2 — Human 终审

- reviewer verdict = approve_for_G2 后，任务 block，通知 Human。
- Human 签字 → `hermes kanban unblock` → 成果进入 `05_deliver/` 交付。

---

## 监控命令速查

```bash
hermes kanban watch         # 实时事件流（所有任务）
hermes kanban list         # 看板总览
hermes kanban show <id>     # 任务详情 + comment + 事件
hermes kanban tail <id>     # 单任务事件流
hermes kanban log <id>      # worker 输出日志（卡住时看这个）
hermes kanban runs <id>     # 尝试历史
```

## 时间预期（mint-glm-5.2 实测）

| 任务 | 角色 | 工作类型 | 耗时 |
|------|------|---------|------|
| T1 大纲 | architect | 读原件+写md | ~90s |
| T2 资料包 | ingestor | 读原件+写md | ~50s |
| T3 证据包 | researcher | 联网检索 | ~6 min |
| T4 初稿 | writer | 读三包+写md | ~2 min |
| T5 审校 | reviewer | 读初稿+写报告 | ~3 min |
| T6 修订 | writer | 读审校+改稿 | ~2 min |

⚠️ T3（联网检索）是整条链的瓶颈，比纯文件任务慢 10-20 倍。设 `--max-runtime`，
轮询放宽，提前告诉用户"这一步要 5-10 分钟"。
