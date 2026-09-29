extends Node
## Global game state and input bindings. Autoloaded as "Game".

signal pieces_changed(count: int)

const MAX_PIECES := 3
## Attack reach with only the hilt, and how much each recovered piece adds.
const BASE_REACH := 22.0
const REACH_PER_PIECE := 10.0

var pieces := 0
var max_hp := 5
## Ids of one-time pickups that have already been taken.
var collected := {}


func _ready() -> void:
	_setup_input()


func blade_reach() -> float:
	return BASE_REACH + REACH_PER_PIECE * pieces


func add_piece() -> void:
	if pieces >= MAX_PIECES:
		return
	pieces += 1
	pieces_changed.emit(pieces)


func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("look_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("look_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind("jump", [KEY_SPACE, KEY_Z, KEY_K], [JOY_BUTTON_A], [])
	_bind("attack", [KEY_J, KEY_X], [JOY_BUTTON_X], [])
	_bind("debug_add_piece", [KEY_F1], [], [])


## Adds an action with default bindings, unless it's already defined in Project Settings.
func _bind(action: String, keys: Array, buttons: Array, axes: Array) -> void:
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
