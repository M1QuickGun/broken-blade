extends "res://scripts/main.gd"
## A quick look at the game for checking visuals (not part of the game): loads the rooms
## named in the LOOK environment variable with every ability, an invulnerable Storm and the
## HUD showing, and saves frames as PNGs into LOOK_OUT (a folder outside the project).
##
##     LOOK="throne_approach:i:12:0.6:fight,refuge" LOOK_OUT="C:/tmp/shots" \
##         Godot_console.exe --path . res://tools/look.tscn
##
## Each entry is room[:door[:seconds[:every[:mode]]]]; mode "fight" walks Storm at the boss
## and keeps him swinging ("phase2" also finishes the boss's first phase early), "walk" walks
## him right, "sign" shows a sign's text, "up" puts him at the top of the room's climb,
## anything else
## stands still. Nothing is saved (Game.no_save).

var _out := ""


func _ready() -> void:
	Game.no_save = true
	Game.window_mode = "windowed"
	Game.window_size = 0
	AudioServer.set_bus_mute(0, true)
	Game.apply_settings()
	get_tree().paused = false
	_out = OS.get_environment("LOOK_OUT")
	if _out == "":
		_out = OS.get_user_data_dir() + "/look"
	DirAccess.make_dir_recursive_absolute(_out)
	Game.new_game()
	for ability in ["wall_jump", "dash", "double_jump", "shockline"]:
		Game.abilities[ability] = true
	Game.pieces = 3
	Game.max_hp = 9
	for room_name in Rooms.LAYOUTS:
		Game.visited[room_name] = true
	_start_world()
	for entry in OS.get_environment("LOOK").split(",", false):
		var parts := entry.split(":")
		var room_name := parts[0]
		var door := parts[1] if parts.size() > 1 else ""
		var seconds := float(parts[2]) if parts.size() > 2 else 2.0
		var every := float(parts[3]) if parts.size() > 3 else 0.5
		var mode := parts[4] if parts.size() > 4 else ""
		await _look(room_name, door, seconds, every, mode)
	get_tree().quit()


func _physics_process(delta: float) -> void:
	super(delta)
	if player:
		player._invuln = 99.0
		player.hp = maxi(player.hp, 1)


func _look(room_name: String, door: String, seconds: float, every: float, mode: String) -> void:
	_load_room(room_name, door)
	if door == "" and room.spawn_point == Vector2.ZERO:
		player.place_at(room.door_spawn(room._doors.keys()[0]))
	camera.position = Vector2.ZERO
	camera.reset_smoothing()
	await hud.fade_in(0.01)
	_transitioning = false
	player.controls_locked = false
	if mode == "up":
		# Stand him by the room's crown cache, to look at the top of a climb.
		for y in room.size_tiles.y:
			var x: int = String(Rooms.LAYOUTS[room_name][y]).find("C")
			if x >= 0:
				player.place_at(Vector2((x - 3 + 0.5) * Rooms.TILE, (y + 1) * Rooms.TILE))
				camera.reset_smoothing()
	if mode == "sign":
		var texts: Array = Rooms.SIGNS.get(room_name, ["A sign, to read the lettering by: The quick brown fox, 1234567890."])
		hud.show_message(texts[0])
	var t := 0.0
	var shot := 0
	while t < seconds:
		var step := minf(every, seconds - t)
		if mode == "phase2" and t >= 6.0 and t < 6.0 + every:
			# Straight to the boss's next phase.
			var boss = get_tree().get_first_node_in_group("boss")
			if boss:
				boss.hp = 1
				boss.take_hit(1, Vector2.RIGHT)
		if mode == "fight" or mode == "phase2":
			var boss = get_tree().get_first_node_in_group("boss")
			var target_x: float = boss.global_position.x if boss else room.size_px.x * 0.6
			var gap := target_x - player.global_position.x
			Input.action_release("move_left")
			Input.action_release("move_right")
			if absf(gap) > 40.0:
				Input.action_press("move_right" if gap > 0.0 else "move_left")
			Input.action_press("attack")
			await get_tree().physics_frame
			Input.action_release("attack")
		elif mode == "walk":
			Input.action_press("move_right")
		await get_tree().create_timer(step).timeout
		t += step
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%02d.png" % [_out, room_name, shot])
		shot += 1
	Input.action_release("move_right")
	Input.action_release("move_left")
