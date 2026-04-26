extends Node

## 事件总线 - 用于场景间通信

signal roster_changed(roster: Array)
signal combat_started
signal wave_started(wave_index: int)
signal victory
signal defeat
signal joystick_input(dx: float, dy: float)
signal joystick_stopped

const JOYSTICK_INPUT := "joystick_input"
const JOYSTICK_STOPPED := "joystick_stopped"
const ROSTER_CHANGED := "roster_changed"
const COMBAT_STARTED := "combat_started"
const WAVE_STARTED := "wave_started"
const VICTORY := "victory"
const DEFEAT := "defeat"

func emit_joystick(dx: float, dy: float) -> void:
	emit_signal(JOYSTICK_INPUT, dx, dy)

func emit_joystick_stop() -> void:
	emit_signal(JOYSTICK_STOPPED)

func emit_roster_changed(roster: Array) -> void:
	emit_signal(ROSTER_CHANGED, roster)

func emit_combat_started() -> void:
	emit_signal(COMBAT_STARTED)

func emit_wave_started(wave_index: int) -> void:
	emit_signal(WAVE_STARTED, wave_index)

func emit_victory() -> void:
	emit_signal(VICTORY)

func emit_defeat() -> void:
	emit_signal(DEFEAT)
