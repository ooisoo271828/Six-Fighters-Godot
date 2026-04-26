## Context

The Hastur Executor dock panel (`executor_dock.gd`) builds its UI programmatically using Godot's built-in controls. The history list is a single-column `ItemList` that currently concatenates all data into one flat string per item: `print("hello") [OK] 14:30:05 - 45ms (local)`. The dock is registered via `EditorDock` with `default_slot = DOCK_SLOT_LEFT_UL`.

The Godot `ItemList` control supports per-item foreground color via `set_item_custom_fg_color(idx, color)`, and the `EditorDock` API provides `DOCK_SLOT_RIGHT_UL` which places the dock in the same tab group as the Inspector (right side, upper-left).

## Goals / Non-Goals

**Goals:**
- Improve history list scanability by putting status first and removing code preview clutter
- Provide instant visual feedback on success/failure via color coding
- Position the dock near the Inspector for a more natural workflow

**Non-Goals:**
- Changing the history data model or backend storage
- Adding multi-column layout to the ItemList (keeping single-column flat display)
- Persisting dock position across sessions (EditorDock handles this automatically)
- Changing the history sort order (keeping chronological oldest-first)

## Decisions

### Decision 1: Use `set_item_custom_fg_color` for status coloring
Apply `Color.GREEN` or `Color.RED` as the foreground color on each `ItemList` item based on execution result. This colors the entire item text.

- **Alternative considered**: Using icons (`set_item_icon`) — would require creating or bundling icon textures. Text color is simpler and sufficient.
- **Alternative considered**: Using `set_item_custom_bg_color` — background colors can look heavy in the editor theme. Foreground color is more subtle and consistent with the existing connection status color pattern.

### Decision 2: Remove code preview entirely from history items
Since `_on_history_selected()` already populates the code editor with the full source, the truncated preview adds noise without value.

- **Alternative considered**: Keep a short 20-char preview after status — still clutters the list. Clean removal is better.
- **Alternative considered**: Use ItemList tooltip (`set_item_tooltip`) for code preview on hover — nice but not requested, can be added later.

### Decision 3: Display format becomes `[STATUS] HH:MM:SS - Nms (source)`
New format: `[OK] 14:30:05 - 45ms (local)` or `[FAIL] 14:31:10 - 12ms (remote)`.

### Decision 4: Use `DOCK_SLOT_RIGHT_UL` for default dock position
Per Godot docs: `DOCK_SLOT_RIGHT_UL` is "right side, upper-left (in default layout includes Inspector, Signal, and Group docks)." This is exactly the Inspector's dock group.

- **Note**: After the first placement, the editor remembers the dock position. The `default_slot` only applies on first add.

## Risks / Trade-offs

- **[Risk] Existing users have dock on the left side** → Godot saves dock layout per-project. After upgrading, users who moved the dock will keep their position. Only fresh installations get the new default.
- **[Risk] `Color.GREEN` / `Color.RED` may not match all editor themes** → These are Godot's standard colors. They are already used for the connection status label, so consistency is maintained. Theme-aware colors could be a future improvement.
