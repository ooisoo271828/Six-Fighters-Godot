---
name: sprite-rendering-order
description: 后添加的 Sprite 渲染在上层。宽段必须后添加否则被窄段遮盖。递缩段的 alpha 与宽度正相关。
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bc79e782-1c8a-48ad-8dcd-6daf37732708
---

### 渲染顺序
Godot 中后添加的子节点渲染在上层。多段叠加时：
- 宽段（80%）必须后添加（上层），否则被窄段遮盖中心
- 窄段（20%）先添加（下层）

从窄到宽添加：`add_child(20%) → 40% → 60% → 80%`

### 递缩 alpha 策略
阶梯递缩结构中 alpha 与宽度正相关：
```
段1 80% 宽度 → alpha 最高（最清晰）
段4 20% 宽度 → alpha 最低（最淡出）
```

### 扩展区位置
光束扩展区（从窄到宽的过渡）覆盖在光柱体末端内部，不延伸到体外。Sprite 用 centered=false，position.y = -width/2 居中。

**Why:** 大激光术技能的基座段调试中，因渲染顺序和 alpha 策略反复出错多次才修正。
**How to apply:** 设计多层叠加视觉效果时，先画出截面图，标注每层的宽度、alpha、z-order，再编码。
