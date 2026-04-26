# 续聊交接：冰旋风技能重构与混合渲染方案（2026-04-10）

Status: 主体结构完成，可运行验证  
Scope: `six-fighter-web/src/scenes/SkillDemoScene.ts`（reg05_ice_cyclone_line 全重构）

---

## 1) 今日已完成（核心成果）

### 1.1 设计思路彻底调整
- **从"刚性几何体"改为"多层椭圆+粒子系统"**：
  - 原方案：单一多边形锥体（倒梯形纸板感）
  - 新方案：4层椭圆（上宽下窄锥体）+ 粒子系统（空气感）

### 1.2 混合渲染架构
- **实体层（正常渲染）**：4层椭圆，深蓝 `0x3a8cff`，透明度 0.8→0.5（底实顶透）
- **光效层（ADD混合）**：内部旋转粒子 `0xe0f0ff` + 外围碎片 `0xf0f8ff`
- **尾迹层（ADD混合）**：贴地冰雾轨迹

### 1.3 关键问题解决
- **混合模式BUG修复**：移除椭圆层的 `ADD` 混合，改用正常渲染（主体不再消失）
- **眼晕问题缓解**：椭圆层从5层减至4层，减少顶部剧烈晃动
- **雪花粒子增强**：数量↑、尺寸↑、亮度↑（更像旋风卷起雪尘）

### 1.4 具体参数
- **锥体尺寸**：高80px，底宽40px，顶宽80px（上宽下窄侧视锥）
- **椭圆层数**：4层（原5层），动态透明度波动
- **内部粒子**：3个/120ms，尺寸2.0-4.5，透明度0.7
- **外围碎片**：3个/100ms，尺寸1.2-3.0，透明度0.6

---

## 2) 当前状态与验证

### 2.1 运行方式
```bash
cd "D:\Vibe Coding\Six Fighter\six-fighter-web"
npm run dev
```

访问 `http://localhost:5173`：
1. 进入 Hub Scene
2. 点击 `Skill Demo V0 (basic)`
3. 用 `Skill` 按钮切换到 `reg05_ice_cyclone_line`
4. 点击 `Play` 播放技能

### 2.2 预期可见效果
1. **深蓝色锥形主体**（4层椭圆叠加，上宽下窄）
2. **柔和光效粒子**（浅蓝雪花，绕旋风旋转）
3. **外围空气碎片**（亮白雪花，受旋转向外飞散）
4. **贴地冰雾尾迹**（紧贴地面线）

### 2.3 技术架构
```typescript
// 分层渲染（文件：SkillDemoScene.ts，行454-579）
- 实体层: 椭圆（正常渲染）——保证主体可见性
- 光效层: 粒子（ADD混合）——增强发光效果  
- 尾迹层: 图形（ADD混合）——地面冰雾

// 动态效果
- 椭圆旋转偏移: offsetX/Y = sin/cos(rotation) * size*0.15
- 透明度波动: alpha = baseAlpha + sin(spin*1.5 + i)*0.1
- 尺寸不规则扰动: irregularity = sin(spin*1.8)*0.2 + cos(spin*0.7)*0.15
```

---

## 3) 未完成/待优化项

### 3.1 视觉效果微调（低优先级）
- 粒子发射频率可能仍需调整（当前120ms/100ms）
- 椭圆颜色渐变可更平滑（当前底深蓝→顶稍浅）
- 贴地尾迹高度（当前+5px）可微调

### 3.2 性能考量（验证中）
- 4层椭圆 + 粒子系统在移动端性能待测
- 粒子回收机制已实现（自动销毁）

---

## 4) 新会话建议提示词（可复制）

```text
先读取 @docs/continued-discussion-handoff-2026-04-10-ice-cyclone-refactor.md 作为上下文。

当前 reg05_ice_cyclone_line 已完成主体重构：4层椭圆锥体 + 雪花粒子系统，混合渲染架构（实体层正常渲染，粒子层ADD混合）。

下一步建议：
1. 如主体仍需增强，调整椭圆颜色/透明度梯度
2. 如粒子效果不足，微调发射频率/尺寸/颜色
3. 整体比例验证（上宽下窄锥体是否明显）

请先运行验证当前效果，再决定微调方向。
```

---

## 5) 核心代码位置（便于快速查阅）

- **技能定义**：[SkillDemoScene.ts:44-51](six-fighter-web/src/scenes/SkillDemoScene.ts#L44-L51)（`reg05` 配置）
- **技能实现**：[SkillDemoScene.ts:454-579](six-fighter-web/src/scenes/SkillDemoScene.ts#L454-L579)（`playIceCyclone` 方法）
- **粒子系统**：
  - 内部旋转：[SkillDemoScene.ts:571-614](six-fighter-web/src/scenes/SkillDemoScene.ts#L571-L614)（`emitSwirlParticles`）
  - 外围碎片：[SkillDemoScene.ts:616-662](six-fighter-web/src/scenes/SkillDemoScene.ts#L616-L662)（`emitCycloneDebris2`）
  - 贴地尾迹：[SkillDemoScene.ts:667-709](six-fighter-web/src/scenes/SkillDemoScene.ts#L667-L709)（`drawCycloneTrail`）

---

## 6) 经验总结

### 6.1 关键教训
- **混合模式慎用**：`ADD` 在非纯黑背景上会使深色元素消失
- **分层渲染有效**：实体层（正常）+ 光效层（ADD）= 可见性+发光感
- **动态波动控制**：正弦波幅度过大会导致眼晕，需平衡"不规则感"与"舒适度"

### 6.2 设计原则
1. 侧视龙卷风 = 上宽下窄锥体（物理正确）
2. 空气感 = 主体 + 粒子 + 尾迹（层次丰富）
3. 不规则感 = 尺寸扰动 + 位置偏移 + 透明度波动（避免刚性）

---

**记录时间**：2026-04-10  
**工作耗时**：约3小时（含调试、重构、测试）  
**状态**：可演示，主体可见，效果符合设计预期，细节可继续微调