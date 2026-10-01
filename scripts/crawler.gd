extends CharacterBody2D
## The ground enemies. All of them walk the floor, turning at walls and ledges, and hurt to
## touch; each kind has its own trick:
## - "beetle" (the Foothills): a mossy beetle as big as Storm. It patrols, and when it spots
##   him ahead it braces, then charges; running into a wall stuns it.
## - "thrall" (the Frozen village): a villager the cold turned into a frozen husk. It shambles
##   after Storm when he's near and lunges when he's close.
## - "hatchling": the Guardian Centipede's young, dropped into its fight. Just crawls.
## - "grub" (the Foothills): a centipede larva that hides in the earth. When Storm comes near
##   the ground rumbles; it bursts out at him, crawls about for a while, then burrows again.
## The node's origin is at its feet.

const LAYER_WORLD := 1
const LAYER_ENEMY := 4

const GRAVITY := 900.0
const MAX_FALL := 400.0
const KNOCKBACK_SPEED := 150.0
const KNOCKBACK_TIME := 0.15
const COLOR_DIRT := Color("3b352b")

## Per kind: body size (world units), drawn size, health, walking speed, sheet, frame size
## (art pixels) and animation speed. Sheets are horizontal strips facing right. "sink" sets
## art with thin legs a little into the ground so it doesn't look like it's hovering.
const KINDS := {
	"beetle": {"size": Vector2(28, 22), "draw": 36.0, "hp": 4, "speed": 28.0,
		"tex": preload("res://art/enemies/beetle.png"), "frame": 64, "fps": 7.0},
	"thrall": {"size": Vector2(14, 28), "draw": 36.0, "hp": 3, "speed": 18.0,
		"tex": preload("res://art/enemies/thrall.png"), "frame": 64, "fps": 6.0},
	"hatchling": {"size": Vector2(32, 24), "draw": 32.0, "hp": 3, "speed": 35.0, "sink": 4.0,
		"tex": preload("res://art/enemies/hatchling.png"), "frame": 32, "fps": 9.0},
	"grub": {"size": Vector2(28, 20), "draw": 28.0, "hp": 2, "speed": 45.0, "sink": 4.0,
		"tex": preload("res://art/enemies/hatchling.png"), "frame": 32, "fps": 12.0},
}

enum St { WALK, WINDUP, CHARGE, STUN, BURIED, RUMBLE, LEAP, DIG }

var kind := "beetle"
## How far it may walk (set by the room): it turns back before reaching a door.
var min_x := -INF
var max_x := INF
var hp := 3
var dir := -1

var _state := St.WALK
var _timer := 0.0
var _knockback := 0.0
var _flash := 0.0
var _anim := 0.0
var _info: Dictionary
var _cooldown := 0.0


func _ready() -> void:
	_info = KINDS[kind]
	hp = _info.hp
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD
	var shape := RectangleShape2D.new()
	shape.size = _info.size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -_info.size.y / 2)
	add_child(col)
	if kind == "grub":
		_bury()
	else:
		add_to_group("shock_target")


## Where the shockline latches on.
func shock_point() -> Vector2:
	return global_position + Vector2(0, -_info.size.y / 2)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_flash -= delta
	_anim += delta
	_knockback -= delta
	_timer -= delta
	_cooldown -= delta
	if _state != St.BURIED and _state != St.RUMBLE:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	var player := _player()
	var to := player.global_position - global_position if player else Vector2(9999, 0)
	if _knockback > 0.0 and _state != St.CHARGE:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	else:
		match kind:
			"beetle":
				_beetle(to)
			"thrall":
				_thrall(to)
			"grub":
				_grub(to)
			_:
				_patrol(_info.speed)
	move_and_slide()
	queue_redraw()


func _patrol(speed: float) -> void:
	if is_on_floor() and (_facing_wall() or not _ground_ahead() or _at_limit()):
		dir = -dir
	velocity.x = dir * speed


## Patrols; spotting Storm ahead, it braces, then charges until it hits something.
func _beetle(to: Vector2) -> void:
	match _state:
		St.WALK:
			_patrol(_info.speed)
			if _cooldown <= 0.0 and absf(to.x) < 110.0 and absf(to.y) < 24.0 and signf(to.x) == dir:
				_state = St.WINDUP
				_timer = 0.55
		St.WINDUP:
			velocity.x = -dir * 8.0  # rearing back
			if _timer <= 0.0:
				_state = St.CHARGE
				_timer = 1.0
		St.CHARGE:
			velocity.x = dir * 165.0
			if _facing_wall() or (is_on_floor() and not _ground_ahead()) or _at_limit() or _timer <= 0.0:
				_state = St.STUN
				_timer = 0.8 if _facing_wall() else 0.4
				velocity.x = 0.0
		St.STUN:
			velocity.x = 0.0
			if _timer <= 0.0:
				_state = St.WALK
				_cooldown = 1.0


## Shambles after Storm when he's near; lunges when he's close.
func _thrall(to: Vector2) -> void:
	var near := absf(to.x) < 130.0 and absf(to.y) < 40.0
	match _state:
		St.WALK:
			if near:
				dir = 1 if to.x > 0.0 else -1
				var blocked := is_on_floor() and (_facing_wall() or not _ground_ahead() or _at_limit())
				velocity.x = 0.0 if blocked else dir * 40.0
				if _cooldown <= 0.0 and absf(to.x) < 34.0:
					_state = St.WINDUP
					_timer = 0.35
			else:
				_patrol(_info.speed)
		St.WINDUP:
			velocity.x = 0.0
			if _timer <= 0.0:
				_state = St.CHARGE
				velocity = Vector2(dir * 120.0, -120.0)
				_timer = 0.4
		St.CHARGE:
			if _timer <= 0.0 and is_on_floor():
				_state = St.WALK
				_cooldown = 1.2


## Waits buried; rumbles when Storm comes near, bursts out at him, crawls, burrows again.
func _grub(to: Vector2) -> void:
	match _state:
		St.BURIED:
			velocity = Vector2.ZERO
			if _cooldown <= 0.0 and absf(to.x) < 80.0 and absf(to.y) < 40.0:
				_state = St.RUMBLE
				_timer = 0.7
		St.RUMBLE:
			velocity = Vector2.ZERO
			if fmod(_anim, 0.08) < get_physics_process_delta_time():
				_spray()
			if _timer <= 0.0:
				dir = 1 if to.x > 0.0 else -1
				collision_layer = LAYER_ENEMY
				add_to_group("shock_target")
				for i in 3:
					_spray()
				velocity = Vector2(dir * 90.0, -260.0)
				_state = St.LEAP
		St.LEAP:
			if is_on_floor() and velocity.y >= 0.0:
				_state = St.WALK
				_timer = 2.5
		St.WALK:
			_patrol(_info.speed)
			if _timer <= 0.0 and is_on_floor():
				_state = St.DIG
				_timer = 0.5
				velocity.x = 0.0
		St.DIG:
			velocity.x = 0.0
			if fmod(_anim, 0.1) < get_physics_process_delta_time():
				_spray()
			if _timer <= 0.0:
				_bury()


func _bury() -> void:
	_state = St.BURIED
	collision_layer = 0
	remove_from_group("shock_target")
	_cooldown = 1.5


func _spray() -> void:
	var room := get_parent()
	if room and room.has_method("_spawn_debris"):
		room._spawn_debris(global_position + Vector2(randf_range(-8, 8), -2), COLOR_DIRT)


func take_hit(damage: int, from_dir: Vector2) -> void:
	if _state == St.BURIED or _state == St.RUMBLE:
		return
	hp -= damage
	_flash = 0.1
	if hp <= 0:
		queue_free()
		return
	if from_dir.x != 0.0 and _state != St.CHARGE:
		velocity.x = from_dir.x * KNOCKBACK_SPEED
		_knockback = KNOCKBACK_TIME


func _at_limit() -> bool:
	return (dir < 0 and global_position.x <= min_x) or (dir > 0 and global_position.x >= max_x)


func _facing_wall() -> bool:
	return is_on_wall() and signf(get_wall_normal().x) == -dir


func _ground_ahead() -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position + Vector2(dir * (_info.size.x / 2 + 2), 4)
	q.collision_mask = LAYER_WORLD
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


func _draw() -> void:
	if _state == St.BURIED:
		return
	if _state == St.RUMBLE or _state == St.DIG:
		# A swelling mound of earth where it's about to come out (or going back in).
		var grow := clampf(1.0 - _timer / 0.7, 0.2, 1.0) if _state == St.RUMBLE else clampf(_timer / 0.5, 0.0, 1.0)
		var pts := PackedVector2Array()
		for i in 9:
			var a := PI * i / 8.0
			pts.append(Vector2(-cos(a) * (6.0 + 8.0 * grow) + randf_range(-0.5, 0.5), -sin(a) * (2.0 + 4.0 * grow)))
		draw_colored_polygon(pts, COLOR_DIRT)
		if _state == St.RUMBLE:
			return
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	if _state == St.WINDUP and fmod(_anim, 0.16) < 0.08:
		tint = Color(1.5, 1.1, 0.9)
	var tex: Texture2D = _info.tex
	var frame_px: int = _info.frame
	var frames := tex.get_width() / frame_px
	var fps: float = _info.fps * (2.0 if _state == St.CHARGE else 0.0 if _state == St.STUN else 1.0)
	var frame := int(_anim * fps) % frames
	var side: float = _info.draw
	var shake := Vector2(randf_range(-1, 1), 0) if _state == St.WINDUP else Vector2.ZERO
	shake.y += _info.get("sink", 0.0)
	draw_set_transform(shake, 0.0, Vector2(1 if dir > 0 else -1, 1))
	draw_texture_rect_region(tex, Rect2(-side / 2.0, -side, side, side),
		Rect2(frame * frame_px, 0, frame_px, frame_px), tint)
	draw_set_transform(Vector2.ZERO)
