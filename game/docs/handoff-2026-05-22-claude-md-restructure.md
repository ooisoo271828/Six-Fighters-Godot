# CLAUDE.md 重构 + AI 工具调研 — 2026-05-22

## 概述

本次工作分两部分：(1) 调研主流 AI 编程工具生态；(2) 基于调研结果全面重构 CLAUDE.md 文件。

---

## 1. AI 工具生态调研

调研了 4 个主流 AI 编程增强工具，评估对本项目的适用性：

### CodeGraph (1.5万星)
- **功能**: 用 tree-sitter 构建代码语义知识图谱，AI agent 直接查图谱而非 grep/glob
- **结论**: **不适用** — 不支持 GDScript，项目规模不够大

### Karpathy Skills (14万星)
- **功能**: 4 条 LLM 编程行为规范（Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven）
- **结论**: **已覆盖** — 我们的 CLAUDE.md 已包含这 4 条

### AgentMemory (1.5万星)
- **功能**: 跨会话持久化记忆系统，自动捕获操作历史，语义搜索
- **结论**: **暂不需要** — Claude Code 自带记忆系统够用，单项目场景不值得装

### Superpowers (20万星)
- **功能**: 完整软件开发方法论（Brainstorming → Planning → Subagent Development → TDD → Review）
- **结论**: **部分吸收** — 采纳了 Systematic Debugging 和 Design Before Coding 的核心理念

---

## 2. CLAUDE.md 重构

### 问题诊断

| 问题 | 严重度 |
|------|--------|
| Auth Token 硬编码明文 | 高 |
| 路径过时 (`E:\VibeCoding\six-fighter-gd`) | 高 |
| 规则 5 (Systematic Debugging) 36 行，与其他规则风格不一致 | 中 |
| 规则 1 vs 规则 6 内容重叠 | 中 |
| 项目文档 290 行全部加载到上下文 | 中 |
| 规则 4 例子不适用 Godot ("Write tests") | 低 |
| 缺少项目基础信息 (Godot 版本、分辨率、核心玩法) | 低 |

### 改动清单

| 改动 | 详情 |
|------|------|
| **安全修复** | Auth Token 改为指向 `.env` 文件 |
| **路径修复** | 全部改为相对路径 (`game/addons/...`, `broker/...`) |
| **规则 5 精简** | 36 行 → 15 行，四阶段压缩为 5 步，与其他规则风格对齐 |
| **规则 1/6 分工明确** | 规则 1 = 别假设；规则 6 = 复杂功能走设计流程 |
| **规则 4 例子适配** | "Write tests" → "Reproduce in SkillDemo" |
| **补充项目基础** | Godot 4.x、540×960、6 英雄自动战斗 |
| **文档拆分** | SkillDemo/Camera/Hastur 详细内容移到 `docs/` 下独立文件 |
| **上下文瘦身** | 407 行 → 147 行（减少 64%） |

### 新文件结构

```
game/.claude/CLAUDE.md              147 行  ← 每次对话加载
game/docs/claude-ref-hastur.md      170 行  ← 需要时读取
game/docs/claude-ref-skill-demo.md   42 行
game/docs/claude-ref-camera.md       32 行
```

### 最终行为规范 (6 条)

1. **Think Before Coding** — 别假设，不确定就问
2. **Simplicity First** — 最少代码解决问题
3. **Surgical Changes** — 只碰该碰的
4. **Goal-Driven Execution** — 定义成功标准，循环验证
5. **Systematic Debugging** — 没找到根因不准修（新吸收自 Superpowers）
6. **Design Before Coding** — 需求不明确先问清楚再动手（新吸收自 Superpowers）

---

## 3. 关键决策记录

- **不装 Superpowers 全套** — 全套装会导致每个任务都走完整流水线，简单任务从 1 分钟变 5-10 分钟
- **只吸收两条核心规则** — Systematic Debugging 和 Design Before Coding，以行为规范形式写入 CLAUDE.md，零日常开销
- **不装 CodeGraph** — 不支持 GDScript
- **不装 AgentMemory** — 单项目场景不需要跨会话记忆系统

---

## 4. 后续可选

- [ ] 将 broker-server 的 auth token 迁移到 `.env` 文件（当前 CLAUDE.md 已指向 `.env`，但 `.env` 文件可能还不存在）
- [ ] 考虑将 `docs/` 下的历史 handoff 文档归档到 `docs/archive/`
