# Memory Index

- [UI Popup Positioning Rule](feedback_ui_popup_positioning.md) — All popup/dialog/overlay must be viewport-centered, manually set anchors to 0.5, slightly below center for mobile
- [Squad Formation Single Source](project_squad_formation_rule.md) — Formation data + spawn logic centralized in GameManager. All scenes use GameManager.spawn_squad(). No more per-scene duplication.
- [Use Hastur Proactively](feedback_use_hastur_proactively.md) — Always consider Hastur first for debugging, inspection, verification. Don't wait for user to suggest it.
