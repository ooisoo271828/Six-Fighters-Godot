# 会话交接文档：VFX 系统改造方案设计
**Date:** 2026-05-17
**Participants:** Engineering (AI Architect)
**Scope:** 对当前技能特效系统进行全面审计，输出改造方案设计文档

---

## 1. 本次会话做了什么

### 1.1 项目全景分析
- 对整个 Godot 项目进行了全面的代码级审计
- 覆盖：核心单例、战斗系统、单位系统、技能系统（SkillSystem 全部子模块）、VFX 系统、场景结构、资源文件、Broker 远程执行系统、CLI 工具、文档体系

### 1.2 VFX 系统深度审计
对以下模块进行了逐文件深度分析：

| 模块 | 文件 | 审计内容 |
|------|------|---------|
| 弹体渲染 | `pools/projectile_node.gd` | 7 层 Sprite2D + 2 GPUParticles2D + 3 Line2D 的完整实现细节 |
| 命中特效 | `vfx/skill_vfx_manager.gd` | 5 种 kind 的执行逻辑（2 种空实现） |
| 层级注册 | `vfx/vfx_tier_registry.gd` | A/B/C 三层查询链 |
| 数据定义 | `registry/skill_visual_def.gd` | 285 行 God Object，100+ @export 字段 |
| 资源文件 | `resources/vfx/layers/*.tres` | 7 个 VFXLayerDef 的参数详情 |
| 场景文件 | `nodes/projectile.tscn` | 有未使用的 Core/Trail 子节点 |

**关键发现：**
- 项目零 Shader（`.gdshader` 文件数 = 0）
- 所有纹理为程序化 16×16 白色圆形（逐像素 `set_pixel`）
- 命中特效每次 `new Sprite2D()` + `queue_free()`，挂在 `scene.root`
- GPUParticles2D 零方向归一化 bug 的过度规避
- Godot 4.6 bool 属性缓存 bug 的 workaround

### 1.3 改造方案设计文档
- 输出 [vfx-system-overhaul-proposal-2026-05.md](tech/vfx-system-overhaul-proposal-2026-05.md)（946 行）
- 5 个 Phase、20+ 个具体 Task
- 每个 Task 含：文件路径、技术规格（含 GLSL/GDScript 代码）、集成点、验收标准
- 含依赖关系图 + AI 并行执行建议

---

## 2. 已落档的文档

| 文档路径 | 内容 |
|---------|------|
| `docs/tech/vfx-system-overhaul-proposal-2026-05.md` | VFX 系统改造方案 v0.1（5 Phase，946 行） |
| 本文件 | 会话交接文档 |

---

## 3. 改造方案概要

### Phase 1：Shader 基础设施（2-3 天）
- Glow Shader — 弹体边缘发光
- Dissolve Shader — 溶解消散
- Ring Wave Shader — 冲击波环
- VFXTextureManager — 全局纹理管理器（替代各类自生成 16×16 圆形）

### Phase 2：命中特效系统升级（3-4 天）
- HitVFXPool — 命中特效对象池
- Executor 策略模式 — 替代 match 硬编码分发
- 实现 ring / sprite_burst 执行器
- 新增 shockwave / afterimage 执行器

### Phase 3：SkillVisualDef 重构（2 天）
- 拆分为 4 个子 Resource：ProjectileVisual / TrailVisual / ImpactVisual / VFXOverride
- 提供迁移脚本（Python）
- 向后兼容层

### Phase 4：新特效类型（2-3 天）
- 路径粒子
- Telegraph 可视化（Shader 驱动的预警区域）
- Rim Glow 边缘发光

### Phase 5：性能优化与收尾（1-2 天）
- 池大小调优
- Shader 性能验证
- 文档更新

---

## 4. 下一步行动建议

### 4.1 方案评审
- 人类审阅 `vfx-system-overhaul-proposal-2026-05.md`
- 确认 Phase 优先级和范围
- 决定是否调整验收标准

### 4.2 AI 执行团队分配建议
| Agent | 负责 Phase | 前置条件 |
|-------|-----------|---------|
| Agent A | Phase 1（Shader 基础设施） | 无 |
| Agent B | Phase 3（SkillVisualDef 重构） | 无（可与 Phase 1 并行） |
| Agent C | Phase 2（命中特效升级） | Phase 1 完成 |
| Agent D | Phase 4（新特效类型） | Phase 1 + 2 完成 |
| 主 Agent | Phase 5（协调收尾） | 全部完成 |

### 4.3 注意事项
- Phase 1 和 Phase 3 可以完全并行执行（无依赖）
- Phase 2 的 Task 2.1（HitVFXPool）和 Task 2.2（Executor 策略模式）有顺序依赖
- Phase 2 的 Task 2.3-2.6（各执行器实现）可以并行
- 所有 Shader 必须在 Godot 移动渲染器下验证
- SkillVisualDef 重构需要提供向后兼容层，避免破坏现有 .tres

---

## 5. 关键技术决策记录

| 决策 | 理由 |
|------|------|
| Shader 作为可选层叠加，不改现有渲染管线 | 最小侵入原则，现有特效在无 Shader 时仍可工作 |
| VFXLayerDef.kind 从 int 改为 StringName | 支持动态查找，新增 kind 无需改 match 分发 |
| 命中特效节点挂在场景树 VFXLayer 下，而非 scene.root | 场景切换时可批量清理，避免内存泄漏 |
| SkillVisualDef 拆分为子 Resource 而非删除旧字段 | 向后兼容，渐进迁移 |
| Executor 策略模式替代 match 分发 | 新增特效只需新建文件 + 注册一行，无需改 Manager |

---

## 6. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-05-17 | 初稿：VFX 系统审计 + 改造方案设计 |
