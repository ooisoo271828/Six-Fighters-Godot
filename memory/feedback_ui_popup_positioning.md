---
name: feedback-ui-popup-positioning
description: "All popup/dialog/overlay UI must be viewport-centered (slightly below center for mobile), never scene-anchored or top-left"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 01ae412e-6c11-42a0-bf28-9e835c13d882
---

All popup dialogs, confirmation windows, and info overlays must be positioned relative to the viewport (screen), NOT the game scene.

**Why:** The user flagged a portal confirmation dialog appearing at the top-left corner. The root cause was using `anchors_preset = PRESET_CENTER` which can be unreliable, combined with offsets that ended up relative to (0,0). On mobile (portrait 540x960), popups must be thumb-friendly.

**How to apply:**
- Always manually set `anchor_left/right = 0.5`, `anchor_top/bottom = 0.5` — do NOT rely on `anchors_preset` alone.
- Then set offsets to center the control: `offset_left = -half_w`, `offset_right = half_w`, `offset_top = -half_h`, `offset_bottom = half_h`.
- For mobile, nudge slightly below center: add ~40-60px to both top and bottom offsets.
- Backdrop (semi-transparent overlay) uses `anchors_preset = PRESET_FULL_RECT` + `mouse_filter = MOUSE_FILTER_STOP`.
- Both backdrop and dialog go into UILayer (CanvasLayer).
- Pattern applies to: confirmation dialogs, info popups, error messages, any modal overlay.
