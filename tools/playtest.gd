extends Node
## Automated smoke test: runs the game, drives Storm with simulated input and
## saves screenshots. Not part of the game.
##
## Usage:  godot --path . res://tools/playtest.tscn -- <output_dir>

var out_dir := "user://playtest"
var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _run() -> void:
	await _wait(0.8)
	_log("start")
	await _shot("01_start")

	# Walk straight into the spike pit to check the respawn point.
	await _hold_until("move_right", func() -> bool: return main.player.controls_locked, 3.0)
	await _wait(0.8)
	_log("after spikes (should be back on safe ground, hp 4)")

	await _tap("attack")
	await _wait(0.03)
	await _shot("02_slash_hilt")

	# Back up for a running start, then jump the pit.
	await _hold("move_left", 0.4)
	_press("move_right")
	while _x() < 170.0:
		await get_tree().physics_frame
	_press("jump")
	await _wait(0.6)
	_release("jump")
	_release("move_right")
	await _wait(0.3)
	_log("after jumping the pit")

	# Test reach growth, then walk into the drop hole.
	Game.add_piece()
	Game.add_piece()
	await _tap("attack")
	await _wait(0.03)
	await _shot("03_slash_two_pieces")
	await _hold_until("move_right", func() -> bool: return main.room.room_name == "undercroft", 4.0)
	await _wait(0.8)
	_log("landed in undercroft")
	await _shot("04_undercroft")

	# Fight through to the right exit.
	var t := 0.0
	_press("move_right")
	while main.room.room_name == "undercroft" and t < 8.0:
		await _tap("attack")
		await _wait(0.35)
		t += 0.4
	_release("move_right")
	await _wait(0.6)
	_log("after undercroft")
	await _shot("05_great_hall")
	get_tree().quit()


func _x() -> float:
	return main.player.global_position.x


func _hold_until(action: String, done: Callable, timeout: float) -> void:
	_press(action)
	var t := 0.0
	while not done.call() and t < timeout:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	_release(action)
	print("[playtest]   held %s for %.2fs" % [action, t])


func _log(label: String) -> void:
	print("[playtest] %s: room=%s pos=%s vel=%s floor=%s hp=%d pieces=%d" % [
		label, main.room.room_name, main.player.global_position.round(), main.player.velocity.round(), main.player.is_on_floor(), main.player.hp, Game.pieces,
	])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _hold(action: String, seconds: float) -> void:
	_press(action)
	await _wait(seconds)
	_release(action)


func _tap(action: String) -> void:
	_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_release(action)


func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(name_ + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[playtest] saved ", path)


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)


func _release(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = false
	Input.parse_input_event(e)
