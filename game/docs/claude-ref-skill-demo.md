# SkillDemo Scene Reference

**Scene**: `res://scenes/dev/skill_demo.tscn`
**Script**: `scripts/dev/skill_demo.gd`

A skills testing tool that uses the same camera system as the actual game.

## Quick Start

In Godot Editor, open `res://scenes/dev/skill_demo.tscn` and press F5.

## Controls

| Control | Function |
|---------|----------|
| Skill dropdown | Select skill (loaded from SkillRegistry) |
| ▶ Play | Cast selected skill from caster to targets |
| ⏸ Pause | Freeze all projectiles (resume to continue) |
| ⏹ Stop | Clear all projectiles, reset state |
| Speed button | 0.5x / 1x / 2x cycle |
| Target mode button | single / dual / triangle / scatter / line cycle |
| Loop checkbox | Auto-replay on completion |
| Space | Play/Stop shortcut |
| R | Toggle loop shortcut |

## Files

| File | Purpose |
|------|---------|
| `scripts/dev/camera_anchor.gd` | CameraAnchor component (reusable) |
| `scripts/dev/skill_demo.gd` | Main controller + UI |
| `scripts/dev/demo_bg.gd` | Grid background drawing |
| `scripts/dev/demo_caster.gd` | Caster unit visual |
| `scripts/dev/demo_target.gd` | Target dummy visual |
| `scenes/dev/skill_demo.tscn` | Scene file |

## Speed/Pause Implementation

Uses `Engine.time_scale`:
- Play: `time_scale = speed_multiplier` (0.5/1.0/2.0)
- Pause: `time_scale = 0.0` (projectiles freeze, UI still responsive)
- Always restored to 1.0 on scene exit (`_exit_tree()`)
