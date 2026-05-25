---
name: project-squad-formation-rule
description: Squad formation is the single source of truth for hero identity + position in ALL scenes. Use GameManager.spawn_squad().
metadata: 
  node_type: memory
  type: project
  originSessionId: 01ae412e-6c11-42a0-bf28-9e835c13d882
---

Squad formation (小队布阵) is the **唯一标准数据源** for hero roster and positions across all game scenes.

**Why:** The user established this as a project-level architectural rule. Previously each scene (hub, arena) duplicated FORMATION_OFFSETS and _spawn_heroes logic, causing position desync when the formation was changed in the editor but not reflected in scenes.

**How to apply:**
- **阵型数据** (`FORMATION_OFFSETS`, `SQUAD_SIZE`): defined ONLY in `GameManager`
- **英雄生成**: call `GameManager.spawn_squad(parent, center_pos, config)` — returns `{ "heroes": Array[Hero], "slot_indices": Array[int] }`
- **阵型偏移查询**: `GameManager.get_formation_offset(slot_index)`
- **阵容读写**: `GameManager.get_roster()` (6-element with empty slots), `GameManager.set_roster()`, `GameManager.get_active_roster()` (non-empty only for UI)
- Any new scene (boss rush, dungeon, PvP, etc.) MUST use `GameManager.spawn_squad()` unless it explicitly declares a custom formation system
- If a scene needs a different formation layout, it should document WHY and use its own offsets only after explicit discussion
