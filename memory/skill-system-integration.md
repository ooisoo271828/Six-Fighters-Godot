---
name: skill-system-integration
description: 新技能必须同步更新 skill_demo 的池检查函数，否则 UI 卡死。reset_for_pool() 必须覆盖 initialize() 的全部修改。
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bc79e782-1c8a-48ad-8dcd-6daf37732708
---

新增自定义对象池时同步更新 `skill_demo.gd`:
- `_count_active_projectiles()` → 加入新池的 `get_active_count()`
- `_clear_all_projectiles()` → 加入新池的 `clear_all()`
- 漏了会导致 `_is_casting` 永为 true，播放按钮锁死

非标准 Effect（非 emit_projectile）的 chain 要在 `skill_root.gd:_execute_chain()` 中特殊路由，否则会被错误地交给 ProjectilePool。

`reset_for_pool()` 必须与 `initialize()` 互逆——前者每一条赋值都能在后者的修改中找到对应。

**Why:** 实际事故：激光柱技能第一次能放，第二次 UI 卡死。根因就是 _count_active_projectiles 没检查 LaserBeamPool。
**How to apply:** 新增技能后对照注册清单逐项检查（见 pitfall-guide §14.3）。
