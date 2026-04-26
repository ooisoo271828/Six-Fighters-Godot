# 产品战斗定位与文档命名约定

Status: Draft  
Version: v0.1  
Owner: Design  
Last Updated: 2026-03-30  
Scope: 战斗/呈现相关 **产品口径**（非硬核 ARPG、用户与数值重心）；团队 **文档 vs 工程命名** 约定。  
Related: `docs/design/other/game-foundation-baseline.md`; `docs/design/combat-rules/skill-warning-zone-spec.md`; `docs/design/visual-rules/hit-feedback-juice-spec.md`; `docs/design/combat-rules/projectile-v1-taxonomy.md`

## 1. 产品口径（战斗与呈现）

- **不是**传统意义上的硬核 ARPG；核心用户偏 **手机端、中轻度泛游戏用户**，不以 **毫秒级反射、极限操作反馈** 为核心卖点。  
- **形态**：**2D 即时制关卡游戏**，操作轻松，带 **部分动作类技能的视觉表现**（技能圈、投射物、命中爆炸感等）。  
- **胜负与成长**：**大数值 RPG** — 角色与怪物数值成长幅度大；能否击杀/被击杀的 **主要决定因素是养成是否达标**，而非高度依赖瞬时操作。  
- **警戒与威胁提示**：要做，体现严谨与对用户的关注；**不作为最核心模块**，体系保持 **简单**（见 `skill-warning-zone-spec.md`）。

## 2. 呈现侧补充（与上并存）

- 战斗视觉可走 **技能范围提示 + 中量多样化投射物 + 强命中反馈**；投射物数量可 **高于常见即时制 RPG**，**远不到** 弹幕射击规模。  
- 投射物与命中表现的 **技术拆分** 见 `projectile-v1-taxonomy.md` 与 `hit-feedback-juice-spec.md`。

## 3. 文档与工程命名约定

- **设计文档正文**：尽量 **中文**，便于方案沟通与体验描述。  
- **工程侧缺省英文**：表头、参数 key、枚举 ID、资源路径、代码标识符等，便于国际化协作与程序实现。  
- 正式 ID 以各 spec 内表格为准。
