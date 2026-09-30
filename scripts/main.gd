extends Node2D
## Owns the player, camera and HUD, and swaps rooms as Storm walks through doors.

const Rooms := preload("res://scripts/rooms.gd")
const Room := preload("res://scripts/room.gd")
const Player := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")

const START_ROOM := "landing"
const DOOR_FADE := 0.15
## How far past the room's edges Storm can go before he's put back on solid ground.
const OUT_OF_BOUNDS_MARGIN := 48.0

var room: Node2D
var player: CharacterBody2D
var camera: Camera2D
var hud: CanvasLayer

var _transitioning := false


func _ready() -> void:
	# Hide the cursor while playing and keep clicks inside the window.
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN

	player = Player.new()
	add_child(player)

	camera = Camera2D.new()
	# The world stays in 1x units (16 px tiles); the 960x540 viewport shows it at 2x so art
	# can be drawn at double detail and placed at 0.5 scale.
	camera.zoom = Vector2(Game.ART_SCALE, Game.ART_SCALE)
	camera.offset = Vector2(0, -11)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)

	hud = Hud.new()
	add_child(hud)
	hud.set_hp(player.hp, Game.max_hp)

	player.hp_changed.connect(hud.set_hp)
	player.hit_hazard.connect(_on_player_hit_hazard)
	player.died.connect(_on_player_died)

	_load_room(START_ROOM, "")
	hud.show_message("Broken Blade")


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("debug_unlock_dash"):
		Game.unlock("dash")
	elif event.is_action_pressed("debug_unlock_shockline"):
		Game.unlock("shockline")
	elif event.is_action_pressed("debug_unlock_double_jump"):
		Game.unlock("double_jump")
	elif event.is_action_pressed("debug_unlock_wall_jump"):
		Game.unlock("wall_jump")


## Loads a room and puts Storm at a door (or at the room's start with door ""), or at
## `at` when given (waking at a rest shrine).
func _load_room(room_name: String, door: String, at := Vector2.INF) -> void:
	if room:
		remove_child(room)
		room.queue_free()
	room = Room.new()
	room.build(room_name)
	add_child(room)
	move_child(room, 0)
	room.door_entered.connect(_on_door_entered)
	room.sign_read.connect(hud.show_message)
	room.boss_defeated.connect(func(title: String) -> void: hud.show_message("%s falls." % title))
	Music.play(Rooms.MUSIC.get(room_name, Rooms.DEFAULT_MUSIC))

	if at != Vector2.INF:
		player.place_at(at)
	else:
		player.place_at(room.spawn_point if door == "" else room.door_spawn(door))
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(room.size_px.x)
	camera.limit_bottom = int(room.size_px.y)
	camera.reset_smoothing()


func _on_door_entered(door: String) -> void:
	if _transitioning:
		return
	var link: Array = Rooms.LINKS[room.room_name][door]
	_transitioning = true
	player.controls_locked = true
	await hud.fade_out(DOOR_FADE)
	_load_room(link[0], link[1])
	await get_tree().physics_frame
	camera.reset_smoothing()
	# Hand control back only once doors work again, or turning straight around
	# walks Storm through a dead door and off the edge of the room.
	await hud.fade_in(DOOR_FADE)
	player.controls_locked = false
	_transitioning = false


func _on_player_hit_hazard() -> void:
	await hud.fade_out(0.2)
	player.respawn_at_safe()
	await get_tree().physics_frame
	camera.reset_smoothing()
	player.controls_locked = false
	await hud.fade_in(0.2)


func _on_player_died() -> void:
	_transitioning = true
	await get_tree().create_timer(0.4).timeout
	await hud.fade_out(0.6)
	player.heal_full()
	Game.refill_flasks()
	# Wake at the last rest shrine, or back at the start if Storm hasn't rested yet.
	if Game.rest_room != "":
		_load_room(Game.rest_room, "", Game.rest_point)
	else:
		_load_room(START_ROOM, "")
	await get_tree().physics_frame
	camera.reset_smoothing()
	await hud.fade_in(0.6)
	player.controls_locked = false
	_transitioning = false


func _physics_process(_delta: float) -> void:
	# Safety net: if Storm ever leaves the room's bounds (a gap in the walls, a missed
	# door), put him back on the last solid ground instead of letting him fall forever.
	if _transitioning or not room:
		return
	if not Rect2(Vector2.ZERO, room.size_px).grow(OUT_OF_BOUNDS_MARGIN).has_point(player.global_position):
		_recover_out_of_bounds()


func _recover_out_of_bounds() -> void:
	_transitioning = true
	player.controls_locked = true
	await hud.fade_out(0.2)
	player.respawn_at_safe()
	await get_tree().physics_frame
	camera.reset_smoothing()
	await hud.fade_in(0.2)
	player.controls_locked = false
	_transitioning = false
