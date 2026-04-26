# ADR: Pixel-art rendering policy for Web (Phaser)

Status: Accepted  
Version: v1.0  
Owner: Engineering  
Last Updated: 2026-03-22  
Scope: Freeze nearest-neighbor pixel rendering defaults and separation from future HD-2D exploration.  
Related: docs/design/visual-rules/pixel-art-visual-bible.md; docs/tech/architecture/client-rendering-and-assets.md

## Context

The product targets **pure 2D pixel art** in browser with a **portrait** layout. Octopath Traveler is cited as **mood reference**, not as a mandate for HD-2D (3D environments + deferred lighting).

## Decision

1. Ship **Phaser 3** with **pixelArt: true**, **antialias: false**, **roundPixels: true** for all gameplay textures authored on a pixel grid.
2. **Do not** introduce Three.js or 3D scene graphs for combat in the current milestone unless a separate ADR replaces this decision.
3. **Visual tuning** that affects readability (shake duration, hit-stop, VFX alpha caps) is driven by `docs/design/visual-rules/values/visual-presentation-values.csv`, not magic numbers in code (values may be duplicated to `public/design-values/` for the web demo).

## Consequences

- Artists export at **integer** sizes; scaling uses **nearest** filter only.
- Full-screen post stacks (bloom, DOF) are **out of scope** until a new ADR; **2D** vignette/overlay sprites are allowed.

## Compliance

- Changes to global signal readability (`strict_global_standard`) still require design approval per combat freeze docs.
