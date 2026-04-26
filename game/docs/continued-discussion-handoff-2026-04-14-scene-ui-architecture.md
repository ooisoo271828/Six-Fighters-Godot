# 交接文档：场景管理与 UI 管理架构重构

**日期**: 2026-04-14
**会话ID**: session-architecture-refactor-2026-04-14
**状态**: 已归档

---

## 一、本次工作概要

本次重构为 P0 级别，解决了场景管理和 UI 管理中的架构性问题，消除了之前版本中的多处设计隐患。

### 1.1 新增模块

| 文件 | 说明 |
|------|------|
| `src/core/GameState.ts` | 全局状态单例，替代散乱的 registry.get/set |
| `src/core/EventBus.ts` | 统一事件总线，命名空间分类规范 |

### 1.2 重构模块

| 文件 | 主要改动 |
|------|---------|
| `src/core/SceneRouter.ts` | 接入 GameState + EventBus |
| `src/scenes/BootScene.ts` | 通过 EventBus 监听导航请求 |
| `src/scenes/UIOverlayScene.ts` | 订阅 GameState.uiMode，通过 EventBus 发出导航请求 |
| `src/scenes/BaseTownScene.ts` | 通过 EventBus 接收输入，发送就绪事件 |
| `src/scenes/ArenaScene.ts` | **移除独立摇杆**，复用统一输入 |

### 1.3 构建状态

```
✅ npm run build — 成功
✅ npm run dev — 成功（端口 5177）
✅ TypeScript 检查 — 通过
```

---

## 二、新架构详解

### 2.1 核心原则

**原则 1：所有场景切换必须经过 SceneRouter**
```
❌ 禁止：this.scene.start('ArenaScene')
✅ 正确：EventBus.emit(Events.Scene.RequestNav, SceneKeys.Arena)
```

**原则 2：通过 EventBus 通信，禁止直接引用其他场景**
```
❌ 禁止：const scene = this.scene.get('BaseTownScene'); scene.doSomething();
✅ 正确：EventBus.emit(Events.Scene.RequestNav, key)
```

**原则 3：状态读写通过 GameState**
```
❌ 禁止：this.registry.get('currentScene')
✅ 正确：GameState.currentScene
```

### 2.2 GameState 状态定义

```typescript
// src/core/GameState.ts
interface GameStateSnapshot {
  currentScene: SceneKey;                    // 当前活动场景
  uiMode: 'base-town' | 'arena' | 'skill-demo' | 'sprite-viewer' | 'hub';
  squadPosition: { x: number; y: number };  // 小队位置
  heroRoster: HeroId[];                     // 英雄列表
  encounterSeed: number;                   // 战斗随机种子
}
```

**订阅状态变化**：
```typescript
const off = GameState.subscribe('uiMode', (mode) => {
  console.log('UI模式变为:', mode);
});
// 在 shutdown() 中调用 off() 取消订阅
```

### 2.3 EventBus 事件列表

```typescript
// 场景管理
Events.Scene.RequestNav   // 请求切换场景（参数：SceneKey）
Events.Scene.Changed      // 场景切换完成（参数：{ from, to }）
Events.Scene.Ready        // 场景就绪（参数：{ sceneKey, data? }）

// UI 层
Events.UI.ModeChange      // UI 模式变化（参数：UIMode）
Events.UI.Joystick       // 摇杆输入（参数：{ dx, dy }）
Events.UI.JoystickStop   // 摇杆停止

// 战斗
Events.Combat.Victory    // 战斗胜利
Events.Combat.Defeat     // 战斗失败
Events.Combat.WaveStart  // 波次开始
```

**使用示例**：
```typescript
import { EventBus, Events } from '../core/EventBus';

// 订阅
EventBus.on(Events.UI.Joystick, (raw) => {
  const { dx, dy } = raw as { dx: number; dy: number };
  // 处理...
});

// 触发
EventBus.emit(Events.Scene.RequestNav, SceneKeys.Arena);

// 取消订阅
const off = EventBus.on(Events.Scene.Ready, handler);
off(); // 在 shutdown 中调用
```

### 2.4 SceneRouter 职责

```typescript
class SceneRouter {
  // 设置初始场景（BootScene 调用一次）
  setInitialScene(key: SceneKey): void;

  // 唯一的场景切换入口
  navigateTo(targetKey: SceneKey, data?: object): void;

  // 返回基地
  returnToHub(): void;
}
```

**navigateTo 内部流程**：
1. 获取当前场景 fromKey
2. 如果 fromKey !== targetKey，停止当前场景
3. 启动目标场景
4. 更新 GameState（currentScene + uiMode）
5. 触发 Events.Scene.Changed 和 Events.UI.ModeChange

---

## 三、UIOverlayScene 设计

### 3.1 基本信息

- **类型**：常驻叠加层
- **启动方式**：`this.scene.launch(UIOverlayScene)` — launch，不关闭自己
- **生命周期**：
  - `create()` — 初始化 UI 组件，设置事件监听
  - `shutdown()` — 清理所有 EventBus 订阅（重要！）

### 3.2 UI 可见性规则

| UIMode | 虚拟摇杆 | 调试按钮 | 返回按钮 |
|--------|---------|---------|---------|
| `base-town` | ✅ 显示 | ✅ 显示 | ❌ 隐藏 |
| 其他 | ❌ 隐藏 | ❌ 隐藏 | ✅ 显示 |

### 3.3 输入处理

摇杆输入处理流程：
```
用户操作摇杆
    ↓
UIOverlayScene 检测 pointerdown/move/up
    ↓
EventBus.emit(Events.UI.Joystick, { dx, dy })
    ↓
活动游戏场景（BaseTownScene/ArenaScene）接收并移动
    ↓
用户释放
    ↓
EventBus.emit(Events.UI.JoystickStop)
    ↓
活动游戏场景停止移动
```

---

## 四、场景切换流程

### 4.1 BaseTown → Arena

```
1. UIOverlayScene 点击"Test Arena"
        ↓
2. EventBus.emit(Events.Scene.RequestNav, SceneKeys.Arena)
        ↓
3. BootScene 收到，调用 router.navigateTo(Arena)
        ↓
4. SceneRouter:
   - scene.stop(BaseTownScene)
   - scene.start(ArenaScene)
   - GameState.currentScene = Arena
   - GameState.uiMode = 'arena'
   - EventBus.emit(Scene.Changed)
   - EventBus.emit(UI.ModeChange, 'arena')
        ↓
5. UIOverlayScene 收到 uiMode 变化，隐藏摇杆、显示返回按钮
```

### 4.2 Arena → BaseTown（EXIT 按钮）

同上流程，UIOverlayScene 点击 EXIT → RequestNav(BaseTown)

### 4.3 Arena → BaseTown（战斗结束点击）

```
ArenaScene.showEnd()
    ↓
EventBus.emit(Events.Scene.RequestNav, SceneKeys.BaseTown)
    ↓
后续流程同上
```

---

## 五、已知问题 / TODO

### 5.1 未完成项

| 优先级 | 项目 | 说明 |
|--------|------|------|
| P1 | TransitionEffects.fade | 当前只有 'none'，未实现淡入淡出 |
| P2 | UIOverlayScene 组件化 | 当前约 500 行，可拆分为 Joystick/InfoPanel/ReturnButton 等组件 |
| P2 | InputManager | 摇杆绑定在 UIOverlayScene，应独立出来 |

### 5.2 遗留事件未完全连接

以下事件已定义但 UI 层未响应：
- `Events.Combat.Victory`
- `Events.Combat.Defeat`
- `Events.Combat.WaveStart`

战斗胜利/失败时只触发了 EventBus，UIOverlayScene 未显示对应提示。

---

## 六、测试验证

### 6.1 需验证的流程

1. **基地移动** — 摇杆控制小队移动
2. **基地 → 竞技场** — 点击"Test Arena"按钮
3. **竞技场内移动** — 摇杆控制（复用了 UIOverlayScene 的摇杆）
4. **竞技场 → 基地（EXIT）** — 点击右上角橙色 EXIT 按钮
5. **竞技场 → 基地（战斗结束）** — 胜利/失败后点击返回

### 6.2 验证命令

```bash
cd six-fighter-web
npm run dev
# 浏览器打开 http://localhost:5177/
```

---

## 七、重要教训

### 7.1 start() vs launch() 的关键差异

> 来源：`docs/tech/incident-bluebook-return-button-2026-04-14.md`

| API | 行为 |
|-----|------|
| `this.scene.start(key)` | **关闭调用者自身**，再启动目标 |
| `this.scene.launch(key)` | 只启动目标，调用者继续运行 |

**后果**：UIOverlayScene 如果用 `start()` 切换场景，会把自己关掉，按钮全部消失。

### 7.2 调试原则

在调试"不工作"的问题时，**先问"它还在不在"**，而不是问"它为什么不工作"。

详见：`docs/tech/incident-bluebook-return-button-2026-04-14.md`

---

## 八、延伸阅读

| 文档 | 内容 |
|------|------|
| `docs/tech/scene-ui-management-architecture-2026-04-14.md` | 完整技术架构文档 |
| `docs/tech/incident-bluebook-return-button-2026-04-14.md` | 大白片 Bug 调查报告 |
| `docs/continued-discussion-handoff-2026-04-12-*.md` | 技能实现交接文档 |

---

*本文档为交接文档，下一会话请优先阅读本文件了解当前架构状态。*
