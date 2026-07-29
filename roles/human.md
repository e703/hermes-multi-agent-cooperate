# SOUL.md — Human（人类闸门）

> **Human 不是 Profile，没有对应的 `hermes profile create` 命令。**
> Human 是真人，gateway 绑定的是 **operator profile**（团队入口），
> 不是"human 角色"。Human 通过飞书/Telegram 给 operator 发消息，
> operator 收到后启动 kanban 任务链。
>
> 本文件说明 Human 在团队中的定位和介入方式。

## 身份

你是 Human——团队的负责人、专家、最终决策者。你不是 AI 角色，你是"虚拟专家事务所"
的合伙人。AI 角色提供选项和建议，但最终拍板的是你。

## 你负责的事

- **专家注入（Expert Pack）**：把你的专业判断写进 `03_expertise/`，或在任务里用
  `[核心结论]` / `[专家修正]` 标注。专家包优先级最高，无条件覆盖外部证据。
- **方向性决策**：做什么、做哪个、接不接这个单。
- **闸门审批**：
  - G1（大纲闸门）：architect 产出大纲后，你审批或修改，才放行研究/写作。
  - G2（终审闸门）：reviewer 通过后，你签字，才允许进入 `05_deliver/` 交付客户。
- **补缺**：AI 标注 `[待专家补充]` 的地方，由你填入真实数据。空白不编造。

## 介入方式：Telegram / 飞书

你通过即时通讯平台给团队下任务、看进度、在闸门节点审批。这是"人机入口"层。

```
你在 Telegram / 飞书 发消息
    │
    ▼
gateway（跑在 operator profile 上）接收消息
    │
    ▼
operator 启动 kanban 任务链
    │
    ▼
AI 团队（architect/ingestor/researcher/writer/reviewer）执行
```

- **下任务**：在 Telegram / 飞书 给 operator profile 发消息，描述订单需求。
   gateway 监听消息，operator 收到后启动 kanban 任务链。
- **看进度**：`hermes kanban list` / `hermes kanban watch` 实时看任务状态；
   或订阅任务事件，完成时自动推送通知到你的 Telegram / 飞书。
- **审批闸门**：任务在 G1/G2 处 `block`（阻塞），你看到通知后用
  `hermes kanban comment` 批注、`hermes kanban unblock` 放行。

详见 `human-gateway.md` 的配置与命令。

## 优先级铁律

整个团队遵循的优先级顺序，不可违背：

```
专家包（你注入） > 客户硬约束（原件） > 外部证据（researcher） > 风格模板
```

你的专家判断是专业护城河，任何外部检索都不能覆盖你标注的结论。

## 你不负责的事

- ❌ 亲手写初稿全文（交给 writer）
- ❌ 逐条联网核实（交给 researcher）
- ❌ 逐句审校（交给 reviewer）
- 你只在关键闸门节点介入，不在每一步都打断 AI 的工作。