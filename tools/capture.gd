extends "res://scripts/main.gd"
## Portfolio screenshots: loads rooms and boss fights with an invulnerable stand-in Storm
## and saves bursts of 960x540 frames into press/raw/ (not committed), for
## tools/make_portfolio_shots.py to pick from. Not part of the game. Run it with
##   Godot_console.exe --path . res://tools/capture.tscn
## (set SHOT=room1,room2 to capture only some). The save is put back as it was when it
## finishes (rooms are marked visited and abilities granted quietly, but a pickup Storm
## walks over would still save).

const OUT := "res://press/raw/"

## Each shot: room, door to arrive by ("" = start/boss), abilities to have, which way to
## walk (-1, 0, 1) and for how long first, then `n` frames `every` seconds apart while
## Storm keeps swinging if `attack`.
const SHOTS := [
	{"room": "landing", "door": "", "walk": 1, "walk_t": 1.0, "n": 4, "every": 0.8},
	{"room": "sunken_glade", "door": "", "walk": 1, "walk_t": 1.0, "n": 4, "every": 0.8},
	{"room": "gate_cavern", "door": "", "unlock": ["wall_jump"], "walk": 1, "walk_t": 1.5, "n": 12, "every": 0.7, "attack": true},
	{"room": "village_square", "door": "g", "walk": 1, "walk_t": 1.5, "n": 4, "every": 0.8},
	{"room": "frost_arena", "door": "k", "walk": 1, "walk_t": 1.0, "n": 12, "every": 0.7, "attack": true},
	{"room": "frost_throne", "door": "m", "unlock": ["dash"], "walk": 1, "walk_t": 1.0, "n": 12, "every": 0.7, "attack": true},
	{"room": "icefall_hall", "door": "", "walk": 1, "walk_t": 1.0, "n": 4, "every": 0.8},
	{"room": "refuge", "door": "", "walk": 1, "walk_t": 2.5, "n": 5, "every": 0.8},
	{"room": "ashen_road", "door": "", "walk": -1, "walk_t": 1.0, "n": 4, "every": 0.8},
	{"room": "forge", "door": "t", "walk": -1, "walk_t": 3.5, "n": 16, "every": 0.7, "attack": true},
	{"room": "drake_roost", "door": "w", "unlock": ["double_jump"], "walk": -1, "walk_t": 1.0, "n": 12, "every": 0.7, "attack": true},
	{"room": "storm_bridges", "door": "", "walk": 1, "walk_t": 1.0, "n": 4, "every": 0.8},
	{"room": "spire", "door": "t", "walk": 1, "walk_t": 1.0, "n": 12, "every": 0.7, "attack": true},
	{"room": "thunder_eyrie", "door": "v", "unlock": ["shockline"], "boss_dx": -110, "walk": 1, "walk_t": 0.3, "n": 20, "every": 0.7, "attack": true},
	{"room": "high_pass", "door": "", "walk": 1, "walk_t": 1.5, "n": 5, "every": 0.8},
	{"room": "windward_pass", "door": "", "walk": 1, "walk_t": 1.5, "n": 4, "every": 0.8},
	{"room": "frozen_street", "door": "", "walk": 1, "walk_t": 1.5, "n": 4, "every": 0.8},
	{"room": "rod_field", "door": "", "walk": 1, "walk_t": 1.5, "n": 4, "every": 0.8},
	{"room": "slag_works", "door": "", "walk": -1, "walk_t": 1.5, "n": 4, "every": 0.8},
]

func _ready() -> void:
	Game.fullscreen = false
	AudioServer.set_bus_mute(0, true)
	Game.apply_settings()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_tree().paused = false
	var had_save := Game.has_save()
	var save_text := FileAccess.get_file_as_string(Game.SAVE_PATH) if had_save else ""
	Game.new_game()
	for room_name in Rooms.LAYOUTS:
		Game.visited[room_name] = true  # so loading a room never saves
	var only := OS.get_environment("SHOT")
	if only == "" or "title" in only:
		var title := Title.new()
		add_child(title)
		await _wait(2.0)
		await _snap("title_00")
		title.queue_free()
	_start_world()
	hud.visible = false
	await _run()
	if only == "" or "map" in only:
		_load_room("crossroads", "p")
		map_screen.open()
		await _wait(0.5)
		await _snap("map_00")
	if had_save:
		FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE).store_string(save_text)
	elif Game.has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit()


func _physics_process(delta: float) -> void:
	super(delta)
	if player:
		player._invuln = 99.0
		player.hp = maxi(player.hp, 1)


func _run() -> void:
	var only := OS.get_environment("SHOT")
	for shot: Dictionary in SHOTS:
		if only != "" and not shot.room in only.split(","):
			continue
		for ability in shot.get("unlock", []):
			Game.abilities[ability] = true  # quietly: no pickup message or save
			Game.pieces += 1
			Game.pieces_changed.emit(Game.pieces)
		_load_room(shot.room, shot.door)
		if shot.door == "" and room.spawn_point == Vector2.ZERO:
			player.place_at(room.door_spawn(room._doors.keys()[0]))
		if shot.has("boss_dx"):
			player.place_at(room._boss_spawn + Vector2(shot.boss_dx, 0))
		camera.reset_smoothing()
		player.heal_full()
		await hud.fade_in(0.01)
		await _wait(0.3)
		var dir: int = shot.get("walk", 0)
		var action := "move_right" if dir > 0 else "move_left"
		if dir != 0:
			Input.action_press(action)
			await _wait(shot.get("walk_t", 1.0))
			Input.action_release(action)
		for i in shot.n:
			if shot.get("attack", false):
				Input.action_press("attack")
				await get_tree().physics_frame
				Input.action_release("attack")
			await _wait(shot.every)
			await _snap("%s_%02d" % [shot.room, i])


func _snap(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name_ + ".png"))


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
