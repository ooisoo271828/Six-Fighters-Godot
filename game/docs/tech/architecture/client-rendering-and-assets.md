# Client Rendering & Assets (Web / Phaser)

Status: Draft  
Version: v0.1  
Owner: Engineering  
Last Updated: 2026-03-22  
Scope: Pixel rendering policy, texture pipeline, loading strategy, audio placeholders, and performance budgets for `six-fighter-web`.  
Related: docs/tech/architecture/web-client-architecture.md; docs/tech/adr/2026-03-22-pixel-art-rendering-policy.md; docs/design/visual-rules/pixel-art-visual-bible.md; docs/design/visual-rules/hero-asset-pipeline-spec.md

## 1. Phaser Boot Configuration

- `render.pixelArt: true` — nearest-neighbor sampling for upscaled pixel textures.
- `render.antialias: false` — avoids softening on edges.
- `render.roundPixels: true` — integer placement where applicable.
- `scale.mode: FIT` + fixed logical size (e.g. 360×640) — letterboxing acceptable; avoid non-uniform stretch of gameplay layer.

CSS: canvas wrapper may use `image-rendering: pixelated` for crisp fullscreen scaling (see app stylesheet).

## 2. Textures & Atlases

- **Authoring**: Aseprite → PNG strip or **Texture Packer / Phaser atlas JSON** for production.
- **Naming**: `{heroId}_{anim}_{index}.png` or single atlas `characters-{heroId}.json` + `characters-{heroId}.png`.
- **Max texture size**: prefer **2048×2048** atlases per major pack; split by scene if needed.

## 3. Scene Loading

- **Boot**: global CSV + shared UI font (system font acceptable for v0).
- **Hub**: hub backgrounds + NPC placeholders.
- **Arena**: hero packs for current roster + enemy/boss packs + VFX atlases — **lazy load** on `scene.start('ArenaScene')` via `this.load` in `preload` phase once refactored from pure `create` async.

Current node build loads CSV from `public/design-values/`; images follow same pattern under `public/assets/`.

## 4. VFX Implementation

- **Particles**: `Phaser.GameObjects.Particles.ParticleEmitter` with conservative max counts on mobile GPUs.
- **Blend**: additive for fire/sparks; alpha clamp from `visual-presentation-values.csv`.
- **Screen effects**: camera `shake`, brief `timeScale` hit-stop — durations from CSV.

## 5. Audio (Future)

- Format: **OGG** primary, MP3 fallback if required by target browsers.
- Duck BGM on ultimate (design toggle, not implemented in first pass).

## 6. Performance Budget (Initial Targets)

- **60 FPS** on mid-range laptop integrated GPU at 360×640 FIT scale.
- **Draw calls**: batch via atlases; avoid per-frame texture swaps.
- **Particle cap**: configurable constant per scene (document when raising).

## 7. Related CSV

- `docs/design/visual-rules/values/visual-presentation-values.csv` — mirrored under `six-fighter-web/public/design-values/` for runtime fetch.
