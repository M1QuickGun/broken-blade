extends Node2D
## Owns the player, camera and HUD, and swaps rooms as Storm walks through doors.

const Rooms := preload("res://scripts/rooms.gd")
const Room := preload("res://scripts/room.gd")
const Player := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")

const START_ROOM := "ruins_entry"
const DOOR_FADE := 0.15

var room: Node2D
var player: CharacterBody2D
var camera: Camera2D
var hud: CanvasLayer

var _transitioning := false


func _ready() -> void:
	player = Player.new()
	add_child(player)

	camera = Camera2D.new()
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
	if OS.is_debug_build() and event.is_action_pressed("debug_add_piece"):
		Game.add_piece()


func _load_room(room_name: String, door: String) -> void:
	if room:
		remove_child(room)
		room.queue_free()
	room = Room.new()
	room.build(room_name)
	add_child(room)
	move_child(room, 0)
	room.door_entered.connect(_on_door_entered)

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
	player.controls_locked = false
	await hud.fade_in(DOOR_FADE)
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
	_load_room(START_ROOM, "")
	await get_tree().physics_frame
	camera.reset_smoothing()
	player.controls_locked = false
	await hud.fade_in(0.6)
	_transitioning = false
