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
## Rooms Storm has been in, for the map.
var visited := {}

## The save (progress) and the settings live in the user's data folder.
const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
## Settings: volumes from 0 to 1 for the "Music" and "SFX" audio buses, and fullscreen.
var music_volume := 0.8
var sfx_volume := 0.8
var fullscreen := true


func _ready() -> void:
	_setup_input()
	_setup_audio_buses()
	load_settings()


# --- Saving ---

## Wipes progress for a new game (the save file is only replaced at the next save).
func new_game() -> void:
	abilities = {}
	pieces = 0
	max_hp = 5
	max_flasks = 3
	flasks = max_flasks
	rest_room = ""
	rest_point = Vector2.ZERO
	defeated = {}
	collected = {}
	visited = {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Writes progress. Called whenever something worth keeping happens: resting at a shrine,
## a pickup, a boss beaten.
func save_game() -> void:
	var data := {
		"abilities": abilities.keys(), "max_hp": max_hp, "max_flasks": max_flasks,
		"rest_room": rest_room, "rest_point": [rest_point.x, rest_point.y],
		"defeated": defeated.keys(), "collected": collected.keys(), "visited": visited.keys(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


## Reads progress back; false if there's no save (or it can't be read).
func load_game() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	new_game()
	for ability in data.get("abilities", []):
		abilities[ability] = true
		if ability in BLADE_ABILITIES:
			pieces += 1
	max_hp = int(data.get("max_hp", 5))
	max_flasks = int(data.get("max_flasks", 3))
	flasks = max_flasks
	rest_room = str(data.get("rest_room", ""))
	var point: Array = data.get("rest_point", [0, 0])
	rest_point = Vector2(point[0], point[1])
	for id in data.get("defeated", []):
		defeated[id] = true
	for id in data.get("collected", []):
		collected[id] = true
	for room in data.get("visited", []):
		visited[room] = true
	return true


# --- Settings ---

func _setup_audio_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), music_volume <= 0.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), sfx_volume <= 0.0)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"music_volume": music_volume, "sfx_volume": sfx_volume, "fullscreen": fullscreen,
		}, "\t"))


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if typeof(data) == TYPE_DICTIONARY:
			music_volume = clampf(float(data.get("music_volume", music_volume)), 0.0, 1.0)
			sfx_volume = clampf(float(data.get("sfx_volume", sfx_volume)), 0.0, 1.0)
			fullscreen = bool(data.get("fullscreen", fullscreen))
	apply_settings()


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
	save_game()


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
	save_game()


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
	save_game()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		fullscreen = not fullscreen
		apply_settings()
		save_settings()


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
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])
	_bind("map", [KEY_M, KEY_TAB], [JOY_BUTTON_BACK], [])
	_bind("interact", [KEY_E, KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [])
	_bind("toggle_fullscreen", [KEY_F11], [], [])
	_bind("debug_unlock_dash", [KEY_1], [], [])
	_bind("debug_unlock_shockline", [KEY_2], [], [])
	_bind("debug_unlock_double_jump", [KEY_3], [], [])
	_bind("debug_unlock_wall_jump", [KEY_4], [], [])
	_bind("debug_defeat_boss", [KEY_5], [], [])
	_bind("debug_warp_village", [KEY_6], [], [])
	_bind("debug_warp_frost_arena", [KEY_7], [], [])
	_bind("debug_warp_frost_throne", [KEY_8], [], [])
	_bind("debug_warp_crossroads", [KEY_9], [], [])
	_bind("debug_reveal_map", [KEY_0], [], [])


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
