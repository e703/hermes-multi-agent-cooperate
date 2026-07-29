# 部署手册：从零搭建五角色团队

> 本文档是真实部署层的 runbook。命令已在 mint-glm-5.2 + Hermes v0.19 验证过。
> 部署前请先读 `architecture.md`（概念映射）和 `roles/`（角色 SOUL）。

---

## 前置条件

- Hermes 已安装，gateway 在运行（`hermes gateway status`）。
  dispatcher 默认跑在 gateway 里，不需要单独 daemon。
- 当前 profile（alan）有可用的 model + API key，角色从这里 clone。
- 客户原件在磁盘上可访问。

## 第一步 — 创建角色 Profile（一次性）

每个角色从 alan clone，继承 model + 工具集。`--description` 是关键——
kanban decomposer 靠它路由任务，不只看 profile 名。

```bash
hermes profile create architect --clone --no-alias \
  --description "文档交付架构师：理解需求、制定大纲、拆解任务、挂依赖；不写长文初稿，不深度检索。"
hermes profile create ingestor --clone --no-alias \
  --description "资料萃取员：只读客户原件(PDF/邮件/文本)，提取事实与硬约束，输出资料包；不联网、不写交付正文。"
hermes profile create researcher --clone --no-alias \
  --description "联网情报员：按大纲章节检索可信来源，输出带引用与置信度的证据包；不写交付口吻长文，不覆盖专家结论。"
hermes profile create writer --clone --no-alias \
  --description "撰写员：融合专家包>资料包>证据包+模板，按大纲写初稿并内嵌溯源；不做最终合规终审。"
hermes profile create reviewer --clone --no-alias \
  --description "审校员：对照大纲/三包/红线审查初稿，做事实核查与发布前检查，输出问题清单与建议补丁；默认不整篇重写，只审不写。"
```

### 创建后：写入 SOUL.md

把 `roles/<role>.md` 的内容写入对应 profile 的 SOUL.md：

```bash
# 例：把本项目的 architect.md 写进 profile
cp roles/architect.md ~/.hermes/profiles/architect/SOUL.md
cp roles/ingestor.md ~/.hermes/profiles/ingestor/SOUL.md
cp roles/researcher.md ~/.hermes/profiles/researcher/SOUL.md
cp roles/writer.md ~/.hermes/profiles/writer/SOUL.md
cp roles/reviewer.md ~/.hermes/profiles/reviewer/SOUL.md
```

### 各 flag 说明

| flag | 原因 |
|------|------|
| `--clone` | 从 alan 继承 model + 工具集，无需手动配 |
| `--no-alias` | 跳过 wrapper 脚本，kanban worker 不需要 |
| `--description` | kanban decomposer 靠它路由，不只看名字 |

> Profile gateway=stopped 是正常的。worker 是 dispatcher spawn 的一次性
> `hermes chat -q` 进程，不是常驻 gateway。

## 第二步 — 创建订单目录 + 导入原件

```bash
ORDER="/home/alan/workspace/orders/<client>-<topic>-<YYYYMMDD>"
mkdir -p "$ORDER"/{00_intake,01_notes,02_research,03_expertise,04_drafts,05_deliver,meta}
cp -a "<客户原件>" "$ORDER/00_intake/"
```

### 订单目录约定

```
00_intake/      # 客户原件（只读，不在原地编辑）
01_notes/       # 资料包（ingestor 产出）
02_research/    # 证据包（researcher 产出，带置信度）
03_expertise/   # 专家包（Human 注入，最高优先级）
04_drafts/      # v0_outline, v1_draft, v2_reviewed, v3_final, review_report
05_deliver/     # 对外交付包（G2 后才进）
meta/           # 订单元数据
```

一单一隔离：每个订单独立 board 和/或 `--tenant`，绝不把客户 A 的材料混进客户 B 的上下文。

## 第三步 — 建任务链

### 关键：`--body` 是 worker 的全部上下文

spawned worker 没有聊天历史。`--body` 必须自包含：角色身份、输入路径、
输出路径、格式要求、红线、以及"用 kanban_complete 提交"的期望。

### T1 — architect 大纲

```bash
T1=$(hermes kanban create "T1 大纲：<topic>" \
  --assignee architect --workspace "dir:$ORDER" --priority 3 \
  --body "你是 architect。阅读 00_intake/<file>，产出 04_drafts/v0_outline.md。
要求：章节结构、每章输入来源、验收标准、红线、待核定参数。
红线：不伪引标准、不编造参数、不写私人邮箱。
完成后用 kanban_complete 提交，summary 写大纲路径，metadata 写章节数与开放问题。" \
  --json | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")

hermes kanban dispatch   # 手动触发一次派发，不必等 60s
```

### 轮询 T1 完成

```bash
for i in $(seq 1 36); do
  S=$(hermes kanban show "$T1" | grep "status:" | awk '{print $2}')
  [ "$S" = "done" ] && break
  sleep 5
done
```

### T2 ∥ T3 — 并行子任务（G1 审批后）

```bash
T2=$(hermes kanban create "T2 资料包" --assignee ingestor \
  --parent "$T1" --workspace "dir:$ORDER" \
  --body "你是 ingestor。读 00_intake/，产出 01_notes/资料包.md。
硬约束表(HC-*)、事实ID+指针、噪音排除清单。原件没有的参数用[待现场核定]占位。
完成后 kanban_complete。" --json | jq -r .id)

T3=$(hermes kanban create "T3 证据包" --assignee researcher \
  --parent "$T1" --workspace "dir:$ORDER" --max-runtime 30m \
  --body "你是 researcher。按大纲章节联网检索，产出 02_research/证据包.md。
每条数据标注置信度(🟢🟡🔴)+引用(URL+日期)，末尾附置信度汇总表。无汇总表视为未完成。
只标注不编造。完成后 kanban_complete。" --json | jq -r .id)

hermes kanban dispatch   # 同时 spawn T2 和 T3 —— 真并行
```

### T4 — writer 初稿（等 T2+T3）

```bash
T4=$(hermes kanban create "T4 初稿" --assignee writer \
  --parent "$T2" --parent "$T3" --workspace "dir:$ORDER" \
  --body "你是 writer。融合 03_expertise/> 01_notes/> 02_research/ + 模板，
按大纲写 04_drafts/v1_draft.md，内嵌溯源。只用🟢数据，🟡🔴禁用。
合成顺序：专家包>资料包>证据包>模板。完成后 kanban_complete。" \
  --json | jq -r .id)
# dispatcher 在 T2 和 T3 都 done 后才 promote T4
```

### T5 — reviewer 审校（等 T4）

```bash
T5=$(hermes kanban create "T5 审校" --assignee reviewer \
  --parent "$T4" --workspace "dir:$ORDER" \
  --body "你是 reviewer。对 04_drafts/v1_draft.md 做两阶段审计：
阶段一·事实核查：提取关键断言逐条独立验证(不依赖researcher原始来源)；
阶段二·发布前检查：格式/内容规则/元数据泄漏。
产出 04_drafts/review_report_r1.md，带severity(critical/major/minor)+issue ID+verdict。
默认只审不写。完成后 kanban_complete。" --json | jq -r .id)
```

### 闭环：reviewer 打回 → writer v2 → reviewer R2

若 T5 verdict=return_to_writer，创建 T6 让 writer 按问题清单修复：

```bash
T6=$(hermes kanban create "T6 修订v2" --assignee writer \
  --parent "$T5" --workspace "dir:$ORDER" \
  --body "你是 writer。读 review_report_r1.md，按 issue ID 逐条修复，
产出 04_drafts/v2_reviewed.md，头部列出已关闭 issue ID。完成后 kanban_complete。" \
  --json | jq -r .id)
# 然后 reviewer R2 只查已关闭 ID + 红线抽查
```

## 第四步 — 监控

```bash
hermes kanban watch          # 实时事件流
hermes kanban list           # 看板总览
hermes kanban show <id>      # 任务详情+comment+事件
hermes kanban tail <id>      # 单任务事件流
hermes kanban log <id>       # worker 日志（卡住时看）
hermes kanban runs <id>      # 尝试历史
```

### 后台轮询（不阻塞 agent loop）

长任务（T3、T5）别在前台死等。用 background 轮询：

```bash
# 终端 background + notify_on_complete，任务完成时通知你
for i in $(seq 1 72); do
  S=$(hermes kanban show "$TASK_ID" 2>/dev/null | grep "status:" | awk '{print $2}')
  [ "$S" = "done" ] || [ "$S" = "blocked" ] && break
  sleep 10
done
hermes kanban list
```

## 第五步 — 跑后验收

- [ ] 每个任务 done 且带 summary + metadata
- [ ] 成果落在订单目录（不是 scratch）
- [ ] 父子 promote 正常（T4 没在 T2+T3 完成前启动）
- [ ] B∥C 真并行（T2/T3 同时 running）
- [ ] 证据包带置信度汇总表
- [ ] reviewer 走了两阶段，verdict 明确
- [ ] 终稿无编造数字/标准/认证
- [ ] 专家占位符 `[待现场核定]` 完好

## 常见问题

| 症状 | 原因 | 解决 |
|------|------|------|
| 任务一直 `ready` 不动 | gateway 没跑（dispatcher 在 gateway 里） | `hermes gateway start` |
| dispatch 显示 `Spawned: 0` | 没有 ready 任务（前置没完成） | 查父任务状态 |
| 任务 `running` 很久 | 联网检索任务 | 看 `kanban log`，设 `--max-runtime` |
| worker 跑完没 complete | 协议违规（答了没调工具） | 任务自动 block 成 gave_up，修 body |
| Profile not found | 拼写错或没建 | `hermes kanban assignees` 看有效 profile |

## 角色演进（不要一上来开五个）

低单量时 2 个 profile（architect + writer 自带轻审）即可；瓶颈出现再拆出
ingestor / researcher / reviewer。**不要在单订单路径跑通前就开五个 profile。**

## Builder 角色（可选，非文档场景）

文档交付不需要 Builder。若团队转向写代码场景，可加一个 builder profile：

```bash
hermes profile create builder --clone --no-alias \
  --description "工程师：实现/调试/测试/交付；发现上游错误写驳回报告，不重跑全量。"
```

Builder 的技术驳回流程：发现上游材料有错 → 拆分已完成和需修正部分 → 写驳回报告 →
architect 只路由需修正部分，不重新跑全量。
