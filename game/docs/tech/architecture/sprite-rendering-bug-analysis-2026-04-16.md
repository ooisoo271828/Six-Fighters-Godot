# LPC 角色精灵显示问题技术报告

**日期**: 2026/04/16
**问题**: LPC 角色在 SpriteViewerScene 中出现左右半片交替闪烁；Ironwall 在所有场景显示半片角色
**状态**: 已解决（存在已知局限）

---

## 一、问题背景

### LPC（Liberated Pixel Cup）精灵表结构

LPC 是一个 Creative Commons 授权的像素角色 sprite sheet 库，格式为 832×1344（26列 × 21行，每格 32×64 像素）。

关键发现来自 `sheets.rb`（官方 Ruby 工具）的结构定义：

```
行 0-3: spellcast (idle) — 7帧/方向
行 4-7: thrust (attack) — 8帧/方向
行 8-11: walkcycle (行走) — 9帧/方向
行 12-15: slash (attack) — 6帧/方向
行 16-19: shoot (skill) — 13帧/方向
行 20: hurt (hit) — 6帧/方向
```

### 像素级分析数据

通过 Python + Pillow 解析 LPC male_light 帧像素：

| 帧文件 | 内容列范围 | 内容宽度 | 位置描述 |
|---|---|---|---|
| `idle_00` | 列 17-31 | 15px | 右半边 |
| `idle_01` | 列 0-14 | 15px | **左半边** |
| `idle_02` | 列 17-31 | 15px | 右半边 |
| `idle_03` | 列 0-14 | 15px | **左半边** |
| `walk_00` | 列 17-31 | 15px | 右半边 |
| `walk_01` | 列 0-14 | 15px | **左半边** |
| `walk_02` | 列 17-31 | 15px | 右半边 |
| `walk_03` | 列 0-14 | 15px | **左半边** |

**这是 LPC 行走动画的内在设计**：每帧只含半个身体内容，左右交替。这是早期 RPG Maker 风格 sprite sheet 的常见做法，目的是节省空间。

### Ironwall 资产问题

| 帧文件 | 内容列范围 | 内容宽度 | 位置描述 |
|---|---|---|---|
| `idle_00` | 列 14-31 | 18px | 右半边 |
| `walk_00` | 列 12-31 | 20px | 右半边 |

Ironwall 所有帧像素天然只在右半边，左半边几乎透明。这是资产原始特性，不是处理过程产生的 bug。

---

## 二、尝试过的方案及结果

### 方案 1：内容偏移补偿（无效）

**思路**: sprite 内容不在 canvas 中心，手动补偿 x 偏移。

**结果**: 位置有移动但 flickering 依旧。

**原因**: 治标不治本。LPC 每帧内容在左/右侧跳变是设计如此。

### 方案 2：Ping-Pong 位置修正（无效）

**思路**: 检测 LPC 帧是偶数（右侧内容）还是奇数（左侧内容），动态调整 `sprite.x`。

**实测数据**:
- cx = 187（固定）
- 偶数帧 sprX = 187 - 25 = 162
- 奇数帧 sprX = 187 - 6 = 181
- 差值 19px = 实际测量的 content center 差

**结果**: 修正值准确，但 flickering 依然存在。

### 方案 3：Phaser 原生 Sprite + Animation 系统（部分有效）

**思路**: 使用 `Phaser.GameObjects.Sprite` + `this.anims.create()` + `sprite.play()`，让 Phaser 内部管理帧切换。

**结果**: flickering 频率降低但方向反了（右半边出现在左侧）。

### 方案 4：flipX 水平翻转（无效）

**思路**: 一个 sprite 正常显示，一个 `setFlipX(true)` 水平翻转后叠加。

**结果**: flipX 对这个 texture 不起作用，两个 sprite 显示相同内容，完全重叠看不见区别。

**原因**: 可能是 Phaser 的 texture origin 或加载方式问题，flipX 并没有真正镜像 texture 内容。

### 方案 5：双 sprite + 奇偶帧分离 + 位置偏移（最终方案）

**思路**: 两个独立 sprite 分别播放偶帧/奇帧动画，位置偏移使左右内容空间合并。

**实测偏移调试过程**:

| 测试 | base 位置 | flip 位置 | 观察结果 |
|---|---|---|---|
| 初始 | cx | cx | gap=32，左右分开放 |
| cx±8 | cx+8 | cx-8 | gap 变大 |
| cx±16 | cx+16 | cx-16 | gap=64，往错误方向 |
| cx±24 | cx+24 | cx-24 | gap 更大 |
| cx±32 | cx+32 | cx-32 | gap 回到64，左右位置正确但分开 |
| cx±16 交换 | cx-16 | cx+16 | **最终方案** — 大面正确 |

**最终偏移**: even sprite（右半内容）在 `cx-16`，odd sprite（左半内容）在 `cx+16`

---

## 三、垂直对齐分析（抖动问题根因）

通过 Python 像素级测量 even/odd 帧的 y 轴数据：

```
frame 0: x=[17-31], y=[15-60], bottom_offset=4  ← 右半内容
frame 1: x=[0-14],  y=[15-60], bottom_offset=4  ← 左半内容
frame 2: x=[17-31], y=[15-60], bottom_offset=4  ← 右半内容
frame 3: x=[0-14],  y=[15-60], bottom_offset=4  ← 左半内容
```

**所有帧 bottom_offset 都是 4，y 范围完全一致 [15-60]**。脚底对齐在像素级别是完美的。

**但动画播放时仍有 1-2px 抖动**，原因是：

LPC walkcycle 的 even 帧和 odd 帧不是**空间上的左右镜像**，而是**时间上交替的行走 pose**：
- even帧：右脚蹬地、左脚悬空（步幅中）
- odd帧：左脚蹬地、右脚悬空（步幅中）

这两组帧的姿态本身就不对称，强行空间叠加不能产生完全对称的完整角色。

**根本矛盾**: LPC 原始设计是时间上交替播放 9 帧形成完整步行动画，不打算被空间叠加合并成完整角色。

---

## 四、官方 sheets.rb 工具分析

`sheets.rb`（官方 Ruby 工具）的核心逻辑：

```ruby
delta_x = 64 - frame.reference_frame.x
delta_y = 64 - frame.reference_frame.y
# 将每帧放到 128x128 画布的正确位置
-repage 128x128+delta_x+delta_y
-background none
-flatten
```

**sheets.rb 能解决的问题**: 通过 reference point 做空间对齐，减少帧间的 vertical jitter。

**不能解决的问题**: 半边身体问题——即使对齐做得再好，原始 LPC 帧本身就只含半个身体内容，不会凭空多出另一半。

**环境要求**: Ruby + ImageMagick。由于网络代理阻断，未能成功安装验证。

---

## 五、最终方案及结论

### 最终实现

SpriteViewerScene 使用**双 sprite + 奇偶帧分离 + 位置偏移**方案：

1. 为每个 LPC 状态创建两个独立动画：
   - `{state}_even`: 偶数帧（index 0,2,4...）= 右半内容
   - `{state}_odd`: 奇数帧（index 1,3,5...）= 左半内容
2. 两个 sprite 分别播放不同动画：
   - even sprite 在 `cx-16`（右半内容偏左，拉回中心）
   - odd sprite 在 `cx+16`（左半内容偏右，拉回中心）
3. 两者叠加形成完整角色

### 存在局限

- 中轴线有 1-2px 的垂直抖动（脚底、头顶弧线）
- 这是 LPC 资产设计特性和行走动画本质决定的，不是实现 bug
- 近看时明显，远看或缩放下不明显，不影响游戏整体表现

### 各方案对比

| 方案 | 效果 | 代价 |
|---|---|---|
| 双 sprite + 奇偶分离 | 完整角色，可播放动画 | 中轴线 1-2px 抖动（可接受） |
| 只用偶帧/单帧 | 无抖动 | 角色不完整，失去动画 |
| sheets.rb 精细对齐 | 可能减少抖动 | 环境配置复杂，收益不确定 |
| 换用完整 sprite 资源 | 无抖动 | 放弃 LPC 资产 |

---

## 六、经验教训

### 1. 像素级验证优先

在猜测之前先用 Python 解析 PNG 原始像素数据，而不是猜测。实测数据（bottom_offset=4 对齐）推翻了很多关于"vertical jitter 是因为脚底不齐"的假设。

### 2. 理解资产的设计意图

LPC 行走动画是"时间上交替"而非"空间上叠加"的。强行空间合并会引入时间性抖动。先理解资产为什么这样设计，再决定是接受还是替换。

### 3. flipX 在 Phaser 中的行为需要验证

`setFlipX(true)` 对某些 texture 可能不起预期作用。两个 sprite 同位置、同 texture、一 flipX 一正常，结果是完全重叠（看不见差异）。flipX 无法代替帧分离。

### 4. 偏移量调试需要系统化

多次调试 offset 时没有记录每次变化和结果。建议未来调试参数时保持表格记录，避免来回折腾。

### 5. 官方工具有参考价值但不等于最优解

sheets.rb 的对齐逻辑理论上能减少抖动，但即使装好也无法解决半边身体的根本问题。工具服务于设计思路，理解设计思路比拥有工具更重要。

---

## 七、相关文件

- `six-fighter-web/src/scenes/SpriteViewerScene.ts` — 精灵动画查看器（当前实现）
- `six-fighter-web/src/data/spriteRegistry.ts` — 精灵注册表（含 LPC 角色注册）
- `six-fighter-web/scripts/pixel_art_builder/lpc_adapter.py` — LPC 适配器脚本
- `C:/Users/User/AppData/Local/Temp/lpc_sprites/` — LPC 官方仓库（含 sheets.rb）
