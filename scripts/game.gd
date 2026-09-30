extends Node
## Global game state and input bindings. Autoloaded as "Game".

signal pieces_changed(count: int)
signal ability_unlocked(ability: String)
signal rested
signal max_hp_changed(max_hp: int)
signal flasks_changed(count: int, max_count: int)

## Art is drawn at 2x the world's pixel density: the world uses 16 px tiles, sprites use 32.
## Sprites are placed at 1 / ART_SCALE and the camera zooms by ART_SCALE.
const ART_SCALE := 2.0
const MAX_PIECES := 3
## Attack reach with only the shard (or the hilt), and how much each recovered piece adds.
const BASE_REACH := 27.0
const REACH_PER_PIECE := 9.0

## Abilities unlocked so far. The blade pieces each grant one: "dash" (ice),
## "double_jump" (fire) or "shockline" (lightning). "wall_jump" isn't a piece: it's
## Storm learning to hook the hilt's sword catcher into walls, found in the tutorial.
const BLADE_ABILITIES := ["dash", "double_jump", "shockline"]
var abilities := {}
var pieces := 0
var max_hp := 5
## Healing flasks, filled with a shrine's pale flame: a few sips carried at a time, each
## mending FLASK_HEAL masks, all refilled whenever Storm rests at a shrine (or wakes at one).
const FLASK_HEAL := 2
var max_flasks := 3
var flasks := 3

## Where Storm wakes after falling: the last rest shrine he touched ("" = the start).
var rest_room := ""
var rest_point := Vector2.ZERO
## Bosses beaten and one-time pickups taken, by id, so they stay gone.
var defeated := {}
var collected := {}


func _ready() -> void:
	_setup_input()


func blade_reach() -> float:
	return BASE_REACH + REACH_PER_PIECE * pieces


## How much of the blade has been reforged, as named in art/storm/ and art/blade/:
## "bare" (Storm wakes with only a rag-wrapped shard), "hilt" (the hilt recovered, with its
## sword catcher: the wall jump), then "ice", "ice_fire", "ice_lightning" or "full". Ice is
## always first; an order the game doesn't allow (a debug unlock without ice) shows the hilt.
func blade_stage() -> String:
	if not has_ability("dash"):
		return "hilt" if has_ability("wall_jump") else "bare"
	var fire := has_ability("double_jump")
	var lightning := has_ability("shockline")
	if fire and lightning:
		return "full"
	if fire:
		return "ice_fire"
	if lightning:
		return "ice_lightning"
	return "ice"


func rest_at(room: String, point: Vector2) -> void:
	rest_room = room
	rest_point = point
	refill_flasks()
	rested.emit()


func refill_flasks() -> void:
	flasks = max_flasks
	flasks_changed.emit(flasks, max_flasks)


## Spends one flask; false if they're all empty.
func use_flask() -> bool:
	if flasks <= 0:
		return false
	flasks -= 1
	flasks_changed.emit(flasks, max_flasks)
	return true


## A mask shard: one more point of health, for good.
func add_mask(id: String) -> void:
	if collected.has(id):
		return
	collected[id] = true
	max_hp += 1
	max_hp_changed.emit(max_hp)


func has_ability(ability: String) -> bool:
	return abilities.has(ability)


func unlock(ability: String) -> void:
	if abilities.has(ability):
		return
	abilities[ability] = true
	if ability in BLADE_ABILITIES:
		pieces += 1
		pieces_changed.emit(pieces)
	ability_unlocked.emit(ability)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("look_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("look_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind("jump", [KEY_SPACE, KEY_Z, KEY_K], [JOY_BUTTON_A], [])
	_bind("attack", [], [JOY_BUTTON_X], [], [MOUSE_BUTTON_LEFT])
	_bind("dash", [KEY_SHIFT, KEY_L, KEY_C], [JOY_BUTTON_RIGHT_SHOULDER], [])
	_bind("shockline", [], [JOY_BUTTON_Y], [], [MOUSE_BUTTON_RIGHT])
	_bind("heal", [KEY_F, KEY_Q], [JOY_BUTTON_B], [])
	_bind("interact", [KEY_E, KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [])
	_bind("toggle_fullscreen", [KEY_F11], [], [])
	_bind("debug_unlock_dash", [KEY_1], [], [])
	_bind("debug_unlock_shockline", [KEY_2], [], [])
	_bind("debug_unlock_double_jump", [KEY_3], [], [])
	_bind("debug_unlock_wall_jump", [KEY_4], [], [])
	_bind("debug_defeat_boss", [KEY_5], [], [])


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
