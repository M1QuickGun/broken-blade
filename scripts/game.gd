extends Node
## Global game state and input bindings. Autoloaded as "Game".

signal pieces_changed(count: int)
signal ability_unlocked(ability: String)
signal rested
signal max_hp_changed(max_hp: int)
signal flasks_changed(count: int, max_count: int)
signal crowns_changed(count: int)
signal achieved(title: String)

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
## Crowns, the old kingdom's coin: carried, and (after a fall) left behind in a purse where
## he last stood, until he takes it back or falls again.
var crowns := 0
var lost_crowns := 0
var lost_room := ""
var lost_point := Vector2.ZERO
## Bought from the refuge: how many times Bram has honed the blade, and Wren's area maps.
var hone := 0
var maps := {}
## Survivors found out in the world (they make for the refuge), and their gifts given.
var rescued := {}
## The journal: foes put down (Rooms.BESTIARY ids), and the signs and notes read, in order.
var journal := {}
var lore: Array = []
## Shrines Storm has rested at, to travel between: "room:x,y" -> [room, x, y].
var shrines := {}
## Pins Storm has put on the map (in map tiles).
var pins: Array = []
## The boss rush (from the title, once the end's been seen): every boss in turn on one life
## of masks, nothing saved but the best time.
var boss_rush := false
## The demo build (exported with the "demo" feature): the Foothills and the Frozen village.
var demo := OS.has_feature("demo")
const DEMO_REGIONS := ["foothills", "ice"]
var rush_best := 0.0
const RUSH := [["gate_cavern", "f"], ["frost_arena", "k"], ["frost_throne", "m"], ["forge", "t"],
	["drake_roost", "w"], ["spire", "t"], ["thunder_eyrie", "v"], ["mirror_hall", "m"], ["throne_room", "j"]]
## What counts toward a save's completion, and how many of each there are.
const COMPLETION := {"bosses": 10, "elites": 5, "survivors": 5, "masks": 19, "flasks": 6, "rooms": 72, "trials": 6}

## A blow of the blade: two, and one more for each time Bram has honed it.
const BASE_DAMAGE := 2

## The saves (three slots of progress) and the settings live in the user's data folder.
const SAVE_PATH := "user://save_%d.json"
## The single save from before there were slots; moved into slot 1 the first time.
const OLD_SAVE_PATH := "user://save.json"
const SLOTS := 3
## Bumped when the save's contents change shape; loading fills in anything older saves lack.
const SAVE_VERSION := 2
## Which slot is being played.
var slot := 1
## Time played on this save, in seconds (counted while a game is running and unpaused).
var play_time := 0.0
var playing := false
## Settings: the camera shaking on big blows, the play timer on screen, and keys chosen in
## place of the defaults (action -> physical keycode).
var screen_shake := true
var show_timer := false
var bindings := {}
## Achievements earned on any save (kept with the settings); ready to hand to Steam.
var achievements := {}
## Hard mode (for this save): every foe a half again as tough, every blow on Storm doubled.
var hard := false
const ACHIEVEMENTS := {
	"hilt": ["Hilt in Hand", "Take the hilt back from the Guardian Centipede."],
	"ice": ["Cold Steel", "Free the ice piece."],
	"fire": ["Forged Again", "Free the fire piece."],
	"lightning": ["Point of the Storm", "Free the lightning tip."],
	"unbound": ["All Unbound", "Beat every boss's second fight."],
	"elites": ["Champion of the Mountain", "Put down every region's elite."],
	"survivors": ["No One Left Behind", "Bring every lost survivor to the refuge."],
	"dark_storm": ["Know Thyself", "Shatter Dark Storm."],
	"ransom": ["A King's Ransom", "Carry a thousand crowns."],
	"trials": ["Tried and True", "Open every trial's chest."],
	"ending": ["The Keeper", "Reseal the evil."],
	"hard_ending": ["The Long Watch", "Reseal the evil in hard mode."],
}
## The actions that can be rebound, with their names on the controls screen.
const REBINDABLE := [["jump", "Jump"], ["attack", "Attack"], ["dash", "Dash / slide"],
	["shockline", "Shockline"], ["heal", "Drink a flask"], ["interact", "Talk / trade"], ["map", "Map"]]
const SETTINGS_PATH := "user://settings.json"
## Settings: volumes from 0 to 1 for the "Music" and "SFX" audio buses, and fullscreen.
var music_volume := 0.8
var sfx_volume := 0.8
var fullscreen := true
## Video: the window ("fullscreen", "borderless" or "windowed"), its size when windowed,
## vsync, a frame-rate cap (0 = none), and whole-number scaling of the picture.
var window_mode := "fullscreen"
var window_size := 0
var vsync := true
var fps_cap := 0
var pixel_perfect := false
const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const FPS_CAPS := [0, 30, 60, 120, 144]
## Accessibility: fewer and softer flashes, the whole game slowed, and every blow on Storm
## taking only one mask.
var reduce_flashes := false
var game_speed := 1.0
var gentle := false


## The game's lettering (art/font/broken_blade.ttf), crisp, with the system font behind it
## for any character it lacks.
var font: FontFile


func _ready() -> void:
	font = load("res://art/font/broken_blade.ttf")
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.fallbacks = [SystemFont.new()]
	# Text in the HUD and its panels is laid out at half size and the whole layer drawn at 2x;
	# rendering the letters at twice the size keeps every pixel of the font whole (at 1x
	# they were rasterized at half its native size and came out unreadable).
	font.oversampling = ART_SCALE
	_setup_input()
	_setup_audio_buses()
	load_settings()
	if DisplayServer.get_name() != "headless" and FileAccess.file_exists(OLD_SAVE_PATH) 			and not FileAccess.file_exists(SAVE_PATH % 1):
		DirAccess.rename_absolute(OLD_SAVE_PATH, SAVE_PATH % 1)


func _process(delta: float) -> void:
	if playing and not get_tree().paused:
		play_time += delta


## Whether the last thing pressed was on a controller (prompts name its buttons then).
var using_pad := false
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_START: "Start",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
}


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		using_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_pad = false


## How to press an action, for the device in use: "Space", "Left mouse", "A", "RB"...
## "move", "up" and "down" name the stick or the keys.
func prompt(action: String) -> String:
	match action:
		"move":
			return "Left stick" if using_pad else "%s / %s" % [_first_key("move_left"), _first_key("move_right")]
		"up":
			return "Up on the stick" if using_pad else _first_key("look_up")
		"down":
			return "Down on the stick" if using_pad else _first_key("look_down")
	if using_pad:
		for e in InputMap.action_get_events(action) if InputMap.has_action(action) else []:
			if e is InputEventJoypadButton:
				return PAD_NAMES.get(e.button_index, "Button %d" % e.button_index)
	return _first_key(action)


func _first_key(action: String) -> String:
	if not InputMap.has_action(action):
		return action
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return OS.get_keycode_string(e.physical_keycode)
		if e is InputEventMouseButton:
			return "Left click" if e.button_index == MOUSE_BUTTON_LEFT else "Right click"
	return action


## Fills {action} in a line of text with how to press it.
func fill_prompts(text: String) -> String:
	var regex := RegEx.create_from_string(r"\{(\w+)\}")
	for m in regex.search_all(text):
		text = text.replace(m.get_string(), prompt(m.get_string(1)))
	return text


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
	crowns = 0
	lost_crowns = 0
	lost_room = ""
	lost_point = Vector2.ZERO
	hone = 0
	maps = {}
	rescued = {}
	play_time = 0.0
	hard = false
	journal = {}
	lore = []
	shrines = {}
	pins = []


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH % slot) or FileAccess.file_exists(SAVE_PATH % slot + ".bak")


## What a slot holds, for the title screen: {} if it's empty.
func slot_summary(n: int) -> Dictionary:
	var data = read_json(SAVE_PATH % n)
	if data == null:
		return {}
	var count := 0
	for ability in data.get("abilities", []):
		if ability in BLADE_ABILITIES:
			count += 1
	return {"pieces": count, "time": float(data.get("play_time", 0.0)), "room": str(data.get("rest_room", "")),
		"done": "hollow_king" in data.get("defeated", []), "hard": bool(data.get("hard", false)),
		"completion": int(data.get("completion", 0))}


## Whether any save has seen the end (hard mode opens then).
func any_finished() -> bool:
	for n in range(1, SLOTS + 1):
		if slot_summary(n).get("done", false):
			return true
	return false


func erase_slot(n: int) -> void:
	for path in [SAVE_PATH % n, SAVE_PATH % n + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


static func clock(seconds: float) -> String:
	var t := int(seconds)
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]


## Writes progress. Called whenever something worth keeping happens: resting at a shrine,
## a pickup, a boss beaten.
func save_game() -> void:
	if DisplayServer.get_name() == "headless":
		return  # a headless test run: never touch the player's real save
	if boss_rush:
		return  # (the rush keeps nothing but its best time)
	var data := {
		"abilities": abilities.keys(), "max_hp": max_hp, "max_flasks": max_flasks,
		"rest_room": rest_room, "rest_point": [rest_point.x, rest_point.y],
		"defeated": defeated.keys(), "collected": collected.keys(), "visited": visited.keys(),
		"crowns": crowns, "lost_crowns": lost_crowns, "lost_room": lost_room,
		"lost_point": [lost_point.x, lost_point.y], "hone": hone, "maps": maps.keys(),
		"rescued": rescued.keys(), "play_time": play_time, "journal": journal.keys(), "lore": lore, "hard": hard, "shrines": shrines.values(), "pins": pins.map(func(p: Vector2) -> Array: return [p.x, p.y]),
	}
	data["version"] = SAVE_VERSION
	data["completion"] = completion()
	check_achievements()
	write_safely(SAVE_PATH % slot, JSON.stringify(data, "\t"))


## Writes a file so a crash or power cut mid-write can't ruin it: to a temporary file first,
## then swapped in, the old one kept as "<path>.bak" (loading falls back to it).
static func write_safely(path: String, text: String) -> void:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_error("Couldn't write %s" % temp)
		return
	file.store_string(text)
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	DirAccess.rename_absolute(temp, path)


## A save's contents, or the backup's if the save itself can't be read; null if neither.
static func read_json(path: String):
	for candidate in [path, path + ".bak"]:
		if FileAccess.file_exists(candidate):
			var data = JSON.parse_string(FileAccess.get_file_as_string(candidate))
			if typeof(data) == TYPE_DICTIONARY:
				return data
	return null


## Reads progress back; false if there's no save (or it can't be read).
func load_game() -> bool:
	if not has_save():
		return false
	var data = read_json(SAVE_PATH % slot)
	if data == null:
		return false
	new_game()
	play_time = float(data.get("play_time", 0.0))
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
	crowns = int(data.get("crowns", 0))
	lost_crowns = int(data.get("lost_crowns", 0))
	lost_room = str(data.get("lost_room", ""))
	var lost: Array = data.get("lost_point", [0, 0])
	lost_point = Vector2(lost[0], lost[1])
	hone = int(data.get("hone", 0))
	for region in data.get("maps", []):
		maps[region] = true
	for id in data.get("rescued", []):
		rescued[id] = true
	for id in data.get("journal", []):
		journal[id] = true
	hard = bool(data.get("hard", false))
	for p in data.get("pins", []):
		pins.append(Vector2(p[0], p[1]))
	for entry in data.get("shrines", []):
		shrines["%s:%d,%d" % [entry[0], entry[1], entry[2]]] = [str(entry[0]), float(entry[1]), float(entry[2])]
	if rest_room != "" and shrines.is_empty():
		# (An older save: at least the shrine it wakes at.)
		shrines["%s:%d,%d" % [rest_room, rest_point.x, rest_point.y]] = [rest_room, rest_point.x, rest_point.y]
	lore = Array(data.get("lore", []))
	return true


# --- Crowns ---

## How much of the game this save has found, as a percentage.
func completion() -> int:
	var bosses := 0
	var elites := 0
	for id in defeated:
		if id in ["brood_mother", "frost_knight", "cinder_brute", "storm_herald", "guard_captain"]:
			elites += 1
		else:
			bosses += 1
	var found: int = mini(bosses, COMPLETION.bosses) + mini(elites, COMPLETION.elites) \
		+ mini(rescued.size(), COMPLETION.survivors) + clampi(max_hp - 5, 0, COMPLETION.masks) \
		+ clampi(max_flasks - 3, 0, COMPLETION.flasks) + mini(visited.size(), COMPLETION.rooms) 		+ mini(_trials_done(), COMPLETION.trials)
	var total := 0
	for key in COMPLETION:
		total += COMPLETION[key]
	return roundi(100.0 * found / total)


func _trials_done() -> int:
	var done := 0
	for id in collected:
		if str(id).begins_with("chest:"):
			done += 1
	return done


## Ready for the boss rush: every ability, a full set of masks and flasks, nothing beaten.
func start_boss_rush() -> void:
	new_game()
	boss_rush = true
	for ability in ["wall_jump", "dash", "double_jump", "shockline"]:
		abilities[ability] = true
	pieces = 3
	max_hp = 9
	max_flasks = 5
	flasks = 5
	hone = 1


## Earns whatever achievements this save now qualifies for (checked at every save).
func check_achievements() -> void:
	var has := func(ids: Array) -> bool: return ids.all(func(id: String) -> bool: return defeated.has(id))
	var earned := {
		"hilt": defeated.has("centipede_1"), "ice": defeated.has("colossus_1"), "fire": defeated.has("drake_1"),
		"lightning": defeated.has("stormcaller_1"),
		"unbound": has.call(["centipede_2", "colossus_2", "drake_2", "stormcaller_2"]),
		"elites": has.call(["brood_mother", "frost_knight", "cinder_brute", "storm_herald", "guard_captain"]),
		"survivors": rescued.size() >= 5, "dark_storm": defeated.has("dark_storm"), "ransom": crowns >= 1000, "trials": _trials_done() >= 6,
		"ending": defeated.has("hollow_king"), "hard_ending": hard and defeated.has("hollow_king"),
	}
	for id in earned:
		if earned[id] and not achievements.has(id):
			achievements[id] = true
			achieved.emit(ACHIEVEMENTS[id][0])
			save_settings()


## A foe put down, for the bestiary.
func note(id: String) -> void:
	journal[id] = true


func read_lore(text: String) -> void:
	if text != "" and text not in lore:
		lore.append(text)


func blade_damage() -> int:
	return BASE_DAMAGE + hone


func add_crowns(count: int) -> void:
	crowns += count
	crowns_changed.emit(crowns)


## Pays `count` crowns if Storm has them; false if he can't afford it.
func spend(count: int) -> bool:
	if crowns < count:
		return false
	crowns -= count
	crowns_changed.emit(crowns)
	save_game()
	return true


## Storm fell: what he carried stays behind where he last stood (any purse left from an
## earlier fall is lost).
func drop_crowns(room: String, point: Vector2) -> void:
	lost_crowns = crowns
	lost_room = room if crowns > 0 else ""
	lost_point = point
	crowns = 0
	crowns_changed.emit(crowns)


func recover_crowns() -> void:
	add_crowns(lost_crowns)
	lost_crowns = 0
	lost_room = ""
	save_game()


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
	Engine.time_scale = game_speed
	Engine.max_fps = fps_cap
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if pixel_perfect \
		else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	fullscreen = window_mode != "windowed"
	match window_mode:
		"fullscreen":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen := DisplayServer.window_get_current_screen()
			DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
			DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
		_:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size: Vector2i = WINDOW_SIZES[clampi(window_size, 0, WINDOW_SIZES.size() - 1)]
			DisplayServer.window_set_size(size)
			var screen := DisplayServer.window_get_current_screen()
			DisplayServer.window_set_position(DisplayServer.screen_get_position(screen)
				+ (DisplayServer.screen_get_size(screen) - size) / 2)


func save_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return  # a headless test run: never touch the player's settings
	write_safely(SETTINGS_PATH, JSON.stringify({
			"music_volume": music_volume, "sfx_volume": sfx_volume, "fullscreen": fullscreen,
			"screen_shake": screen_shake, "show_timer": show_timer, "bindings": bindings,
			"achievements": achievements.keys(), "window_mode": window_mode, "window_size": window_size,
			"vsync": vsync, "fps_cap": fps_cap, "pixel_perfect": pixel_perfect, "reduce_flashes": reduce_flashes,
			"game_speed": game_speed, "gentle": gentle, "rush_best": rush_best,
		}, "\t"))


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if typeof(data) == TYPE_DICTIONARY:
			music_volume = clampf(float(data.get("music_volume", music_volume)), 0.0, 1.0)
			sfx_volume = clampf(float(data.get("sfx_volume", sfx_volume)), 0.0, 1.0)
			fullscreen = bool(data.get("fullscreen", fullscreen))
			window_mode = str(data.get("window_mode", "fullscreen" if fullscreen else "windowed"))
			window_size = int(data.get("window_size", window_size))
			vsync = bool(data.get("vsync", vsync))
			fps_cap = int(data.get("fps_cap", fps_cap))
			pixel_perfect = bool(data.get("pixel_perfect", pixel_perfect))
			reduce_flashes = bool(data.get("reduce_flashes", reduce_flashes))
			game_speed = clampf(float(data.get("game_speed", game_speed)), 0.5, 1.0)
			gentle = bool(data.get("gentle", gentle))
			rush_best = float(data.get("rush_best", 0.0))
			screen_shake = bool(data.get("screen_shake", screen_shake))
			show_timer = bool(data.get("show_timer", show_timer))
			for id in data.get("achievements", []):
				achievements[id] = true
			var keys = data.get("bindings", {})
			if typeof(keys) == TYPE_DICTIONARY:
				for action in keys:
					rebind(action, int(keys[action]), false)
	apply_settings()


## Puts `keycode` in place of an action's keyboard keys (its mouse and controller buttons
## stay).
func rebind(action: String, keycode: int, save := true) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			InputMap.action_erase_event(action, e)
	var key := InputEventKey.new()
	key.physical_keycode = keycode as Key
	InputMap.action_add_event(action, key)
	bindings[action] = keycode
	if save:
		save_settings()


## The keyboard key(s) on an action, for showing.
func key_names(action: String) -> String:
	var names := []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			names.append(OS.get_keycode_string(e.physical_keycode))
		elif e is InputEventMouseButton:
			names.append("Left mouse" if e.button_index == MOUSE_BUTTON_LEFT else "Right mouse")
	return ", ".join(names) if not names.is_empty() else "-"


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
	shrines["%s:%d,%d" % [room, point.x, point.y]] = [room, point.x, point.y]
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


## A flask found: one more to carry, for good.
func add_flask(id: String) -> void:
	if collected.has(id):
		return
	collected[id] = true
	max_flasks += 1
	refill_flasks()
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
		window_mode = "fullscreen" if fullscreen else "windowed"
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
	_bind("debug_warp_forge", [KEY_MINUS], [], [])
	_bind("debug_warp_roost", [KEY_EQUAL], [], [])
	_bind("debug_warp_spire", [KEY_BRACKETLEFT], [], [])
	_bind("debug_warp_eyrie", [KEY_BRACKETRIGHT], [], [])
	_bind("debug_warp_castle", [KEY_BACKSLASH], [], [])
	_bind("debug_warp_throne", [KEY_APOSTROPHE], [], [])
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
