extends Node2D
## The Shade (the castle): a scrap of the evil, a hunched wraith of smoke with clawed arms.
## It hangs where it waits, drifting after Storm through rock and all. Then it fades out of
## sight, and a moment later wells up again just behind him (its eyes show first) and
## lunges at where he stood. After the lunge it hangs there spent: hit it then. Fading, it
## can't be struck. The room places it at the feet of where it waits; it hangs a few tiles
## above.

const Effects := preload("res://scripts/effects.gd")
const LAYER_ENEMY := 4

const TEX := preload("res://art/enemies/shade.png")
const FRAME := 64
const DRAW := 40.0
const FPS := 8.0

const HOVER_HEIGHT := 40.0
const DRIFT_SPEED := 22.0
const LEASH := 140.0
const NOTICE := Vector2(180, 120)
const FADE_TIME := 0.45
## How long it takes to well up behind him: its eyes show first, the warning.
const RISE_TIME := 0.6
const LUNGE_SPEED := 250.0
const LUNGE_TIME := 0.45
const SPENT_TIME := 0.9
const COOLDOWN := 1.4
## How far behind Storm it comes back.
const BEHIND := 54.0
const KNOCKBACK_SPEED := 120.0
const COLOR_SHADOW := Color(0.12, 0.09, 0.16)
const COLOR_EYE := Color(0.82, 0.72, 1.0)

enum St { DRIFT, FADE, RISE, LUNGE, SPENT }

var hp := 3

var _state := St.DRIFT
var _timer := 0.0
var _cooldown := 1.0
var _flash := 0.0
var _anim := randf() * 2.0
var _home := Vector2.ZERO
var _velocity := Vector2.ZERO
var _facing := -1
var _alpha := 1.0
var _hurt: Hurt


## Its body: struck, it hurts the shade; touched, it hurts Storm.
class Hurt extends Area2D:
	var shade: Node

	func take_hit(damage: int, from_dir: Vector2) -> void:
		shade.take_hit(damage, from_dir)


func _ready() -> void:
	position.y -= HOVER_HEIGHT
	_home = position
	_hurt = Hurt.new()
	_hurt.shade = self
	_hurt.collision_layer = LAYER_ENEMY
	_hurt.collision_mask = 0
	_hurt.monitoring = false
	var shape := CircleShape2D.new()
	shape.radius = 9.0
	var col := CollisionShape2D.new()
	col.shape = shape
	_hurt.add_child(col)
	add_child(_hurt)
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
	var player := _player()
	var target := player.global_position + Vector2(0, -14) if player else global_position + Vector2(9999, 0)
	var to := target - global_position
	var near := absf(to.x) < NOTICE.x and absf(to.y) < NOTICE.y
	match _state:
		St.DRIFT:
			_alpha = move_toward(_alpha, 1.0, 3.0 * delta)
			var want := _home + Vector2(sin(_anim * 0.5) * 14.0, sin(_anim * 1.3) * 5.0)
			if near:
				want = global_position + to * 0.5
				want.x = clampf(want.x, _home.x - LEASH, _home.x + LEASH)
				_facing = 1 if to.x > 0.0 else -1
			var step := want - position
			_velocity = _velocity.lerp(step.limit_length(1.0) * DRIFT_SPEED, 3.0 * delta)
			if near and _cooldown <= 0.0:
				_state = St.FADE
				_timer = FADE_TIME
				Sfx.play("swing", -14.0, 0.3)
		St.FADE:
			_velocity = _velocity.lerp(Vector2.ZERO, 6.0 * delta)
			_alpha = clampf(_timer / FADE_TIME, 0.0, 1.0)
			if _timer <= 0.0:
				# Back up behind him, wherever he's facing away from.
				var behind := -1.0
				if player:
					var face = player.get("facing")
					behind = -float(face) if face is int else -signf(to.x)
				position = target + Vector2(behind * BEHIND, -6.0) - (get_parent() as Node2D).global_position
				_facing = 1 if behind < 0.0 else -1
				_state = St.RISE
				_timer = RISE_TIME
		St.RISE:
			_velocity = Vector2.ZERO
			_alpha = clampf(1.0 - _timer / RISE_TIME, 0.0, 1.0)
			if _timer <= 0.0:
				_state = St.LUNGE
				_timer = LUNGE_TIME
				_velocity = to.normalized() * LUNGE_SPEED
				_facing = 1 if to.x > 0.0 else -1
				Sfx.play("screech", -8.0, 0.2)
		St.LUNGE:
			_alpha = 1.0
			if _timer <= 0.0:
				_state = St.SPENT
				_timer = SPENT_TIME
		St.SPENT:
			_velocity = _velocity.lerp(Vector2.ZERO, 5.0 * delta)
			if _timer <= 0.0:
				_state = St.DRIFT
				_cooldown = COOLDOWN
				_home = position.lerp(_home, 0.5)
	position += _velocity * delta
	# Out of sight it can't be struck, and doesn't hurt.
	_hurt.collision_layer = LAYER_ENEMY if _alpha > 0.5 else 0
	queue_redraw()


func take_hit(damage: int, from_dir: Vector2) -> void:
	if _alpha <= 0.5:
		return
	hp -= damage
	_flash = 0.1
	Sfx.play("hit", -4.0)
	Effects.sparks(get_parent(), position, COLOR_EYE)
	if hp <= 0:
		Sfx.play("enemy_die", -4.0)
		Effects.puff(get_parent(), position, COLOR_SHADOW)
		Effects.sparks(get_parent(), position, COLOR_EYE, 10, 80.0)
		queue_free()
		return
	if from_dir != Vector2.ZERO:
		_velocity = from_dir.normalized() * KNOCKBACK_SPEED
	if _state == St.LUNGE:
		_state = St.SPENT
		_timer = SPENT_TIME


func _draw() -> void:
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	var frames := TEX.get_width() / FRAME
	var frame := int(_anim * FPS * (2.0 if _state == St.LUNGE else 1.0)) % frames
	var bob := Vector2(0, sin(_anim * 2.4) * 2.0)
	if _state == St.RISE:
		# Its eyes open in the dark first: the warning.
		var eye := Vector2(_facing * 6.0, -8.0)
		draw_circle(eye, 2.5, Color(COLOR_EYE, 0.9))
		draw_circle(eye, 6.0, Color(COLOR_EYE, 0.2))
	if _state == St.LUNGE:
		# A smear of smoke behind it.
		for i in 3:
			draw_circle(-_velocity.normalized() * (8.0 + i * 8.0), 7.0 - i * 2.0, Color(COLOR_SHADOW, 0.4 - i * 0.12))
	draw_set_transform(bob, 0.0, Vector2(_facing, 1))
	draw_texture_rect_region(TEX, Rect2(-Vector2(DRAW, DRAW) / 2.0, Vector2(DRAW, DRAW)),
		Rect2(frame * FRAME, 0, FRAME, FRAME), Color(tint, tint.a * _alpha))
	draw_set_transform(Vector2.ZERO)
