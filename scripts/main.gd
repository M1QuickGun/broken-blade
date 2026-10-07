extends Node2D
## Opens on the title screen; then owns the player, camera, HUD, pause menu and map, and
## swaps rooms as Storm walks through doors. Progress saves itself along the way.

const Rooms := preload("res://scripts/rooms.gd")
const Room := preload("res://scripts/room.gd")
const Player := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")
const Title := preload("res://scripts/title.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
const MapScreen := preload("res://scripts/map_screen.gd")
const Intro := preload("res://scripts/intro.gd")
const Shop := preload("res://scripts/shop.gd")
const Travel := preload("res://scripts/travel.gd")

const START_ROOM := "landing"
## Debug warps (keys 6-9, -, =, [, ], \ and '): action -> [room, the door to arrive by].
const DEBUG_WARPS := {
	"debug_warp_village": ["village_square", "g"],
	"debug_warp_frost_arena": ["frost_arena", "k"],
	"debug_warp_frost_throne": ["frost_throne", "m"],
	"debug_warp_crossroads": ["crossroads", "p"],
	"debug_warp_forge": ["forge", "t"],
	"debug_warp_roost": ["drake_roost", "w"],
	"debug_warp_spire": ["spire", "t"],
	"debug_warp_eyrie": ["thunder_eyrie", "v"],
	"debug_warp_castle": ["castle_gate", "c"],
	"debug_warp_throne": ["throne_approach", "i"],
}
const DOOR_FADE := 0.15
## The view in world units (see Game.ART_SCALE).
const VIEW_HEIGHT := 270
const VIEW_WIDTH := 480
## How far past the room's edges Storm can go before he's put back on solid ground.
const OUT_OF_BOUNDS_MARGIN := 48.0

var room: Node2D
var player: CharacterBody2D
var camera: Camera2D
var hud: CanvasLayer
var pause_menu: CanvasLayer
var map_screen: CanvasLayer

var _transitioning := false
## The region Storm is in, to name a new one as he steps into it.
var _region := ""
## The boss rush: which fight it's on, and the time so far.
var _rush_index := 0
var _rush_time := 0.0


func _ready() -> void:
	# Hide the cursor while playing and keep clicks inside the window.
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	get_tree().paused = false
	var title := Title.new()
	title.chosen.connect(_on_title_chosen)
	add_child(title)


func _on_title_chosen(choice: String) -> void:
	if choice == "rush":
		Game.start_boss_rush()
		_start_world()
		_rush_index = 0
		_rush_time = 0.0
		_load_room(Game.RUSH[0][0], Game.RUSH[0][1])
		hud.show_message("The boss rush. Every boss, one after another.")
		await hud.fade_in(0.8)
		return
	if choice == "new":
		var hard := Game.hard
		Game.new_game()
		Game.hard = hard
		Game.save_game()
		var intro := Intro.new()
		add_child(intro)
		await intro.finished
		_start_world()
		_load_room(START_ROOM, "")
		hud.show_message("Broken Blade")
	else:
		Game.load_game()
		_start_world()
		if Game.rest_room != "":
			_load_room(Game.rest_room, "", Game.rest_point)
		else:
			_load_room(START_ROOM, "")
	await hud.fade_in(0.8)


## Builds everything that lasts from room to room: Storm, the camera, the HUD and menus.
func _start_world() -> void:
	Game.playing = true
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
	player.hp_changed.connect(_on_hp_changed)
	player.hit_hazard.connect(_on_player_hit_hazard)
	player.died.connect(_on_player_died)

	pause_menu = PauseMenu.new()
	pause_menu.map_requested.connect(func() -> void: map_screen.open())
	pause_menu.quit_to_title.connect(_quit_to_title)
	add_child(pause_menu)
	map_screen = MapScreen.new()
	add_child(map_screen)
	hud.set_black()


func _process(_delta: float) -> void:
	if map_screen and room:
		map_screen.current_room = room.room_name
		map_screen.storm_at = player.position


var _last_hp := -1


## Losing health: a red flash and a jolt of the camera.
func _on_hp_changed(hp: int, _max_hp: int) -> void:
	if _last_hp >= 0 and hp < _last_hp:
		hud.flash_hurt()
		var tween := create_tween()
		for i in 5:
			tween.tween_property(camera, "position", Vector2(randf_range(-3, 3), randf_range(-3, 3)), 0.03)
		tween.tween_property(camera, "position", Vector2.ZERO, 0.03)
	_last_hp = hp


## The end: a moment in the quiet throne room, then the ending's panels, then the title.
## (Continuing afterwards wakes Storm at the shrine in the throne room.)
## On to the next boss of the rush (healed), or the end of it with the time.
func _next_rush_fight() -> void:
	await get_tree().create_timer(2.5).timeout
	_rush_index += 1
	if _rush_index >= Game.RUSH.size():
		var best := Game.rush_best == 0.0 or _rush_time < Game.rush_best
		if best:
			Game.rush_best = _rush_time
			Game.save_settings()
		hud.show_message("The rush is done: %s%s" % [Game.clock(_rush_time), "  (a new best)" if best else ""])
		await get_tree().create_timer(4.0).timeout
		_quit_to_title()
		return
	_transitioning = true
	player.controls_locked = true
	await hud.fade_out(0.4)
	player.heal_full()
	Game.refill_flasks()
	_load_room(Game.RUSH[_rush_index][0], Game.RUSH[_rush_index][1])
	await get_tree().physics_frame
	camera.position = Vector2.ZERO
	camera.reset_smoothing()
	await hud.fade_in(0.4)
	player.controls_locked = false
	_transitioning = false


func _play_ending() -> void:
	player.controls_locked = true
	await get_tree().create_timer(2.5).timeout
	await hud.fade_out(1.5)
	var ending := Intro.new()
	ending.panels = Intro.ENDING
	add_child(ending)
	await ending.finished
	var credits: CanvasLayer = load("res://scripts/credits.gd").new()
	add_child(credits)
	await credits.finished
	_quit_to_title()


func _open_travel() -> void:
	if _transitioning:
		return
	var menu := Travel.new()
	menu.here = room.room_name
	menu.chosen.connect(_travel_to)
	add_child(menu)


## Off to another shrine: a fade, and Storm wakes there as if he'd rested.
func _travel_to(room_name: String, point: Vector2) -> void:
	_transitioning = true
	player.controls_locked = true
	await hud.fade_out(0.5)
	_load_room(room_name, "", point)
	Game.rest_at(room_name, point)
	await get_tree().physics_frame
	camera.position = Vector2.ZERO
	camera.reset_smoothing()
	await hud.fade_in(0.5)
	player.controls_locked = false
	_transitioning = false


func _quit_to_title() -> void:
	Game.save_game()
	Game.playing = false
	Game.boss_rush = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or player == null:
		return
	if event.is_action_pressed("debug_unlock_dash"):
		Game.unlock("dash")
	elif event.is_action_pressed("debug_unlock_shockline"):
		Game.unlock("shockline")
	elif event.is_action_pressed("debug_unlock_double_jump"):
		Game.unlock("double_jump")
	elif event.is_action_pressed("debug_unlock_wall_jump"):
		Game.unlock("wall_jump")
	for action in DEBUG_WARPS:
		if event.is_action_pressed(action) and not _transitioning:
			_debug_warp(DEBUG_WARPS[action][0], DEBUG_WARPS[action][1])
			return
	if event.is_action_pressed("debug_reveal_map"):
		# Mark every room visited, to see the whole map (M) filled in.
		for room_name in Rooms.LAYOUTS:
			Game.visited[room_name] = true
		hud.show_message("Map revealed.")
		return
	if event.is_action_pressed("debug_defeat_boss"):
		# Finish off whatever boss is fighting (for testing what comes after it).
		var boss = get_tree().get_first_node_in_group("boss")
		if boss:
			boss.hp = 1
			boss.take_hit(1, Vector2.RIGHT)


func _debug_warp(room_name: String, door: String) -> void:
	_transitioning = true
	player.controls_locked = true
	await hud.fade_out(DOOR_FADE)
	player.heal_full()
	_load_room(room_name, door)
	await get_tree().physics_frame
	camera.reset_smoothing()
	await hud.fade_in(DOOR_FADE)
	player.controls_locked = false
	_transitioning = false


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
	room.travel_requested.connect(_open_travel)
	room.shop_opened.connect(func(shop: String, title: String) -> void:
		var trading := Shop.new()
		trading.shop = shop
		trading.title = title
		add_child(trading))
	room.boss_defeated.connect(func(title: String) -> void:
		hud.show_message("%s falls." % title)
		Game.save_game()
		if Game.boss_rush:
			_next_rush_fight()
		elif Game.defeated.has("hollow_king") and room.room_name == "throne_room":
			_play_ending())
	Music.play(Rooms.music_for(room_name))
	Music.ambience(room.ambience())
	player.step_sound = room.step_sound()
	var region := Rooms.region_of(room_name)
	if region != _region and room_name not in Rooms.SECRET_ROOMS:
		if _region != "":
			hud.show_area(Rooms.REGION_TITLES[region])
		_region = region
	if not Game.visited.has(room_name):
		Game.visited[room_name] = true
		Game.save_game()

	if at != Vector2.INF:
		player.place_at(at)
	else:
		player.place_at(room.spawn_point if door == "" else room.door_spawn(door))
	camera.limit_left = 0
	camera.limit_top = -int(room.roof_px)
	# A room barely taller than the screen isn't for climbing: the camera holds still
	# vertically, showing its floor, instead of bobbing up after every jump.
	if room.size_px.y <= VIEW_HEIGHT + 3 * Rooms.TILE:
		camera.limit_top = int(room.size_px.y) - VIEW_HEIGHT
	camera.limit_right = int(room.size_px.x)
	camera.limit_bottom = int(room.size_px.y)
	# A room narrower than the screen sits in the middle of it, walled in by rock either side
	# (room.gd draws the rock on past its edges).
	if room.size_px.x < VIEW_WIDTH:
		camera.limit_left = int(room.size_px.x - VIEW_WIDTH) / 2
		camera.limit_right = camera.limit_left + VIEW_WIDTH
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
	# The view slides on in the way he's going as the new room fades in.
	var came_from_left: bool = room.door_spawn(link[1]).x < room.size_px.x / 2.0
	camera.position = Vector2(-40.0 if came_from_left else 40.0, 0.0)
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
	if Game.boss_rush:
		_transitioning = true
		await get_tree().create_timer(1.6, true, false, true).timeout
		hud.show_message("The rush ends.")
		await hud.fade_out(1.0)
		_quit_to_title()
		return
	_transitioning = true
	# What he carried stays where he last stood on solid ground.
	Game.drop_crowns(room.room_name, room.to_local(player.safe_position))
	# Let him fall: the death plays out (in slow motion at first) before the fade.
	await get_tree().create_timer(1.6, true, false, true).timeout
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


## The camera leads Storm a little the way he's going, and holding up or down while he
## stands still lets him peek above or below. In a boss fight it stays centred on him.
const LOOK_AHEAD := 34.0
const PEEK := 72.0
const PEEK_AFTER := 0.4
var _peek_time := 0.0


## A boss fight has its own music; once it's over, the room's comes back.
func _update_music() -> void:
	if room == null or _transitioning:
		return
	var boss = get_tree().get_first_node_in_group("boss")
	if boss:
		var big: bool = boss.get("boss_id") in ["hollow_king", "dark_storm"]
		Music.play("final_boss" if big else "boss")
	else:
		Music.play(Rooms.music_for(room.room_name))


func _update_camera(delta: float) -> void:
	if camera == null or player == null:
		return
	var target := Vector2.ZERO
	var fighting := get_tree().get_first_node_in_group("boss") != null
	if not fighting:
		var moving := absf(player.velocity.x) > 40.0
		target.x = player.facing * (LOOK_AHEAD if moving else LOOK_AHEAD * 0.4)
	var still: bool = player.is_on_floor() and absf(player.velocity.x) < 5.0 and not player.controls_locked
	var peek := 0.0
	if still and Input.is_action_pressed("look_up"):
		peek = -1.0
	elif still and Input.is_action_pressed("look_down"):
		peek = 1.0
	_peek_time = _peek_time + delta if peek != 0.0 else 0.0
	if _peek_time > PEEK_AFTER:
		target.y = peek * PEEK
	camera.position = camera.position.lerp(target, clampf(2.5 * delta, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	_update_camera(delta)
	if Game.boss_rush and not get_tree().paused:
		_rush_time += delta
	_update_music()
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
