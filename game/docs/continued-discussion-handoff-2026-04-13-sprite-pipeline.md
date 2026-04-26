# 续聊交接：角色精灵资产管线 + 动画查看器（2026-04-13）

Status: Active
Scope: 精灵资产管线建立、美术命名规范、角色动画查看器、PNG 资产管道打通
Session ID: (延续 session)

---

## 一、今日工作成果

### 1. 美术资产命名规范 v1.0

**文件**: `docs/project/standards/asset_naming_convention.md`

建立了完整的游戏资产文件命名法则，包括：

**目录结构**：
```
assets/
├── sprites/heroes/<hero_id>/     # 英雄精灵
├── sprites/monsters/             # 怪物精灵
├── sprites/bosses/               # Boss 精灵
├── sprites/ui/                   # UI 精灵
├── audio/sfx/                    # 音效
├── audio/bgm/                    # 背景音乐
└── vfx/                          # 视觉特效贴图
```

**精灵文件命名格式**：
```
spr_<unit_type>_<unit_name>_<anim_state>_<frame_idx>.png
```

- `spr` = sprite 资源前缀
- `unit_type`: `hero` | `monster` | `boss` | `npc` | `env`
- `unit_name`: 单位名称全小写（ironwall / grunt / skeleton_archer）
- `anim_state`: `idle` | `run` | `walk` | `attack_basic` | `skill_a` | `hit` | `death` | `victory` | `spawn`
- `frame_idx`: 两位数字补零（00, 01, 02...）

**完整示例**：
```
spr_hero_ironwall_idle_00.png
spr_hero_ironwall_run_00.png
spr_hero_ironwall_run_01.png
spr_monster_grunt_idle_00.png
spr_boss_ice_golem_idle_00.png
```

**核心规则**：
- 全部小写 + 下划线连接
- 序号两位补零
- 脚底对齐画布底部
- 每角色独立调色板，索引0=透明

### 2. 精灵资产重新整理

将原有的不规范资源迁移到新结构：

| 旧路径 | 新路径 |
|--------|--------|
| `assets/sprites/ironwall/ironwall_idle_0.png` | `assets/sprites/heroes/ironwall/spr_hero_ironwall_idle_00.png` |
| `assets/sprites/ironwall/ironwall_run_0.png` | `assets/sprites/heroes/ironwall/spr_hero_ironwall_run_00.png` |
| `assets/sprites/ironwall/ironwall_run_1.png` | `assets/sprites/heroes/ironwall/spr_hero_ironwall_run_01.png` |

### 3. PNG 精灵生成管道打通（Python + Pillow）

**文件**: `six-fighter-web/scripts/generate_sprites.py`

Python 脚本从硬编码像素数组生成 PNG 文件，遵循命名规范：

```
py scripts/generate_sprites.py
```

**输出**：
- `assets/sprites/heroes/ironwall/spr_hero_ironwall_idle_00.png` (32×64)
- `assets/sprites/heroes/ironwall/spr_hero_ironwall_run_00.png`
- `assets/sprites/heroes/ironwall/spr_hero_ironwall_run_01.png`
- `src/data/sprites/ironwall.json`（精灵元数据）

**工作流程**：
1. 修改 `generate_sprites.py` 中的像素数组
2. 运行 `py scripts/generate_sprites.py` 生成 PNG
3. 刷新浏览器查看效果

**已知问题**：像素绘画能力有限（Ironwall 骑士腿比例失调），建议迭代方案见"待解决问题"。

### 4. 角色精灵注册表

**文件**: `six-fighter-web/src/data/spriteRegistry.ts`

```typescript
export interface SpriteFrame {
  state: string;
  index: number;
  textureKey: string;   // Phaser 贴图 key
  filePath: string;    // PNG 文件路径
}

export interface HeroSpriteSet {
  heroId: string;
  displayName: string;
  frames: SpriteFrame[];
}
```

`spriteRegistry.ts` 是精灵数据的单一数据源，ArenaScene 和 SpriteViewerScene 都从它读取。

### 5. 角色动画查看器（SpriteViewerScene）

**文件**: `six-fighter-web/src/scenes/SpriteViewerScene.ts`

新场景，功能：
- 左侧角色列表（目前仅 Ironwall）
- 中央显示选中角色（3x 放大显示）
- 地面参考线
- 下方动画状态按钮（IDLE / RUN）
- PLAY / PAUSE 控制动画循环播放（400ms/帧）
- 刷新页面保持当前选中状态

**入口**：HubScene 底部「Sprite & Animation Viewer」紫色按钮

**texture key 约定**：`spr_hero_<name>_<state>_<idx>`

### 6. ArenaScene 切换到 PNG 加载模式

**改动前**：canvas 实时绘制（`preloadAllHeroTextures` + `generateHeroTexture`）
**改动后**：Phaser `this.load.image()` 加载预生成的 PNG 文件

```typescript
this.load.image('spr_hero_ironwall_idle_00',
  'assets/sprites/heroes/ironwall/spr_hero_ironwall_idle_00.png');
await this.loadPromise(); // 等待贴图加载完成
this.add.image(hx, hy, 'spr_hero_ironwall_idle_00');
```

canvas 相关函数（`preloadAllHeroTextures`、`generateHeroTexture`）仍保留在 `unitVisual.ts`，但 ArenaScene 不再调用。

---

## 二、Git 提交记录

**Commit `a415142`** — `feat: 角色精灵资产管线 + 动画查看器`
- 140 files, 17094 insertions
- 已推送到 GitHub: https://github.com/ooisoo271828/Six-Fighter

---

## 三、待解决问题

### Ironwall 像素精灵质量

**问题**：当前像素绘画的 Ironwall 骑士比例严重失调，腿占了约一半高度（32px/64px），与真实西欧骑士比例差距很大。

**建议方案**（三选一）：

1. **找参考图驱动**：用户提供想要的骑士风格参考图（如 32×64 像素骑士截图），AI 分析比例后复刻像素数组，而非从零创作

2. **使用现成像素素材站**：
   - https://opengameart.org （免费，游戏用）
   - https://itch.io/game-assets （各类像素美术）
   - 挑选比例合适的骑士 sprite，下载后转换格式接入管道

3. **降低复杂度先跑通管线**：先用一个简单人形轮廓把 SpriteViewerScene 动画播放跑通，之后再换精细素材

### 其他待做精灵

- Ember（火焰系英雄）：调色板 ember，idle/run 帧
- Moss（自然系英雄）：调色板 moss，idle/run 帧
- 完整 animState：attack_basic、skill_a、hit、death 等

---

## 四、关键文件清单

| 文件 | 说明 |
|------|------|
| `docs/project/standards/asset_naming_convention.md` | 美术资产命名规范 v1.0 |
| `six-fighter-web/scripts/generate_sprites.py` | PNG 精灵生成脚本 |
| `six-fighter-web/src/data/spriteRegistry.ts` | 精灵注册表数据 |
| `six-fighter-web/src/scenes/SpriteViewerScene.ts` | 角色动画查看器 |
| `six-fighter-web/src/scenes/ArenaScene.ts` | 已切换到 PNG 加载 |
| `six-fighter-web/src/scenes/HubScene.ts` | 新增 Sprite Viewer 入口按钮 |
| `six-fighter-web/src/main.ts` | 已注册 SpriteViewerScene |
| `six-fighter-web/assets/sprites/heroes/ironwall/*.png` | Ironwall 精灵 PNG |
| `six-fighter-web/src/data/sprites/ironwall.json` | Ironwall 精灵元数据 |

---

## 五、开发服务器状态

- URL: http://localhost:5181
- 首页底部「Sprite & Animation Viewer」紫色按钮 → 进入查看器
- Arena 场景可看到 Ironwall 精灵（需先在首页选英雄再进 Portal）
