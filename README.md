# hermes-multi-agent-cooperate

Hermes 多角色协作团队 —— 面向专业文档交付（研究 + 写作）的五角色架构。

用 Hermes 原生的 **多 Profile + Kanban 看板** 做角色分工与任务路由，
不手搓通信层。Human 通过 Telegram / 飞书 下任务、看进度、在闸门节点审批。

---

## 这是什么

一个人管理一支稳定协作的 AI Agent 团队，按"虚拟专家事务所"的方式交付专业文档：

- **角色分离**：管流程的不管质量，管质量的不管流程。
- **三级置信度**：研究员在源头标注 🟢🟡🔴，阻断编造数据进入下游。
- **独立审计**：reviewer 独立做事实核查 + 发布前检查，不信任 writer 自检。
- **双闸门人审**：大纲（G1）和终审（G2）由 Human 拍板。
- **一单一隔离**：每个订单独立目录，客户材料互不污染。

## 五角色

| 角色 | Profile | 职责 | 不负责 |
|------|---------|------|--------|
| architect | `architect` | 大纲、拆解、挂依赖、汇总 | 写初稿、检索、审计 |
| ingestor | `ingestor` | 解析原件→资料包 | 联网、写正文、编造 |
| researcher | `researcher` | 联网检索→证据包(🟢🟡🔴) | 润色、覆盖专家结论 |
| writer | `writer` | 三包+模板→初稿(只用🟢) | 事实核查、终审 |
| reviewer | `reviewer` | 事实核查 + 发布前检查 | 写作、发布 |
| **Human** | （非 Profile） | 专家注入 + 双闸门审批 | 亲手写初稿/逐句审 |

> Builder（工程师）角色为可选，文档交付不需要；写代码场景再启用，见 `deployment.md`。

## 协作流程

```
需求 → architect 大纲 →【G1 人审】→ ingestor∥researcher(资料包∥证据包)
     → 专家包(人) → writer 初稿 → reviewer 事实核查 → reviewer 发布前检查
     →【G2 人终审】→ 交付
```

详见 `collaboration-flow.md`。

## 文档导航

| 文档 | 内容 |
|------|------|
| `architecture.md` | 核心骨架：概念到 Hermes 原生命令的逐项映射 |
| `roles/` | 五个角色的 SOUL.md 草案（architect/ingestor/researcher/writer/reviewer + human） |
| `collaboration-flow.md` | 一个完整订单的端到端流程，每步配 kanban 命令 |
| `deployment.md` | 真实部署 runbook：profile 创建、任务链、监控、常见问题 |
| `human-gateway.md` | Human 通过 Telegram/飞书 下任务、看进度、审批闸门 |
| `wiki-system.md` | 共享记忆层：skills + memory + 订单目录，防污染规则 |

## 为什么不用旧的 Telegram 通信方案

旧方案用 4 个 agent + Telegram group 不同 topic 互相发消息，手搓 FROM/TO/CONTENT 协议。
致命缺陷：只实现了"发消息"，没实现"收消息"——agent 收不到对方回信，协作跑不起来。

本方案改用 Hermes 原生 kanban：任务看板 + dispatcher 自动 spawn worker，不需要 agent
互相喊。任务路由靠 `--description`、依赖靠 `--parent`、并行靠 `dispatch`、
进度靠看板状态。详见 `architecture.md` 第 6 节。

## 部署前须知

- 角色命名沿用已验证实践（非新方案的 coordinator/editor/builder 命名）。
- 所有命令在 Hermes v0.19 + mint-glm-5.2 验证过，计时数据见 `deployment.md`。
- 角色从当前 profile（alan）clone，继承 model + 工具集。
- 先读 `architecture.md` 理解概念映射，再按 `deployment.md` 动手。
- **不要在单订单路径跑通前就开五个 profile**——低单量时 2 个（architect+writer）即可。
