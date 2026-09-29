extends Node
## Global game state and input bindings. Autoloaded as "Game".

signal pieces_changed(count: int)
signal ability_unlocked(ability: String)

const MAX_PIECES := 3
## Attack reach with only the hilt, and how much each recovered piece adds.
const BASE_REACH := 22.0
const REACH_PER_PIECE := 10.0

## Blade pieces recovered so far. Each one grants an ability: "dash" (ice),
## "double_jump" (fire) or "shockline" (lightning).
var abilities := {}
var pieces := 0
var max_hp := 5


func _ready() -> void:
	_setup_input()


func blade_reach() -> float:
	return BASE_REACH + REACH_PER_PIECE * pieces


func has_ability(ability: String) -> bool:
	return abilities.has(ability)


func unlock(ability: String) -> void:
	if abilities.has(ability):
		return
	abilities[ability] = true
	pieces = abilities.size()
	pieces_changed.emit(pieces)
	ability_unlocked.emit(ability)


func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("look_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("look_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind("jump", [KEY_SPACE, KEY_Z, KEY_K], [JOY_BUTTON_A], [])
	_bind("attack", [], [JOY_BUTTON_X], [], [MOUSE_BUTTON_LEFT])
	_bind("dash", [KEY_SHIFT, KEY_L, KEY_C], [JOY_BUTTON_RIGHT_SHOULDER], [])
	_bind("shockline", [], [JOY_BUTTON_Y], [], [MOUSE_BUTTON_RIGHT])
	_bind("debug_unlock_dash", [KEY_F1], [], [])
	_bind("debug_unlock_shockline", [KEY_F2], [], [])


## Adds an action with default bindings, unless it's already defined in Project Settings.
func _bind(action: String, keys: Array, buttons: Array, axes: Array, mouse: Array = []) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.4)
	for key in keys:
		var e := InputEventKey.new()
		e.physical_keycode = key
		InputMap.action_add_event(action, e)
	for button in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		InputMap.action_add_event(action, e)
	for axis in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = axis[0]
		e.axis_value = axis[1]
		InputMap.action_add_event(action, e)
	for mouse_button in mouse:
		var e := InputEventMouseButton.new()
		e.button_index = mouse_button
		InputMap.action_add_event(action, e)
