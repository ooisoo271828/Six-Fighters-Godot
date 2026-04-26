## Why

The Hastur Executor dock panel's history list has poor readability: the status indicator is buried in the middle of each item string, all items use the same plain text color regardless of success/failure, and the code preview takes up valuable horizontal space even though selecting an item already shows the full code. Additionally, the dock defaults to the left panel side, far from the Inspector where users typically work with properties.

## What Changes

- Reorder history item display to put status first: `[OK] 14:30:05 - 45ms (local)` instead of `print("hello") [OK] 14:30:05 - 45ms (local)`
- Remove code preview text from history list items entirely (full code is already shown in the code editor on selection)
- Color-code history item foreground text: green (`Color.GREEN`) for successful executions, red (`Color.RED`) for failed executions
- Change the dock's default slot from `DOCK_SLOT_LEFT_UL` to `DOCK_SLOT_RIGHT_UL` so it appears in the same dock group as the Inspector panel

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `execution-history`: Change the display format requirement to put status first, remove code preview from list items, and add color-coded status (green for success, red for failure)
- `executor-dock-ui`: Change the default dock slot from left side to right side (same group as Inspector)

## Impact

- `addons/hasturoperationgd/executor_dock.gd` — `_refresh_history_list()` method: display format reorder, code preview removal, per-item foreground color via `ItemList.set_item_custom_fg_color()`
- `addons/hasturoperationgd/hasturoperationgd.gd` — `_enter_tree()`: change `default_slot` from `DOCK_SLOT_LEFT_UL` to `DOCK_SLOT_RIGHT_UL`
- `openspec/specs/execution-history/spec.md` — update display format and add color requirements
- `openspec/specs/executor-dock-ui/spec.md` — update dock position requirement
