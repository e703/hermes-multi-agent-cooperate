#!/bin/bash
# =============================================================================
# setup.sh — Hermes 五角色团队部署脚本
#
# 适用环境：全新 Hermes 安装 + Blank Slate 配置后
# 从当前 active profile 创建 operator 入口 + 5 个角色 profile
# 幂等：可重复运行，已存在的 profile 会被跳过（但 SOUL.md 会覆盖更新）
#
# 用法：
#   cd /path/to/hermes-multi-agent-cooperate
#   bash scripts/setup.sh
#
# 前提：
#   - Hermes 已安装，已完成 setup（Blank Slate 或标准安装均可）
#   - 当前 active profile 有可用的 model + API key（◆ 标记的 profile）
#   - 已 git clone 本项目到本地
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

echo "=============================================="
echo " Hermes 五角色团队 — 自动部署"
echo "=============================================="

# ---- 前置检查 ----
echo ""
echo "━━━ [检查] 前置条件 ━━━"

# 确认 hermes 命令可用
if ! command -v hermes &>/dev/null; then
    echo "❌ hermes 命令未找到，请先安装 Hermes Agent"
    echo "   安装指南: https://hermes-agent.nousresearch.com/docs"
    exit 1
fi

# 确认当前 active profile
CURRENT_PROFILE=$(hermes profile list 2>/dev/null | grep "◆" | awk '{print $2}')
if [ -z "$CURRENT_PROFILE" ]; then
    CURRENT_PROFILE="default"
    echo "⚠️  未检测到 active profile，使用 'default' 作为源"
else
    echo "   源 profile: $CURRENT_PROFILE"
fi

# 确认 roles/ 目录存在
if [ ! -d "$PROJECT_DIR/roles" ]; then
    echo "❌ roles/ 目录不存在"
    echo "   请确认在项目根目录运行: bash scripts/setup.sh"
    exit 1
fi

# ---- Step 1: 验证 kanban 可用（内置功能，不需额外启用） ----
echo ""
echo "━━━ [1/5] 验证 kanban 可用性 ━━━"
echo "   kanban 是 Hermes 内置功能，非工具集，无需手动启用"

if hermes kanban init 2>/dev/null; then
    echo "   ✅ kanban 可用"
else
    echo "   ❌ kanban 初始化失败，请检查 Hermes 安装"
    exit 1
fi

# ---- Step 2: 创建 operator SOUL.md ----
echo ""
echo "━━━ [2/5] 写入 operator SOUL.md ━━━"

if [ ! -f "$HOME/.hermes/profiles/operator/SOUL.md" ]; then
    echo "   ⚠️  operator profile 不存在，请先创建:"
    echo "      hermes profile create operator --clone --no-alias --description \"团队入口...\""
    echo "      hermes profile use operator"
    exit 1
fi

cp "$PROJECT_DIR/roles/operator.md" "$HOME/.hermes/profiles/operator/SOUL.md"
echo "   ✅ operator SOUL.md 已写入"

# ---- Step 3: 创建五个角色 profile ----
echo ""
echo "━━━ [3/5] 创建五个角色 profile ━━━"

declare -A ROLE_MAP
ROLE_MAP[architect]="文档交付架构师：理解需求、制定大纲、拆解任务、挂依赖；不写长文初稿，不深度检索。"
ROLE_MAP[ingestor]="资料萃取员：只读客户原件(PDF/邮件/文本)，提取事实与硬约束，输出资料包；不联网、不写交付正文。"
ROLE_MAP[researcher]="联网情报员：按大纲章节检索可信来源，输出带引用与置信度的证据包；不写交付口吻长文，不覆盖专家结论。"
ROLE_MAP[writer]="撰写员：融合专家包>资料包>证据包+模板，按大纲写初稿并内嵌溯源；不做最终合规终审。"
ROLE_MAP[reviewer]="审校员：对照大纲/三包/红线审查初稿，做事实核查与发布前检查，输出问题清单与建议补丁；默认不整篇重写，只审不写。"

for ROLE in "${!ROLE_MAP[@]}"; do
    DESC="${ROLE_MAP[$ROLE]}"

    if ! hermes profile list 2>/dev/null | grep -qw "$ROLE"; then
        hermes profile create "$ROLE" --clone --no-alias --description "$DESC"
        echo "   ✅ $ROLE profile 已创建"
    else
        echo "   ✅ $ROLE profile 已存在，跳过创建"
    fi

    # 写入 SOUL.md（总是覆盖更新）
    if [ -f "$PROJECT_DIR/roles/$ROLE.md" ]; then
        cp "$PROJECT_DIR/roles/$ROLE.md" "$HOME/.hermes/profiles/$ROLE/SOUL.md"
        echo "   ✅ $ROLE SOUL.md 已写入"
    else
        echo "   ⚠️  $PROJECT_DIR/roles/$ROLE.md 不存在，跳过"
    fi
done

# ---- Step 4: 创建共享技能目录 ----
echo ""
echo "━━━ [4/5] 创建共享技能目录 ━━━"

SKILLS_DIR="$HOME/.hermes/profiles/operator/skills/productivity/professional-document-delivery"
mkdir -p "$SKILLS_DIR/references"

# 复制项目参考文档作为技能参考
for doc in wiki-system.md architecture.md collaboration-flow.md; do
    if [ -f "$PROJECT_DIR/$doc" ]; then
        cp "$PROJECT_DIR/$doc" "$SKILLS_DIR/references/"
        echo "   ✅ 已复制: $doc"
    fi
done

echo "   技能目录: $SKILLS_DIR"

# ---- Step 5: 创建订单目录模板 ----
echo ""
echo "━━━ [5/5] 创建订单目录模板 ━━━"

TEMPLATE_DIR="$HOME/.hermes/profiles/operator/templates/order"
mkdir -p "$TEMPLATE_DIR"
echo "   ✅ 订单模板目录: $TEMPLATE_DIR"

# ---- 完成 ----
echo ""
echo "=============================================="
echo " ✅ 部署完成"
echo "=============================================="
echo ""
echo "角色总览:"
hermes profile list 2>/dev/null | grep -v "^$" | grep -v "Profile" | grep -v "─"
echo ""
echo "━━━ 下一步操作 ━━━"
echo "  1. 安装并启动 gateway:  hermes gateway install"
echo "     (安装后记得 sudo loginctl enable-linger \$(whoami))"
echo "  2. 配置 IM 通知:        参考 human-gateway.md"
echo "  3. 跑验证订单:          参考 deployment.md 的验证步骤"
echo ""
echo "━━━ 快速验证 ━━━"
echo "  hermes profile list                        # 确认 7 个 profile 都在"
echo "  hermes kanban list                         # 看板就绪（空）"
echo "  hermes kanban assignees                    # 确认 5 角色可路由"
echo "========================================================================="