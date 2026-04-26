# Pixel Art Visual Bible (Octopath-Inspired Tone, Pure 2D)

Status: Draft  
Version: v0.1  
Owner: Art + Design  
Last Updated: 2026-03-22  
Scope: 2D 像素混合视觉基线：调色板、假光照、安全区、以及 VFX 分层与可读性约束。MVP 优先产出像素资源，但不以“必须纯像素”为唯一目标；不限定最终角色概念。  
Related: docs/design/other/game-foundation-baseline.md; docs/design/combat-rules/combat-core-l3-readability-guardrails.md; docs/design/visual-rules/combat-presentation-spec.md; docs/design/visual-rules/values/visual-presentation-values.csv; docs/tech/adr/2026-03-22-pixel-art-rendering-policy.md

## 1. Product Alignment

- **Pure 2D pixel** in a **portrait** frame (browser-first), per `game-foundation-baseline.md`.
- **像素混合**：MVP 优先产出像素版资源以提升落地成功率与成本效率；允许少量非像素素材（例如插画/矢量/更干净的贴图），但必须在调色板、对比度、语义锚点（盟友/敌人/警戒/治疗等）和层级优先级上保持一致，否则不作为 MVP 竖切的可接受交付。
- **Tone goal**: limited palette, strong value steps, directional highlights — evoking **Octopath Traveler** mood **without** HD-2D (no 3D environments or engine switch in phase 1).

## 2. Logical Resolution & Pixel Grid

- **Design resolution (reference)**: **360×640** logical pixels (matches current web demo canvas); art may be authored at **1×** or **2×** export then downscaled with **nearest** filtering only.
- **Grid**: integer pixel alignment for key outlines; avoid sub-pixel blur on character edges (enforced in tech via `pixelArt` / nearest scaling — see `client-rendering-and-assets.md`).

## 3. Palette & Neutrals

- Use a **restricted palette** (target 32–64 master colors for characters+VFX, excluding UI chrome).
- Reserve **semantic anchors** (exact hex in implementation via theme, not in this logic doc):
  - Ally readable silhouette
  - Enemy hostile read
  - Hazard warning (must stay distinct from ally — see §6)
  - Healing / buff (if used)
- **Octopath-like feel** comes from **value separation** (dark midtones + one highlight direction), not from rainbow saturation.

## 4. Fake Lighting (2D)

- **Global fake light direction**: **top-left** (highlights on upper-left edges, core shadows opposite).
- **Contact shadow**: 1–2 px soft ellipse or band under feet; never compete with hazard ground telegraphs in contrast.
- **No** baked environment normal maps in v1; optional **gradient background** layers behind playfield.

## 5. Portrait Safe Zones

- **Top ~12%**: reserved for mode title / wave info (optional).
- **Central playfield**: hazards and combat; keep **critical telegraphs** inside **middle 70%** width where possible.
- **Bottom ~18%**: thumb + virtual joystick; **no** mandatory readability content under finger occlusion (only redundant or duplicate cues).

## 6. VFX Priority vs Readability (`strict_global_standard`)

Aligned with `combat-core-l3-readability-guardrails.md` layer priority (lethal > telegraphs > silhouettes > ally FX > decoration).

### 6.1 Rules

1. **Telegraphs** must remain readable: outline, fill, or dashed border — **never** fully covered by ally VFX for the full wind-up window.
2. **Additive / bright particles** (fire, sparks) use **clamped opacity** and **short lifetime** near silhouettes; tunable caps in `visual-presentation-values.csv`.
3. **Boss / full-screen flair** (darkening edges, vignette) must **not** occur on the same frames as **lethal** hazard boundary reveal (see combat presentation spec for timing separation).

### 6.2 Z-Order (conceptual)

From back to front: background parallax → ground decals → enemy shadow → **hazard telegraph** → units → ally VFX → **critical hazard overlay** (if any) → UI.

## 7. Non-Goals (Phase 1)

- Real HD-2D: 3D meshes, dynamic GI, depth-of-field as a 3D post chain.
- Per-character unique shader stacks beyond palette swap + additive VFX.

## 8. Numeric Tuning

Opacity caps, shake duration, flash duration, and hit-stop lengths are **not** finalized here — see:

- `docs/design/visual-rules/values/visual-presentation-values.csv`
