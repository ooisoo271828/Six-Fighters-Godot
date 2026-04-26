# Hero Asset Pipeline (Aseprite → Phaser)

Status: Draft  
Version: v0.1  
Owner: Art + Engineering  
Last Updated: 2026-03-22  
Scope: Directory layout, naming, export rules, and **V1 single-hero vertical slice** acceptance criteria.  
Related: docs/design/feature-systems/hero-skill-template-v1.md; docs/design/visual-rules/pixel-art-visual-bible.md; docs/tech/architecture/client-rendering-and-assets.md; docs/tech/adr/2026-03-22-pixel-art-rendering-policy.md

## 1. Directory Layout (Repository)

Under `six-fighter-web/public/assets/` (runtime URL `/assets/...`):

```text
assets/
  characters/
    <heroId>/
      atlas.json          # optional Phaser atlas
      atlas.png
      animations.json     # optional custom manifest (frame ranges)
  vfx/
    <skillTag>/
      strip.png
      meta.json             # fps, loop, blend mode hint
  README.md                 # links back to this doc
```

For MVP（尤其是 Phaser 里粒子与 telegraph 的贴图使用），建议将每个 `vfx/<skillTag>/` 目录在导入时**生成一份 per-skill 的 Phaser atlas**（`atlas.json + atlas.png`），用于粒子贴图与必要的 telegraph 帧检索；目录中的 `strip.png/meta.json` 仍作为作者源文件。

Authoritative design copies may also live under `docs/design/visual-rules/` as references (storyboards only — **no** binary blobs in `docs/` if repo size policy forbids).

## 2. Naming

- **heroId**: lowercase kebab-case matching code (`ironwall`, `ember`, `moss`).
- **Animation keys** (Phaser `anims.create`):
  - `hero_<id>_idle`
  - `hero_<id>_run`
  - `hero_<id>_attack_basic`
  - `hero_<id>_skill_a`
  - `hero_<id>_skill_b`
  - `hero_<id>_ultimate`
  - `hero_<id>_hit`
  - `hero_<id>_death`

## 3. Aseprite Export Rules

- **Canvas**: consistent **character rig height** (e.g. 48 px tall baseline) across heroes for roster readability.
- **Pivot**: feet centered bottom of cell for ground alignment.
- **Export**: PNG, **no** premultiplied alpha unless documented; **nearest** scaling only.
- **Frames**: label layers/tags per animation; JSON hash export compatible with Phaser atlas pipeline (Texture Packer JSON or Aseprite sheet + JSON).

## 4. VFX Tags

Map skills to folders under `vfx/`:

| Tag | Use |
|-----|-----|
| `fx_phys_slash` | Physical arcs |
| `fx_fire_burst` | Fire small/ult |
| `fx_spark_line` | Lightning |
| `fx_ice_cyclone` | Ice cyclone / slow field |
| `fx_poison_cloud` | Poison |
| `fx_energy_missile_storm` | Energy missile storm（Bezier 曲线多枚飞弹+落点冲击） |
| `fx_impact_light` / `fx_impact_heavy` | Generic hit sparks |

## 5. V1 Vertical Slice Acceptance (One Hero)

For the first completed hero (recommended: `ember` — covers fire + lightning reads):

1. **Animations**: idle, run (or shuffle), basic attack, skill A, skill B, ultimate, hit, death — all playable in Arena without placeholder rectangle.
2. **VFX**: at least **two** skill VFX strips (fire + lightning) + one **impact** prefab.
3. **Hit feedback**: uses global CSV-driven flash + shake (no hardcoded durations in scene code).
4. **Performance**: single atlas ≤ 2048×2048 for that hero pack.

## 6. V2–V4 Rollout (Reminder)

- **V2**: replicate pipeline for three heroes with distinct silhouettes.
- **V3**: enemy + boss atlases; hazard decal art.
- **V4**: polish pass — hit-stop tuning, audio hooks, readability regression vs `combat-core-l3-readability-guardrails.md`.
