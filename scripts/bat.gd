extends CharacterBody2D
## The Ash bat (the Fire slopes): a bat of charred flesh with embers in its wings. It hangs in
## the air above where it roosts, drifting after Storm when he's near. Then it screeches,
## flaring up (the telegraph), and dives at where he stood in one straight line, carrying on
## until it hits the ground or overshoots, and swoops back up. A small lesson in the Ashen
## Drake's dives: step aside, then hit it while it climbs back. The room places it at the
## feet of its roost; it hangs a few tiles above.

const Effects := preload("res://scripts/effects.gd")
const LAYER_WORLD := 1
const LAYER_ENEMY := 4

const TEX := preload("res://art/enemies/ash_bat.png")
const FRAME := 64
const DRAW := 38.0
const FPS := 12.0
## The frame with the wings swept flat, held through the dive.
const DIVE_FRAME := 4
const SIZE := Vector2(18, 12)

## How high above its roost it hangs.
const HOVER_HEIGHT := 56.0
const HOVER_SPEED := 32.0
## How far it strays from its roost following Storm.
const LEASH := 150.0
const NOTICE := Vector2(150, 130)
const SCREECH_TIME := 0.5
const DIVE_SPEED := 240.0
const DIVE_MAX := 1.1
const CLIMB_TIME := 0.9
const COOLDOWN := 1.3
const KNOCKBACK_SPEED := 160.0
const KNOCKBACK_TIME := 0.2
const COLOR_EMBER := Color(1.0, 0.55, 0.18)

enum St { HOVER, SCREECH, DIVE, CLIMB }

var hp := 2
var dir := -1

var _state := St.HOVER
var _timer := 0.0
var _cooldown := 0.5
var _knockback := 0.0
var _flash := 0.0
var _anim := 0.0
var _home := Vector2.ZERO
var _dive_dir := Vector2.ZERO
var _phase := randf() * TAU


func _ready() -> void:
	position.y -= HOVER_HEIGHT
	_home = position
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	add_to_group("shock_target")


## Where the shockline latches on.
func shock_point() -> Vector2:
	return global_position


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_anim += delta
	_flash -= delta
	_timer -= delta
	_cooldown -= delta
	_knockback -= delta
	var player := _player()
	# Aim at his middle, not his feet.
	var to := (player.global_position + Vector2(0, -14)) - global_position if player else Vector2(9999, 0)
	if _knockback > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		if _state == St.DIVE:
			_climb()
	else:
		match _state:
			St.HOVER:
				_hover(to)
			St.SCREECH:
				# Flaring up, wings wide, before the dive.
				velocity = Vector2(0, -26.0)
				if _timer <= 0.0:
					_state = St.DIVE
					_timer = DIVE_MAX
					velocity = _dive_dir * DIVE_SPEED
			St.DIVE:
				velocity = _dive_dir * DIVE_SPEED
				if _timer <= 0.0 or get_slide_collision_count() > 0:
					if get_slide_collision_count() > 0:
						Effects.puff(get_parent(), global_position, Color(0.5, 0.45, 0.42), 6, 40.0)
					_climb()
			St.CLIMB:
				# Swooping back up to hang over its roost again.
				var back := Vector2(clampf(global_position.x, _home.x - LEASH, _home.x + LEASH), _home.y)
				velocity = velocity.lerp((back - global_position).limit_length(1.0) * 90.0, 3.0 * delta)
				if _timer <= 0.0:
					_state = St.HOVER
					_cooldown = COOLDOWN
	move_and_slide()
	queue_redraw()


func _hover(to: Vector2) -> void:
	var near := absf(to.x) < NOTICE.x and absf(to.y) < NOTICE.y
	var bob := sin(_anim * 2.4 + _phase) * 10.0
	var want := Vector2(_home.x + sin(_anim * 0.7 + _phase) * 20.0, _home.y + bob)
	if near:
		# Drifting over toward him, staying up at its own height.
		want.x = clampf(global_position.x + to.x, _home.x - LEASH, _home.x + LEASH)
		dir = 1 if to.x > 0.0 else -1
		if _cooldown <= 0.0 and to.y > -10.0:
			_state = St.SCREECH
			_timer = SCREECH_TIME
			_dive_dir = to.normalized()
			Sfx.play("screech", -6.0)
			return
	var step := want - global_position
	velocity = step.limit_length(1.0) * HOVER_SPEED * clampf(step.length() / 12.0, 0.3, 1.0)
	if absf(velocity.x) > 4.0 and not near:
		dir = 1 if velocity.x > 0.0 else -1


func _climb() -> void:
	_state = St.CLIMB
	_timer = CLIMB_TIME
	velocity = Vector2(velocity.x * 0.4, -60.0)


func take_hit(damage: int, from_dir: Vector2) -> void:
	hp -= damage
	_flash = 0.1
	Sfx.play("hit", -4.0)
	Effects.sparks(get_parent(), global_position, Color(1, 0.8, 0.5))
	if hp <= 0:
		Sfx.play("enemy_die", -4.0)
		Effects.puff(get_parent(), global_position, Color(0.4, 0.36, 0.34))
		Effects.sparks(get_parent(), global_position, COLOR_EMBER, 12, 90.0)
		queue_free()
		return
	if from_dir != Vector2.ZERO:
		velocity = from_dir.normalized() * KNOCKBACK_SPEED
		_knockback = KNOCKBACK_TIME


func _draw() -> void:
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	if _state == St.SCREECH and fmod(_anim, 0.12) < 0.06:
		tint = Color(1.8, 1.2, 0.8)
	var frames := TEX.get_width() / FRAME
	var frame := int(_anim * FPS * (1.6 if _state == St.SCREECH else 1.0)) % frames
	var angle := 0.0
	var flip := 1.0 if dir > 0 else -1.0
	if _state == St.DIVE:
		# Wings swept back and pointed along the dive.
		frame = DIVE_FRAME
		flip = 1.0 if _dive_dir.x >= 0.0 else -1.0
		angle = atan2(_dive_dir.y, absf(_dive_dir.x)) * flip
		# A trail of embers behind it.
		for i in 3:
			var p := -_dive_dir * (8.0 + i * 7.0) + Vector2(randf_range(-2, 2), randf_range(-2, 2))
			draw_circle(p, 1.5 - i * 0.3, Color(COLOR_EMBER, 0.7 - i * 0.2))
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) if _state == St.SCREECH else Vector2.ZERO
	draw_set_transform(shake, angle, Vector2(flip, 1))
	draw_texture_rect_region(TEX, Rect2(-DRAW / 2.0, -DRAW / 2.0, DRAW, DRAW),
		Rect2(frame * FRAME, 0, FRAME, FRAME), tint)
	draw_set_transform(Vector2.ZERO)
