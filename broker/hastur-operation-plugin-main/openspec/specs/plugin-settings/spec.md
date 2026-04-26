## ADDED Requirements

### Requirement: Register plugin settings in ProjectSettings
The plugin SHALL register its configuration settings in Godot's ProjectSettings under the `hastur_operation/` prefix during `_enter_tree()`. Each setting SHALL be registered with a default value via `set_initial_value()` and exposed in the Project Settings dialog via `add_property_info()`.

#### Scenario: First-time plugin activation
- **WHEN** the plugin is enabled for the first time and `hastur_operation/output_max_char_length` does not exist in ProjectSettings
- **THEN** the plugin SHALL create the setting with default value 800, set its initial value to 800, and register property info with type int and a range hint (100 to 10000)

#### Scenario: Plugin re-activation with existing settings
- **WHEN** the plugin is re-enabled and `hastur_operation/output_max_char_length` already exists in ProjectSettings
- **THEN** the plugin SHALL NOT overwrite the current value, but SHALL still call `set_initial_value()` and `add_property_info()` to ensure the setting is properly displayed in the Project Settings dialog

### Requirement: Output max char length setting
The plugin SHALL provide a `hastur_operation/output_max_char_length` setting (int, default 800) that controls the maximum number of characters allowed in a single output value. The setting SHALL be editable in Godot's Project Settings dialog under the `hastur_operation/` category.

#### Scenario: Reading the default value
- **WHEN** no custom value has been set for `hastur_operation/output_max_char_length`
- **THEN** the plugin SHALL use the default value of 800

#### Scenario: Reading a custom value
- **WHEN** the user has set `hastur_operation/output_max_char_length` to 1200 in Project Settings
- **THEN** the plugin SHALL use 1200 as the maximum character length for output values
