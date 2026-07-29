# 共享记忆层：skills + memory + 订单目录

> 本文说明"Wiki 共享记忆"如何用 Hermes 原生机制落地，而不是自研一套 wiki/ 目录。
> 核心思路：分层存储——模板/红线放 skills，风格/术语放 memory，客户文件放订单目录。

---

## 1. 为什么不自研 wiki/ 目录

原概念方案设计了一套 `wiki/system/`、`wiki/projects/`、`wiki/pages/` 的目录结构。
我们没有照搬，因为 Hermes 已经提供了等价且更优的原生载体：

| 原概念 wiki/ 结构 | Hermes 原生等价 | 为什么原生更好 |
|------------------|----------------|--------------|
| `wiki/system/`（角色定义/规范） | Profile `SOUL.md` + `skills/` | SOUL 随 profile 加载，自动注入上下文 |
| `wiki/projects/<项目>/` | `hermes project` + 订单目录 | project 可 bind-board，工作区确定性 |
| `wiki/pages/`（长期知识） | `skills/`（模板/SOP） | skill 可被 kanban 任务 `--skill` 指定加载 |
| 跨项目记忆 | Profile `memories/MEMORY.md` | memory 持久化，跨会话保留 |

自研目录的额外代价：要自己写加载逻辑、自己管注入、自己维护一致性。
原生机制这些都内置了。**能用原生的就不自研。**

---

## 2. 三层存储模型

### 第一层：skills/（长期可复用知识）

放跨订单复用的模板、红线、SOP。这些是"员工手册"级别的内容。

```
skills/productivity/professional-document-delivery/
├── SKILL.md                          # 流水线 SOP、角色契约、红线
└── references/
    ├── virtual-expert-firm.md        # 角色映射、流程图
    ├── kanban-deployment.md           # 部署 runbook
    ├── directory-dry-run.md           # 目录级演练
    ├── order-examples.md              # 已跑订单示例
    └── knowledge-base-tools.md        # 工具选型
```

**写入原则**：只有"六个月后还有用"的才进 skills。单次笔记、订单进度不进。

**技能分配**（防角色边界混乱）：

| 角色 | 应加载的技能 | 不该加载 |
|------|-------------|---------|
| architect | document-delivery（大纲/拆解部分） | 联网检索、写作模板 |
| ingestor | document-delivery（萃取部分）、ocr-and-documents | 联网检索 |
| researcher | document-delivery（检索部分）、web 搜索 | 写作模板 |
| writer | document-delivery（写作/模板部分）、humanizer | 检索技能 |
| reviewer | document-delivery（审校/红线部分） | 写作模板 |

通用技能（如 plan、文件操作）可跨角色共享。领域专用技能按职责归位。
质量审计类技能只归 reviewer，不归 architect——**管流程的不管质量**。

### 第二层：memories/MEMORY.md（跨订单经验）

放稳定的风格偏好、术语约定、表头/格式惯例。**绝不放客户密件。**

```markdown
# MEMORY.md — <role>

## 风格偏好
- 正文用"本制度"而非"我方"，避免供应商口吻
- 章节编号：第一章 → 1.1 → 1.1.1

## 术语表
- 弱电系统 = 综合布线+安防+楼控的统称
- 等保三级 = 信息安全等级保护第三级

## 协作经验（跨订单）
- researcher 联网任务慢 10-20 倍，务必设 --max-runtime
- reviewer 排除噪音时按 ID 引用，不重现敏感字符串
```

**写入原则**：

1. 是否特定于某订单？→ 是：存订单目录，不存 memory。
2. 是否只是临时状态？→ 是：存 kanban comment，不存 memory。
3. 六个月后还有用吗？→ 否：存 log，不存 memory。

reviewer 的 memory 只存"哪些数据易错、哪些来源更可靠"这类跨订单核查经验，
不存任何订单特定内容。

### 第三层：订单目录（客户文件 + 单次产出）

每个订单独立目录，所有客户原件和产出都在这里：

```
orders/<client>-<topic>-<YYYYMMDD>/
├── 00_intake/      # 客户原件（只读）
├── 01_notes/       # 资料包
├── 02_research/    # 证据包（带置信度）
├── 03_expertise/   # 专家包（Human 注入）
├── 04_drafts/      # 大纲/初稿/审校报告/终稿
├── 05_deliver/     # 对外交付包（G2 后进）
└── meta/           # 订单元数据
```

**一单一隔离**：每个订单独立 board 和/或 `--tenant`，客户 A 的材料绝不混进客户 B。
客户密件只进订单目录，**永远不进全局 memory**。

---

## 3. 信息路由总表（防污染）

| 信息类型 | 存哪 | 反例 |
|---------|------|------|
| 角色身份/行为准则 | Profile `SOUL.md` | 订单经验混进 SOUL |
| 跨订单协作经验 | Profile `memories/MEMORY.md` | 订单进度混进 MEMORY |
| 模板/红线/SOP | `skills/` | 临时想法混进 skills |
| 订单特定规则 | 订单目录 `AGENTS.md` | 提升为架构标准 |
| 单次任务记录 | kanban 事件流 + `log/` | 混入长期知识 |
| 客户原件与产出 | 订单目录 | 客户密件进 memory |

## 4. 信息污染预警

出现以下情况 = 信息放错位置，需纠正：

- `SOUL.md` 出现订单名称 → 角色身份被订单污染
- `MEMORY.md` 出现"今天做了什么" → 角色经验被进度污染
- `skills/` 出现单次笔记 → 临时想法污染长期知识
- `05_deliver/` 出现草稿 → 未验证材料混入正式产出
- 任何 memory 出现本属其他角色的关注点 → 角色边界污染

## 5. 向量库 / RAG（以后再说）

跨订单检索（向量库）是可选项，**只有在单订单路径跑通后再考虑**。
当前阶段：skills 管 SOP、memory 管风格、订单目录管文件——这三层足够。
过早引入向量库只会增加运维噪音。
