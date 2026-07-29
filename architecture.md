# 架构：概念到 Hermes 原生机制的映射

> 本文档是整套团队协作方案的骨架。它把"多角色协作"的每个概念，逐项映射到
> Hermes v0.19+ 的真实原生命令，不发明任何自研基础设施。
> 适用场景：专业文档交付（研究 + 写作）。角色命名沿用已验证实践。

---

## 1. 核心判断

Hermes 的高级用法不是多开几个 Agent，而是用多 Profile 做角色分工，用
Kanban 看板做任务路由与进度跟踪，用 skills/memory 做分层记忆。目标是让
一个人也能管理一支稳定协作的 Agent 团队。

为什么不单 Agent 全包？长期任务中研究、写作、审查、复盘会挤进同一段上下文，产生三个问题：

- **幻觉**：一个 Agent 自己查、自己写、自己审，缺乏交叉视角。
- **记忆污染**：不同订单的经验互相串味。
- **角色混乱**：该研究时下结论，该审查时替自己辩护。

解决思路：角色分离（管流程的不管质量）+ 三级置信度（在源头阻断编造）+
独立审计（Editor 不信任 Writer 的自检）。

---

## 2. 五个基础概念 → Hermes 载体

多 Agent 系统乱的根本原因：把长期角色、临时任务、项目空间和共享记忆混成了一件事。
下表把概念和 Hermes 真实载体对齐：

| 概念 | Hermes 载体 | 职责 | 生命周期 |
|------|------------|------|---------|
| Profile（角色） | `~/.hermes/profiles/<name>/SOUL.md` | 定义"我是谁、我该做什么" | 长期固定 |
| Project（项目） | `hermes project create` + 订单目录 | 一个具体订单的完整记录 | 订单周期 |
| 共享记忆（Wiki） | `skills/` + `memories/` + 订单目录 | 模板/红线、风格/术语、客户文件 | 分层永久 |
| Session（会话） | kanban worker 进程 | 单次任务执行的上下文 | 任务结束即释放 |
| 任务路由 | `hermes kanban` 看板 | 任务领取、父子依赖、自动派发 | 任务周期 |

要点：同一个 Profile 团队服务多个 Project（订单）。换订单不换角色，换角色才换 Profile。

---

## 3. 六角色模型

每个角色有明确的"负责"和"不负责"边界。从五角色起步，不要一开始开十几个角色。

### 3.0 operator（团队入口）

- **负责**：接收 Human 订单、启动 kanban 任务链、监控进度、闸门桥接、维护团队。
- **不负责**：具体执行（研究/写作/审计）。
- **成为 gateway 绑定的入口 profile**，Human 通过飞书/Telegram 向你发消息。
- **对应原生命令**：
  ```bash
  hermes profile create operator --clone --no-alias \
    --description "团队入口：接收 Human 订单、启动 kanban 任务链、监控进度；不亲自做研究/写作/审校。"
  ```
  description 是关键——kanban decomposer 靠它路由任务，不只看 profile 名。

### 3.1 architect（编排者 / 架构师）

- **负责**：理解需求、制定大纲、拆解任务、挂依赖链、检查边界、汇总结果。
- **不负责**：具体执行（研究/写作）、质量审计、内容审核。
- **Session Gate**：每次接到订单先确认归属，产出结构化大纲（文档类型、受众、
  章节结构、每章输入来源、验收标准、红线），列出待核定参数。
- **对应原生命令**：
  ```bash
  hermes profile create architect --clone --no-alias \
    --description "文档交付架构师：理解需求、制定大纲、拆解任务、挂依赖；不写长文初稿，不深度检索。"
  ```
  description 是关键——kanban decomposer 靠它路由任务，不只看 profile 名。

### 3.2 ingestor（资料萃取员）

- **负责**：解析客户原件（PDF/邮件/文本），提取事实与硬约束，输出结构化资料包。
- **不负责**：联网检索、写交付正文、编造原件中没有的参数。
- **缺失即承认**：原件中没有的参数（温度、日志保留天数、UPS 容量）用
  `[待现场核定]` / `[待专家补充]` 占位，绝不编造。
- **对应原生命令**：
  ```bash
  hermes profile create ingestor --clone --no-alias \
    --description "资料萃取员：只读客户原件(PDF/邮件/文本)，提取事实与硬约束，输出资料包；不联网、不写交付正文。"
  ```

### 3.3 researcher（研究员 + 三级置信度）

- **负责**：按大纲章节检索可信来源、对比来源、提炼事实、标注不确定性、输出证据包。
- **不负责**：内容表达和润色、覆盖专家结论。
- **三级置信度（强制标注）**：每条数据/事实/数字必须标注等级，无标注的证据包视为未完成。

  | 等级 | 标记 | 定义 | 使用规则 |
  |------|------|------|---------|
  | 🟢 | 已核实 | 至少 1 个独立可信来源确认 | 下游可直接使用 |
  | 🟡 | 估计值 | 未找到直接来源，间接推断 | 下游禁用，需补查 |
  | 🔴 | 推测 | 无任何来源，纯推断 | 下游禁用 |

  每份证据包末尾必须附带「置信度汇总表」。核心理念：在源头阻断编造，
  研究阶段标清楚，下游就不会基于错误数据工作。
- **对应原生命令**：
  ```bash
  hermes profile create researcher --clone --no-alias \
    --description "联网情报员：按大纲章节检索可信来源，输出带引用与置信度的证据包；不写交付口吻长文，不覆盖专家结论。"
  ```

### 3.4 writer（撰写员 / 执行者）

- **负责**：把三包（专家包 > 资料包 > 证据包）+ 模板转化为初稿，内嵌溯源。
- **不负责**：事实验证、质量审计、项目规划。
- **关键规则**：Writer 只用 🟢 数据。🟡 和 🔴 不应出现在最终产出中。🟢 数据不足时，
  召回 researcher 补查，不从 🟡 里挑。写作合成顺序：专家包 → 资料包 → 证据包 → 模板。
- **对应原生命令**：
  ```bash
  hermes profile create writer --clone --no-alias \
    --description "撰写员：融合专家包>资料包>证据包+模板，按大纲写初稿并内嵌溯源；不做最终合规终审。"
  ```

### 3.5 reviewer（质量审计 / Editor）

- **v1 核心升级。管流程的会优先关注"做完了吗"，独立审计才只问"做对了吗"。**
- **负责两阶段审计**：
  - **阶段一·事实核查**：提取初稿中所有关键断言（数字、日期、比较值、排名），
    逐条独立验证，不依赖 researcher 的原始来源。输出核查清单，不通过打回 writer。
  - **阶段二·发布前检查**：执行项目定义的检查清单（格式规范、内容规则、
    元数据清理）、验证外部依赖完整、确认无内部元数据泄漏到对外产出。
- **不负责**：选题、研究、写作、发布、流程编排。
- **默认只审不写**：输出问题清单（severity: critical/major/minor）+ 可选补丁建议，
  不整篇重写。返回 verdict：`return_to_writer` / `approve_for_G2` / `needs_expert`。
- **对应原生命令**：
  ```bash
  hermes profile create reviewer --clone --no-alias \
    --description "审校员：对照大纲/三包/红线审查初稿，做事实核查与发布前检查，输出问题清单与建议补丁；默认不整篇重写，只审不写。"
  ```

### 3.6 Human（人类闸门）

- Human 不是 Profile，是唯一拥有最终决策权的角色。
- **方向性决策**（做什么、做哪个）归属于 Human。
- **发布/交付决策**（可以发出去了）归属于 Human。
- 介入方式：通过 Telegram / 飞书 给 operator profile 发消息，operator 收到后启动 kanban 任务链。
  详见 `human-gateway.md`。

---

## 4. 信息路由规则（防污染）

规定所有类型信息的唯一存放位置。这是防污染的核心。

| 信息类型 | 存放位置 | 反例 |
|---------|---------|------|
| 角色身份/行为准则 | Profile `SOUL.md` | 项目经验混入 SOUL.md |
| 跨订单协作经验 | Profile `memories/MEMORY.md` | 订单进度混入 MEMORY.md |
| 长期可复用知识（模板/红线/SOP） | `skills/` | 临时想法混入 skills |
| 订单特定规则和流程 | 订单目录 `AGENTS.md` | 提升为架构标准 |
| 单次任务记录 | kanban 任务事件流 + `log/` | 混入长期知识库 |
| 客户原件与产出 | 订单目录（`00_intake/` ... `05_deliver/`）| 客户密件进全局 memory |

### 写入前三问（三问原则）

任何角色在写入信息前，必须先问自己：

1. **是否特定于某个订单？** → 是：存到订单目录，不存 Profile memory 或全局 skills。
2. **是否只是临时状态？** → 是：存到 kanban 任务 comment 或订单 `log/`，不存长期存储。
3. **六个月后还有用吗？** → 否：存到 `log/`，不存 skills 或 memory。

### 信息污染预警

出现以下情况说明信息放错了位置：

- `SOUL.md` 里出现订单名称 → 角色身份被订单状态污染。
- `MEMORY.md` 里出现"今天做了什么" → 角色经验被订单进度污染。
- `skills/` 里出现单次笔记 → 临时想法污染长期知识。
- `05_deliver/` 里出现草稿 → 未验证材料混入正式产出。

---

## 5. 质量保障体系（三层防护）

| 防护层 | 执行者 | 时机 | 机制 | 阻止什么 |
|-------|-------|------|------|---------|
| #1 源头阻断 | researcher | 研究产出时 | 三级置信度标注 | 未经核实的数据进入下游 |
| #2 独立核查 | reviewer | 初稿完成后 | 逐条独立验证关键断言 | 已核实数据中的错误 |
| #3 交付复检 | reviewer | 发布/交付前 | 项目检查清单 | 形式错误和元数据泄漏 |

三层递进：#1 在研究产出时就阻断编造数据进入下游；#2 独立验证 Writer 使用的
🟢 数据仍准确；#3 在交付前兜底形式问题。

### 闸门（HITL）

1. **大纲闸门（G1）**：architect 产出结构化大纲后，Human 审批/修改，才放行
   ingestor ∥ researcher 并行。
2. **终审闸门（G2）**：reviewer 通过后，Human 终审签字，才允许进入 `05_deliver/`。
3. **（可选）专家包闸门**：高风险订单，在 writer 动笔前确认专家包完整性。

---

## 6. 为什么不手搓通信层（旧方案对比）

旧项目（已删除的 `profiles/` + `scripts/telegram_send.py`）用 4 个 agent
+ Telegram group 的不同 topic 互相发消息，手搓了一套 FROM/TO/CONTENT 通信协议。

**为什么丢弃**：

| 维度 | 旧方案（手搓 Telegram） | 新方案（Hermes kanban） |
|------|----------------------|----------------------|
| 任务路由 | agent 自己读消息、自己判断该干啥 | kanban decomposer 按 description 路由 |
| 任务依赖 | 靠 agent 之间的消息传递，时序无保证 | `--parent` 父子链，dispatcher 自动等待 |
| 并行执行 | 各发各的消息，无法真正并行 | `dispatch` 一次 spawn 多个 worker 进程 |
| 进度跟踪 | 每个 agent 维护自己的 .md 文件 | kanban 看板统一状态（todo/running/done/blocked） |
| 接收消息 | ❌ 没实现（致命缺陷） | ✅ dispatcher 自动 spawn worker 读 `--body` |
| 持久化 | 无，消息发完即逝 | SQLite 持久化，可 reclaim/comment/attach |
| 容错 | 无 | `--max-runtime` 超时、`--max-retries` 重试、`gave_up` 自动 block |

旧方案最致命的问题：只实现了"发消息"，没实现"收消息"——agent 收不到对方回信，
协作根本跑不起来。kanban 用"任务看板 + dispatcher 自动 spawn worker"彻底
解决了这个问题：不需要 agent 互相喊，dispatcher 看到任务 ready 就自动派发。

---

## 7. 概念映射总表

| 新方案概念 | Hermes 原生实现 | 关键命令 |
|-----------|----------------|---------|
| Profile（角色） | `hermes profile create --clone` | `--description` 供 decomposer 路由 |
| Project（项目） | `hermes project create` | `bind-board` 绑定看板 |
| 角色协作/任务路由 | `hermes kanban` | `create` / `assign` / `dispatch` |
| 并行→审核→汇总 | `hermes kanban swarm` | `--worker` / `--verifier` / `--synthesizer` |
| 任务依赖（等前置完成） | `--parent` 父子链 | dispatcher 自动 promote |
| 任务隔离工作区 | `--workspace dir:<abs>` | 客户文件不丢 |
| 任务记录/进度 | kanban 事件流 | `show` / `tail` / `log` / `watch` |
| 等人审批 | `kanban block` + comment | unblock 后继续 |
| Session Gate | kanban `context` | 加载项目上下文 |
| 共享模板/红线 | `skills/` | 跨订单复用 |
| 风格/术语记忆 | `memories/MEMORY.md` | 不含客户密件 |
| Human 下任务/看进度 | gateway 监听 Telegram/飞书 → operator profile | `hermes send` / `kanban notify-subscribe` |