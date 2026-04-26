## 1. History List Display Format

- [x] 1.1 In `executor_dock.gd` `_refresh_history_list()`: change display format from `"%s [%s] %s - %dms (%s)" % [preview, status_str, ...]` to `"[%s] %s - %dms (%s)" % [status_str, entry.timestamp, entry.duration_ms, source_str]`, removing the code preview portion entirely
- [x] 1.2 In `_refresh_history_list()`: remove the code preview logic (the `preview` variable, `split("\n")[0]`, and truncation to 60 chars) since it is no longer used

## 2. History Item Status Color Coding

- [x] 2.1 In `_refresh_history_list()`: after `_history_list.add_item(display)`, call `_history_list.set_item_custom_fg_color(idx, color)` where `idx` is the return value of `add_item`, using `Color.GREEN` for OK status and `Color.RED` for FAIL status

## 3. Dock Default Position

- [x] 3.1 In `hasturoperationgd.gd` `_enter_tree()`: change `_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_UL` to `_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL`
