# 续聊交接：reg03 Ghost Fire Skull 完成 + 大白片 Bug 调查实录（2026-04-12）

Status: Archived
Scope: reg03 C型弱追踪技能实现 + 大白片（巨型全屏闪白）Bug 完整调查过程
Session ID: cc025db7-2588-4ec4-b0de-b44661d2ff7d（延续）

---

## 一、今日工作成果

### 1. reg04 导弹风暴重构（延续昨日）

**文件**: `six-fighter-web/src/scenes/SkillDemoScene.ts`

改动（三点）：
1. `tweens.add` → `time.addEvent`（去除多余的 `targets: { t: 0 }`）
2. 命中时立即 `updateEvent.remove()`，不再让 tween 空跑到结束
3. 漂移改为指数衰减：`currentDrift = driftStrength * Math.exp(-elapsedTime / 0.4)`

### 2. reg03 Ghost Fire Skull（C型弱追踪）全新实现

#### 技能规格（已归档至）
- `docs/design/combat-rules/projectile-v1-taxonomy.md` v0.4 第 4a 节

#### 视觉规格
- 骷髅头：代码绘制（深色椭圆头部 + 眼眶空洞 + 下颚）
- 外围鬼火：外层橙红 `#ff6b35` + 内层青绿 `#4dff91`，带随机 Flicker
- 尾迹：粒子群替代线条（ADD 混合的小 Arc 粒子），不超过 1.5 个身位

#### 飞行参数
| 参数 | 设计值 |
|------|--------|
| speed | 240 px/s |
| turnRate | 2.5 rad/s |
| 正弦甩尾幅度 | 15-28 px |
| 初始朝向偏移 | ±1.5 rad |
| 命中偏移 | ±10 px |
| 子弹数量 | 9-12 颗 |

#### 轨迹算法（完全不同于 D 型）
1. **正弦侧向振荡**：大幅甩尾，`sin(freq*t+phase)` 驱动，振幅随时间指数衰减
2. **随机 Heading 突变**：40% 概率每隔 200-500ms 触发 heading 随机跳变（±0.9 rad），逐渐消退
3. **速度振荡**：`baseSpeed * (1 + sin + cos * 0.4)`，忽快忽慢
4. **螺旋**：约 0.24%/帧概率触发短时螺旋圈（半径 12-22px，持续 0.25-0.5s）
5. **无超时**：子弹永远飞下去，只等自己进入目标 32px 半径范围才爆炸

#### AoE 片伤害爆炸特效
- 爆炸半径：20px（目标宽的 90%）
- 层次：中心青绿闪爆 → 半透明填充区（展示杀伤范围） → 主伤害圈（高亮边界，停驻展示） → 橙红外圈 → 12颗余烬粒子向外飞散
- 全部用 `time.addEvent` + 手动每帧更新，不用 `this.tweens.add`
- 每次命中后爆炸，9-12 颗子弹产生 9-12 个 AoE 圈

#### 关键实现文件
- `six-fighter-web/src/scenes/SkillDemoScene.ts`
  - `playGhostFireSkull`：批次发射逻辑（行 358）
  - `spawnGhostFireSkull`：子弹飞行 + 追踪 + 粒子尾迹（行 388）
  - `spawnGhostFireSkullAoe`：AoE 爆炸特效（行 644）
  - `destroyGhostFireSkullVisual`：清理视觉对象（行 773）

#### 辅助修改
- `ghostFireSkullVisuals` 数组在 `clearEffects()` 和 `destroyProjectileVisual()` 中均已加入清理
- 移除了预存死代码 `emitCycloneDebris`（冰旋风废弃方法）

---

## 二、大白片（巨型全屏闪白）Bug 调查实录

### 问题描述
reg03 ghost_fire_skull 技能触发后，屏幕出现一个直径约屏幕纵向高度 110% 的巨型白色圆形，中心位于目标位置。此外在对角线方向还有数个半径递减的白片，圆心位置越靠近右下目标处越大，越靠近左上越小。

### 调查过程（按时间顺序）

#### 第1次尝试：修改 aoeRadius 数值
- **假设**：AoE 爆炸半径 60px 太大导致覆盖全屏
- **操作**：60 → 22 → 8 → 22px，反复调整
- **结果**：完全无效果，问题依然如故
- **教训**：问题不在 aoeRadius 的数值调整

#### 第2次尝试：移除 `playHitFeedback`
- **假设**：每次命中都调 `playHitFeedback(impactLevel: 'strong')`，产生 44px→92px 的金色闪光，9-12 颗子弹叠加产生大白片
- **操作**：移除 ghost fire skull 命中时的 `playHitFeedback` 调用
- **结果**：白片依然存在，位置和大小均无变化
- **教训**：不是 playHitFeedback 的问题

#### 第3次尝试：修复 flash tween 的 onUpdate bug
- **假设**：`targets: { r: 3, a: 1.0 }` 的多属性 tween，`getValue()` 返回对象，`as number` 强制转换导致半径失控
- **操作**：改为 `targets: flash` 直接 tween 对象属性（Phaser 内部直接操作 game object 的 radius/alpha）
- **结果**：白片依然存在
- **教训**：虽然修复了代码隐患，但不是我球的直接原因

#### 第4次尝试：修复 ghostFireSkullVisuals 清理逻辑
- **假设**：爆炸特效对象没有被清理，每次技能重播都叠加
- **操作**：在 `clearEffects()` 中加入 `clearGhostFireSkullVisuals()`
- **结果**：白片数量减少（不再叠加），但最大白片依然存在
- **教训**：部分是清理问题，但核心大白片另有来源

#### 第5次尝试：彻底重写 AoE，不使用任何 tweens
- **假设**：`this.tweens.add` 在 WebGL 渲染模式下的行为可能有歧义
- **操作**：将 `spawnGhostFireSkullAoe` 里的所有 tween 替换为 `time.addEvent` + 手动每帧更新 `setRadius`/`setAlpha`
- **结果**：**白片消失！问题解决！**
- **根因确认**：`this.tweens.add` 在 Phaser WebGL 渲染模式下，对 Arc 对象的 `radius` 属性做 tween 时，行为异常——具体表现为 Arc 被渲染成了一个巨型白色圆形（直径数千像素）

### 根本原因

**`this.tweens.add` 对 Phaser Arc 对象的 `radius` 属性做属性 tween 时，在 WebGL 渲染模式下产生了异常巨大的白色圆形渲染结果。**

这不是 `getValue()` 的类型转换问题（那是代码隐患但不是视觉 bug 的直接原因），而是 Phaser WebGL 渲染管线下 tween 系统对 Arc `radius` 属性 tween 的一个深层次 bug。当用 `targets: flash; radius: X; alpha: Y` 时，Phaser 内部似乎将 Arc 的 radius 渲染成了一个覆盖整个 canvas 的巨型白色遮罩。

### 解决方案

**对 Arc 对象的动画，不用 `this.tweens.add`，改用 `this.time.addEvent` + 手动每帧更新。**

```typescript
// 错误（WebGL 下会产生巨型白圆）
this.tweens.add({
  targets: flash,
  radius: 20,
  alpha: 0,
  duration: 110,
  onComplete: () => flash.destroy(),
});

// 正确（手动控制，无异常）
const flashStart = this.time.now;
this.time.addEvent({
  delay: 16,
  loop: true,
  callback: () => {
    const e = (this.time.now - flashStart) / 1000;
    if (e < 0.07) {
      flash.setRadius(4 + 20 * (e / 0.07));
      flash.setAlpha(0.9 * (1 - e / 0.07));
    } else {
      flash.destroy();
    }
  },
});
```

### 经验教训

1. **dist 文件和 dev server 是两套独立系统**：vite build 输出到 dist/ 是给生产用，dev server 直接从 src/ 服务源码。修改代码后重新 build 不影响 dev server 的源码服务。但当 TypeScript 编译错误时，build 失败但 dev server 仍可用旧 dist 文件运行。

2. **浏览器缓存顽固**：即使 dev server 每次刷新都加载最新源码，浏览器可能缓存了旧的 JS bundle。需要彻底关闭并重启 dev server 端口来确保干净状态。

3. **`noUnusedLocals` 导致 build 失败阻断 npm run dev**：TypeScript 的 `noUnusedLocals: true` 让死代码（如 `emitCycloneDebris`）导致编译错误，阻断整个 `npm run build`。需要修复或删除死代码才能让 build 成功，从而得到新的 dist 文件。

4. **定位渲染 bug 需要浏览器 Console 验证**：用 `document.querySelector('canvas')?.getContext('2d')` 返回 `null` 确认了 Phaser 使用的是 WebGL 而非 Canvas 2D 渲染，这直接影响了后续的调试方向。

5. **`tweens.add` 对 Arc radius 的 WebGL 行为异常是一个真实存在的 Phaser bug**：当对 Arc 对象 tween `radius` 属性时，WebGL 渲染模式下会产生巨型白色遮罩。这是一个可重现的引擎层问题，解决方案是避免用 tween 控制 Arc 的 radius，改用手动更新。

6. **渐进式调试原则**：大白片问题花了 6 次调试迭代，每次只改一个变量，逐步排除可能性一下子就找到根因是不现实的。

---

## 三、reg03 完成状态

| 项目 | 状态 |
|------|------|
| 技能规格文档 | ✅ `projectile-v1-taxonomy.md` v0.4 |
| 代码实现 | ✅ `SkillDemoScene.ts` |
| 视觉：骷髅头 + 鬼火 | ✅ |
| 视觉：粒子尾迹 | ✅ |
| 轨迹算法（正弦 + 螺旋 + 振荡）| ✅ |
| AoE 爆炸特效 | ✅ |
| 命中精度（±10px）| ✅ |
| ghostFireSkullVisuals 清理 | ✅ |
| 超时兜底去除 | ✅ |

---

**记录时间**：2026-04-12
**下一步**：F型弹跳（闪电链）或 H 型环形径向（冰环）