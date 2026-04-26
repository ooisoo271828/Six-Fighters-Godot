# 像素艺术构建器 - 交接文档

**日期**: 2026-04-15
**状态**: 完成 V1 架构
**负责人**: Claude (Human → AI 协作)

---

## 1. 概述

### 1.1 背景

原 `generate_sprites.py` 是硬编码像素数组的简单脚本，难以维护和扩展。为了支持更复杂的像素艺术工作流，重构为模块化架构。

### 1.2 目标

- 支持分层构建角色（头、躯干、双臂、下肢独立定义）
- 支持姿态变换（站立、行走、奔跑、攻击、受击、死亡）
- 支持多种导出格式（PNG、Aseprite JSON、HTML 预览）
- 可扩展以支持更多角色（Ember、Moss 等）

---

## 2. 架构

### 2.1 目录结构

```
six-fighter-web/scripts/pixel_art_builder/
├── __init__.py          # 模块初始化，导出公共接口
├── palette.py           # 调色板定义
├── sprite_parts.py      # 身体部位像素定义
├── poses.py             # 动作姿态库
├── composer.py          # 帧组合器
├── animator.py          # 动画序列生成
├── exporters.py         # PNG / Aseprite JSON / HTML 导出
└── builder.py           # 主入口
```

### 2.2 模块职责

| 模块 | 职责 |
|------|------|
| `palette.py` | 定义角色调色板（颜色索引 → RGBA） |
| `sprite_parts.py` | 定义身体部位的像素数组（头、躯干、左臂、右臂、腿） |
| `poses.py` | 定义动作姿态（各部位的偏移/翻转） |
| `composer.py` | 将部位按姿态组合成完整帧 |
| `animator.py` | 生成动画序列（多帧） |
| `exporters.py` | 导出 PNG、JSON、HTML |
| `builder.py` | 命令行入口，协调所有模块 |

### 2.3 核心概念

#### 像素数据类型
```python
PixelRow = list[int]      # 一行 32 像素
PixelFrame = list[PixelRow]  # 64 行的帧
```

#### 身体部位
- `HEAD` - 头部（骑士头盔）
- `TORSO` - 躯干（胸甲+护肩）
- `ARMS` - 双臂（左臂、右臂）
- `LEGS` - 下肢（腿甲+靴子）

#### 姿态
```python
@dataclass
class LimbPose:
    offset_x: int = 0    # X 轴偏移
    offset_y: int = 0    # Y 轴偏移
    flip: bool = False   # 水平翻转
```

#### 组合顺序（从后到前）
1. 腿部（最底层）
2. 躯干
3. 双臂
4. 头部（最顶层）

---

## 3. 使用方法

### 3.1 命令行

```bash
cd six-fighter-web/scripts/pixel_art_builder

# 构建所有角色
python builder.py

# 构建特定角色
python builder.py ironwall

# 生成 HTML 预览
python builder.py ironwall --preview

# 启用调试输出
python builder.py ironwall --debug

# 查看系统信息
python builder.py --info

# 测试组合器
python builder.py --test
```

### 3.2 输出文件

| 路径 | 说明 |
|------|------|
| `assets/sprites/heroes/<hero>/spr_hero_<hero>_<state>_<idx>.png` | 单帧 PNG |
| `assets/sprites/heroes/<hero>/strip_<state>.png` | 动画 strip PNG |
| `src/data/sprites/<hero>.json` | 精灵注册表 |
| `src/data/sprites/<hero>_<state>.json` | Aseprite JSON |
| `docs/preview/<hero>/preview.html` | HTML 动画预览 |

---

## 4. 当前状态

### 4.1 已实现角色

#### 铁墙 (Ironwall) - 西欧重甲骑士

**调色板** (PAL_IRONWALL):
| 索引 | 颜色 | 用途 |
|------|------|------|
| 0 | 透明 | 背景 |
| 1 | 深钢色 | 轮廓线 |
| 2 | 暗钢色 | 阴影 |
| 3 | 主体钢色 | 盔甲主体 |
| 4 | 高光钢色 | 高光 |
| 5 | 金色 | 装饰 |
| 6 | 盾牌蓝 | 盾牌 |

**部位定义**:
- 头部: 8 像素高，居中，骑士头盔造型
- 躯干: 10 像素高，有胸甲和金色腰带装饰
- 腿部: 32 像素高，包含腿甲和靴子
- 左臂: 7 像素高，臂甲+护手
- 右臂: 7 像素高，镜像左臂

**动画状态**:
| 状态 | 帧数 | 说明 |
|------|------|------|
| idle | 1 | 站立待机 |
| walk | 2 | 行走 |
| run | 2 | 奔跑 |
| attack_basic | 1 | 基本攻击 |
| hit | 1 | 受击 |
| death | 1 | 死亡 |

### 4.2 预留角色

- **Ember** - 火焰法师（调色板已定义）
- **Moss** - 自然辅助（调色板已定义）

---

## 5. 已知的限制

### 5.1 像素艺术质量

当前生成的是**程序化简单像素艺术**，用于快速验证架构。实际生产需要：
- 使用 Aseprite 等专业工具绘制
- 定义更精细的像素数组
- 添加更多动画帧

### 5.2 架构限制

- 姿态系统仅支持简单的偏移/翻转，不支持复杂变形
- 像素混合使用简单的覆盖，没有真正的颜色混合
- 左右臂是独立定义的，但镜像逻辑可能需要改进

### 5.3 精灵加载

`SpriteViewerScene` 需要在场景中正确加载纹理。当前实现：
- `SkillDemoScene` 在 `preload()` 中加载铁墙精灵
- `SpriteViewerScene` 在 `selectHero()` 中动态加载

---

## 6. 后续工作建议

### 6.1 高优先级
1. **改进铁墙像素艺术** - 按照西欧重甲骑士设计重新绘制
2. **添加更多行走帧** - 至少 4 帧实现平滑行走
3. **添加攻击动画** - 3-4 帧的攻击动作

### 6.2 中优先级
4. **实现 Ember 和 Moss** - 复用架构
5. **改进镜像系统** - 统一管理左右对称
6. **添加 Aseprite 导出** - 支持导入 Aseprite 编辑

### 6.3 低优先级
7. **添加像素混合效果** - 基于调色板颜色的真正混合
8. **支持多层姿态** - 更复杂的姿态变形
9. **批量导出工具** - 支持批量处理多个角色

---

## 7. 相关文件索引

| 文件 | 说明 |
|------|------|
| `scripts/pixel_art_builder/*.py` | 构建器源码 |
| `assets/sprites/heroes/ironwall/*.png` | 铁墙精灵 |
| `src/data/sprites/ironwall.json` | 铁墙注册表 |
| `src/data/spriteRegistry.ts` | 精灵注册表 TypeScript |
| `src/scenes/SpriteViewerScene.ts` | 精灵查看器 |
| `docs/preview/ironwall/preview.html` | HTML 预览 |

---

## 8. 关键代码位置

### 组合逻辑
- `composer.py:compose_frame()` - 帧组合入口

### 部位定义
- `sprite_parts.py:create_ironwall_parts()` - 铁墙部位

### 姿态定义
- `poses.py:get_idle_pose()`, `get_walk_pose_left()` 等

### 导出逻辑
- `exporters.py:export_png()` - PNG 导出
- `exporters.py:export_html_preview()` - HTML 预览生成

---

**交接日期**: 2026-04-15
**下一步**: 根据需要改进像素艺术或扩展架构
