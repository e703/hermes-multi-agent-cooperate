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

## 六角色

| 角色 | Profile | 职责 | 不负责 |
|------|---------|------|--------|
| **operator** | `operator` | 入口：收订单、起 kanban 链、监控进度 | 研究/写作/审计 |
| architect | `architect` | 大纲、拆解、挂依赖、汇总 | 写初稿、检索、审计 |
| ingestor | `ingestor` | 解析原件→资料包 | 联网、写正文、编造 |
| researcher | `researcher` | 联网检索→证据包(🟢🟡🔴) | 润色、覆盖专家结论 |
| writer | `writer` | 三包+模板→初稿(只用🟢) | 事实核查、终审 |
| reviewer | `reviewer` | 事实核查 + 发布前检查 | 写作、发布 |
| **Human** | （非 Profile） | 专家注入 + 双闸门审批 | 亲手写初稿/逐句审 |

> Builder（工程师）角色为可选，文档交付不需要；写代码场景再启用，见 `deployment.md`。

## 协作流程

```
需求 → operator 起链 → architect 大纲 →【G1 人审】→ ingestor∥researcher(资料包∥证据包)
     → 专家包(人) → writer 初稿 → reviewer 事实核查 → reviewer 发布前检查
     →【G2 人终审】→ 交付
```

详见 `collaboration-flow.md`。

## 文档导航

| 文档 | 内容 |
|------|------|
| `architecture.md` | 核心骨架：概念到 Hermes 原生命令的逐项映射 |
| `roles/` | 六个角色 + human 的 SOUL.md（operator + 5 角色 + human） |
| `collaboration-flow.md` | 一个完整订单的端到端流程，每步配 kanban 命令 |
| `deployment.md` | 自部署 runbook：Blank Slate → setup.sh → gateway → IM |
| `human-gateway.md` | Human 通过 Telegram/飞书 下任务、看进度、审批闸门 |
| `wiki-system.md` | 共享记忆层：skills + memory + 订单目录，防污染规则 |
| `scripts/setup.sh` | 一键部署脚本：创建 6 个 profile + 初始化看板 |

## 部署方式

全新环境自部署，见 `deployment.md`。核心流程：

```bash
# 1. 安装 Hermes（Blank Slate）→ 配置 model
# 2. git clone 本项目
# 3. 在 hermes chat 中运行 setup.sh
# 4. 启动 gateway → 配置 IM → 验证
```

## 部署前须知

- 角色命名沿用已验证实践（非新方案的 coordinator/editor/builder 命名）。
- 所有命令在 Hermes v0.19 + mint-glm-5.2 验证过，计时数据见 `deployment.md`。
- 角色从 operator profile clone，继承 model + 工具集。
- 先读 `architecture.md` 理解概念映射，再按 `deployment.md` 动手。
- **不要在单订单路径跑通前就开五个角色**——低单量时 2 个（operator + architect 自带轻审）即可。