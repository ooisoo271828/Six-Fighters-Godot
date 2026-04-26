# 场景管理与 UI 管理架构文档

**文件编号**: SIXFIGHTER-TECH-001
**日期**: 2026-04-14
**状态**: 已归档
**版本**: v1.0

---

## 一、架构概述

本项目采用 Phaser 3 游戏引擎，场景系统和 UI 系统解耦设计。

### 1.1 核心模块

| 模块 | 文件路径 | 职责 |
|------|---------|------|
| SceneKeys | `src/core/SceneKeys.ts` | 场景键名常量，禁止字符串字面量 |
| SceneRouter | `src/core/SceneRouter.ts` | 集中式场景切换，所有切换必经此路由 |
| GameState | `src/core/GameState.ts` | 全局状态单例，唯一的全局状态来源 |
| EventBus | `src/core/EventBus.ts` | 统一事件总线，跨场景通信中枢 |
| TransitionEffects | `src/core/TransitionEffects.ts` | 场景过渡效果配置（当前仅 'none'） |

### 1.2 场景列表

| 场景键名 | 类名 | 用途 |
|---------|------|------|
| `BootScene` | BootScene | 启动场景，负责初始化和数据加载 |
| `BaseTownScene` | BaseTownScene | 基地城镇，探索模式主场景 |
| `ArenaScene` | ArenaScene | 竞技场，战斗模式主场景 |
| `SkillDemoScene` | SkillDemoScene | 技能演示器 |
| `SpriteViewerScene` | SpriteViewerScene | 精灵查看器 |
| `UIOverlayScene` | UIOverlayScene | UI 叠加层，常驻始终存活 |
| `HubScene` | HubScene | 中心枢纽（已废弃，保留但未使用） |

---

## 二、GameState 全局状态

### 2.1 设计目的

在本次重构（2026-04-14）之前，游戏状态分散在：
- `Phaser.Scene.registry`
- 各场景实例属性
- UIOverlayScene 的 `currentMode` 状态

这种分散管理导致状态同步困难、难以追踪。GameState 作为**唯一的全局状态来源**，所有模块都可以订阅状态变化。

### 2.2 状态定义

```typescript
// src/core/GameState.ts
interface GameStateSnapshot {
  currentScene: SceneKey;           // 当前活动场景
  uiMode: UIMode;                   // UI 模式
  squadPosition: { x: number; y: number };  // 小队位置
  heroRoster: HeroId[];             // 英雄列表
  encounterSeed: number;            // 战斗随机种子
}

type UIMode = 'base-town' | 'arena' | 'skill-demo' | 'sprite-viewer' | 'hub';
```

### 2.3 订阅机制

```typescript
// 订阅状态变化
const unsubscribe = GameState.subscribe('currentScene', (newValue, oldValue) => {
  console.log(`场景切换: ${oldValue} -> ${newValue}`);
});

// 取消订阅
unsubscribe();
```

### 2.4 UIMode 与场景的映射

| SceneKey | UIMode |
|----------|--------|
| BaseTown | `base-town` |
| Arena | `arena` |
| SkillDemo | `skill-demo` |
| SpriteViewer | `sprite-viewer` |
| Hub | `hub` |

---

## 三、EventBus 统一事件总线

### 3.1 设计目的

跨场景、跨模块通信的规范通道。避免直接引用其他场景实例（`this.scene.get(key)` 的 try-catch 满天飞）。

### 3.2 事件命名空间

```typescript
// src/core/EventBus.ts

Events.Scene.RequestNav   // 请求切换场景（数据：SceneKey）
Events.Scene.Changed      // 场景切换完成（数据：{ from, to }）
Events.Scene.Ready        // 场景初始化完成（数据：{ sceneKey, data? }）

Events.UI.ModeChange      // UI 模式变化（数据：UIMode）
Events.UI.Joystick        // 摇杆输入（数据：{ dx, dy }）
Events.UI.JoystickStop    // 摇杆停止
Events.UI.InfoMessage     // 添加信息消息（数据：string）

Events.Combat.WaveStart   // 波次开始
Events.Combat.WaveEnd     // 波次结束
Events.Combat.Victory     // 战斗胜利
Events.Combat.Defeat      // 战斗失败

Events.Unit.SquadPosition // 小队位置更新
Events.Unit.RosterChange  // 英雄列表变化
```

### 3.3 使用方式

```typescript
import { EventBus, Events } from '../core/EventBus';

// 订阅
const off = EventBus.on(Events.UI.Joystick, (raw) => {
  const { dx, dy } = raw as { dx: number; dy: number };
  // 处理...
});

// 触发
EventBus.emit(Events.Scene.RequestNav, SceneKeys.Arena);

// 取消订阅
off();

// 一次性订阅
EventBus.once(Events.Combat.Victory, () => {
  // 只触发一次后自动取消
});
```

### 3.4 注意事项

- EventBus 的回调参数类型是 `unknown`，调用方需要自行类型断言
- 在 emit 回调中修改同一事件的订阅者（添加/删除）是安全的
- `once` 会在触发后自动取消订阅

---

## 四、SceneRouter 场景路由器

### 4.1 设计原则

**所有场景切换必须经过 SceneRouter**，游戏场景禁止直接调用 `this.scene.start/launch/stop`。

### 4.2 核心方法

```typescript
class SceneRouter {
  /** 设置初始场景（由 BootScene 在启动完成后调用） */
  setInitialScene(key: SceneKey): void;

  /** 导航到目标场景（唯一的场景切换入口） */
  navigateTo(targetKey: SceneKey, data?: object): void;

  /** 返回基地场景 */
  returnToHub(): void;

  /** 获取当前场景键名 */
  getCurrentSceneKey(): SceneKey;

  /** 获取当前 UI 模式 */
  getCurrentUIMode(): UIMode;
}
```

### 4.3 切换流程

```
调用 navigateTo(target)
    ↓
1. 获取当前场景 fromKey
2. 如果 fromKey !== targetKey，停止当前场景
3. 确保目标场景已停止
4. 启动目标场景：this.game.scene.start(targetKey, data)
5. 更新 GameState.currentScene
6. 更新 GameState.uiMode
7. 触发 Events.Scene.Changed 通知
8. 触发 Events.UI.ModeChange 通知
9. 确保 UIOverlayScene 在最上层
```

### 4.4 关键 API 差异（历史教训）

> **大白片 Bug（2026-04-13 ~ 2026-04-14）**：十余次修复未果，最终发现根因是 `this.scene.start()` 会**关闭调用者自身**，而 `this.scene.launch()` 不会。
>
> 教训来源：`docs/tech/incident-bluebook-return-button-2026-04-14.md`
>
> 结论：切换到其他游戏场景时使用 `this.scene.launch()`，场景管理器会保持调用者存活。

| API | 行为 |
|-----|------|
| `scene.start(key)` | 先停止调用者自身，再启动目标 |
| `scene.launch(key)` | 只启动目标，调用者继续运行 |

当前 SceneRouter 内部统一使用 Phaser SceneManager 的标准 API，确保行为一致。

---

## 五、UIOverlayScene 设计

### 5.1 职责

UIOverlayScene 是一个**常驻叠加层**，同一时刻只有一个实例存活，所有游戏场景共享。

职责清单：
- 虚拟摇杆输入处理
- 信息面板管理
- 调试按钮渲染
- 返回按钮渲染
- UI 模式切换（通过订阅 GameState.uiMode）

### 5.2 生命周期

```
BootScene
    └── this.scene.launch(UIOverlayScene)  ← launch，不关闭自己
            ↓
    UIOverlayScene.create()
            ↓
    游戏过程中始终存活
            ↓
    shutdown() ← 场景被完全销毁时调用，清除所有 EventBus 订阅
```

### 5.3 UI 可见性规则

| UIMode | 虚拟摇杆 | 调试按钮 | 返回按钮 |
|--------|---------|---------|---------|
| `base-town` | 显示 | 显示 | 隐藏 |
| 其他 | 隐藏 | 隐藏 | 显示 |

### 5.4 与游戏场景的通信

```
UIOverlayScene                    BaseTownScene / ArenaScene
      │                                    │
      ├── emit(Events.UI.Joystick) ──────►│  接收移动输入
      ├── emit(Events.UI.JoystickStop) ───►│  接收停止指令
      │                                    │
      │◄─── emit(Events.Scene.Ready) ─────┤  场景就绪通知
      │                                    │
      │◄─── emit(Events.Scene.Changed) ────┤  场景切换通知
```

---

## 六、场景切换流程详解

### 6.1 从 BaseTown → Arena

```
1. 用户点击"Test Arena"按钮（UIOverlayScene）
       ↓
2. UIOverlayScene: EventBus.emit(Events.Scene.RequestNav, SceneKeys.Arena)
       ↓
3. BootScene: EventBus.on(Events.Scene.RequestNav, ...) 收到
       ↓
4. BootScene: router.navigateTo(SceneKeys.Arena)
       ↓
5. SceneRouter:
   - scene.stop(BaseTownScene)
   - scene.start(ArenaScene)
   - GameState.setCurrentScene(Arena)
   - GameState.setUIMode('arena')
   - EventBus.emit(Events.Scene.Changed, { from: 'BaseTownScene', to: 'ArenaScene' })
   - EventBus.emit(Events.UI.ModeChange, 'arena')
       ↓
6. UIOverlayScene: GameState.subscribe('uiMode', ...) 收到，隐藏摇杆、显示返回按钮
```

### 6.2 从 Arena → BaseTown（点击 EXIT）

```
1. 用户点击"EXIT"按钮（UIOverlayScene）
       ↓
2. UIOverlayScene: EventBus.emit(Events.Scene.RequestNav, SceneKeys.BaseTown)
       ↓
3. 同 6.1 的 3-6 步
```

### 6.3 从 Arena → BaseTown（战斗结束点击返回）

```
1. 战斗胜利/失败，显示"Tap to return to Base"
       ↓
2. 用户点击 tapText
       ↓
3. ArenaScene: EventBus.emit(Events.Scene.RequestNav, SceneKeys.BaseTown)
       ↓
4. 同 6.1 的 3-6 步
```

---

## 七、架构演进记录

### v1.0 (2026-04-14) — 当前版本

**变更内容**：

1. 新增 GameState 单例（`src/core/GameState.ts`）
   - 替代分散的 registry.get/set
   - 支持订阅状态变化

2. 新增 EventBus 统一事件总线（`src/core/EventBus.ts`）
   - 规范事件命名空间
   - 支持订阅、一次性订阅、取消订阅

3. 重构 SceneRouter
   - 接入 GameState 和 EventBus
   - 所有切换统一通过 navigateTo()

4. 重构 UIOverlayScene
   - 移除 router 引用，改为订阅 GameState
   - 通过 EventBus 发出导航请求
   - 正确实现 shutdown() 清理订阅

5. 重构 BaseTownScene
   - 通过 EventBus 接收摇杆输入
   - 发送场景就绪事件

6. 重构 ArenaScene
   - **移除独立摇杆实现**，复用 UIOverlayScene 的统一摇杆
   - 通过 EventBus 接收摇杆输入
   - 通过 EventBus 请求返回基地

**遗留问题（TODO）**：

- [ ] TransitionEffects 未实现 fade 效果，当前只有 'none'
- [ ] UIOverlayScene 单文件仍然较大（~500 行），可进一步组件化
- [ ] InputManager 输入中枢未建立（摇杆绑定在 UIOverlayScene 中）
- [ ] 战斗相关事件（Victory/Defeat）未完全连接到 UI 层

### 早期版本

详见各交接文档：
- `docs/continued-discussion-handoff-2026-04-12-*.md`
- `docs/incident-bluebook-return-button-2026-04-14.md`

---

## 八、开发者指南

### 8.1 新增一个场景

1. 在 `src/core/SceneKeys.ts` 添加键名常量
2. 在 `src/scenes/` 创建场景类，继承 `Phaser.Scene`
3. 在 `src/main.ts` 的 `scene: []` 数组中添加
4. 如果需要切换：在 `UIOverlayScene` 或其他场景中 `EventBus.emit(Events.Scene.RequestNav, YourSceneKey)`

### 8.2 在场景间通信

```typescript
// 发送事件
EventBus.emit(Events.YourEvent, yourData);

// 接收事件
const off = EventBus.on(Events.YourEvent, (raw) => {
  const data = raw as YourDataType;
  // 处理...
});

// 在 shutdown() 中清理
shutdown() {
  off();
}
```

### 8.3 订阅 GameState 变化

```typescript
// 在 create() 中订阅
const off = GameState.subscribe('uiMode', (mode) => {
  this.onUIModeChange(mode);
});

// 在 shutdown() 中取消
shutdown() {
  off();
}
```

---

## 九、调试命令

### 9.1 查看当前状态

在浏览器控制台执行：

```javascript
// 获取 GameState 快照
window.__PHASER_GAME__?.scene.scenes.forEach(s => {
  if (s.registry) console.log(s.scene.key, s.registry.list?.());
});

// 读取 GameState（需要暴露到全局）
```

### 9.2 查看活跃事件

```typescript
// 在 EventBus 中添加调试代码
console.log(EventBus.listEvents());
```

---

*本文档为团队技术传承文件，后续开发者请优先阅读此文档了解架构。*
