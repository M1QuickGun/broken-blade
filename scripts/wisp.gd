extends Node2D
## The Spark wisp (the Lightning peaks): a knot of static around a stone core with one eye.
## It hangs in the air above where it waits, drifting after Storm when he's near. Then it
## charges, a thin line showing where it's aiming (it tracks him, then holds still just
## before), and zaps a beam along that line to the rock. Step out of the line, then hit it.
## The shockline can catch it like a ring. The room places it at the feet of where it waits;
## it hangs a few tiles above.

const Effects := preload("res://scripts/effects.gd")
const LAYER_WORLD := 1
const LAYER_ENEMY := 4

const TEX := preload("res://art/enemies/spark_wisp.png")
const FRAME := 64
const DRAW := 34.0
const FPS := 10.0

const HOVER_HEIGHT := 52.0
const DRIFT_SPEED := 26.0
## How far it strays from where it waits, and how near Storm must be for it to notice him.
const LEASH := 110.0
const NOTICE := Vector2(190, 140)
const CHARGE_TIME := 1.0
## For the last part of the charge it stops tracking him: the moment to step out of line.
const LOCK_TIME := 0.35
const ZAP_TIME := 0.22
const COOLDOWN := 1.6
const BEAM_WIDTH := 8.0
const BEAM_REACH := 420.0
const KNOCKBACK_SPEED := 140.0
const COLOR_SPARK := Color(0.78, 0.66, 1.0)
const COLOR_CORE := Color(0.95, 0.92, 1.0)

enum St { DRIFT, CHARGE, ZAP }

var hp := 2

var _state := St.DRIFT
var _timer := 0.0
var _cooldown := 0.8
var _flash := 0.0
var _anim := randf() * 2.0
var _home := Vector2.ZERO
var _velocity := Vector2.ZERO
var _aim := Vector2.RIGHT
var _beam_end := Vector2.ZERO
var _beam: Beam


## Its beam: hurts to touch, but there's nothing in it to strike.
class Beam extends Area2D:
	var slide_through := true

	func take_hit(_damage: int, _from_dir: Vector2) -> void:
		pass


func _ready() -> void:
	position.y -= HOVER_HEIGHT
	_home = position
	var hurt := Hurt.new()
	hurt.wisp = self
	hurt.collision_layer = LAYER_ENEMY
	hurt.collision_mask = 0
	hurt.monitoring = false
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	var col := CollisionShape2D.new()
	col.shape = shape
	hurt.add_child(col)
	add_child(hurt)
	_beam = Beam.new()
	_beam.collision_layer = 0
	_beam.collision_mask = 0
	_beam.monitoring = false
	_beam.top_level = true
	var beam_shape := RectangleShape2D.new()
	beam_shape.size = Vector2(10, BEAM_WIDTH)
	var beam_col := CollisionShape2D.new()
	beam_col.shape = beam_shape
	_beam.add_child(beam_col)
	add_child(_beam)
	add_to_group("shock_target")


## Its body: struck, it hurts the wisp; touched, it hurts Storm.
class Hurt extends Area2D:
	var wisp: Node

	func take_hit(damage: int, from_dir: Vector2) -> void:
		wisp.take_hit(damage, from_dir)


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
	var to := (player.global_position + Vector2(0, -12)) - global_position if player else Vector2(9999, 0)
	var near := absf(to.x) < NOTICE.x and absf(to.y) < NOTICE.y
	match _state:
		St.DRIFT:
			var want := _home + Vector2(sin(_anim * 0.6) * 16.0, sin(_anim * 1.7) * 6.0)
			if near:
				want.x = clampf(global_position.x + to.x * 0.5, _home.x - LEASH, _home.x + LEASH)
			var step := want - position
			_velocity = _velocity.lerp(step.limit_length(1.0) * DRIFT_SPEED * clampf(step.length() / 10.0, 0.2, 1.0), 4.0 * delta)
			if near and _cooldown <= 0.0:
				_state = St.CHARGE
				_timer = CHARGE_TIME
				_aim = to.normalized()
				Sfx.play("shock_charge", -10.0, 0.05)
		St.CHARGE:
			_velocity = _velocity.lerp(Vector2.ZERO, 6.0 * delta)
			if _timer > LOCK_TIME and to != Vector2.ZERO:
				_aim = _aim.slerp(to.normalized(), 6.0 * delta)
			_beam_end = _cast(_aim)
			if _timer <= 0.0:
				_state = St.ZAP
				_timer = ZAP_TIME
				Sfx.play("zap", -6.0)
				Effects.sparks(get_parent(), _beam_end, COLOR_SPARK, 8, 120.0)
		St.ZAP:
			_velocity = -_aim * 20.0  # a little kick back
			if _timer <= 0.0:
				_state = St.DRIFT
				_cooldown = COOLDOWN
	position += _velocity * delta
	_update_beam()
	queue_redraw()


## Where a beam from it along `dir` stops: the first rock, or its full reach.
func _cast(dir: Vector2) -> Vector2:
	var from := global_position
	var to := from + dir * BEAM_REACH
	var query := PhysicsRayQueryParameters2D.create(from, to, LAYER_WORLD)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.position if hit else to


func _update_beam() -> void:
	var on := _state == St.ZAP
	_beam.collision_layer = LAYER_ENEMY if on else 0
	if on:
		var from := global_position
		var shape: RectangleShape2D = _beam.get_child(0).shape
		shape.size = Vector2(maxf(from.distance_to(_beam_end), 1.0), BEAM_WIDTH)
		_beam.global_position = (from + _beam_end) / 2.0
		_beam.global_rotation = (_beam_end - from).angle()


func take_hit(damage: int, from_dir: Vector2) -> void:
	hp -= damage
	_flash = 0.1
	Sfx.play("hit", -4.0)
	Effects.sparks(get_parent(), position, COLOR_SPARK)
	if hp <= 0:
		Sfx.play("enemy_die", -4.0)
		Sfx.play("crackle", -6.0)
		Effects.sparks(get_parent(), position, COLOR_CORE, 14, 110.0)
		queue_free()
		return
	# Knocked away, and its charge broken.
	if from_dir != Vector2.ZERO:
		_velocity = from_dir.normalized() * KNOCKBACK_SPEED
	if _state == St.CHARGE:
		_state = St.DRIFT
		_cooldown = COOLDOWN * 0.6


func _draw() -> void:
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	var frames := TEX.get_width() / FRAME
	var speed := FPS * (2.0 if _state == St.CHARGE else 1.0)
	var frame := int(_anim * speed) % frames
	if _state == St.CHARGE:
		# The line it's aiming along, brightening as it charges; it pulses once it's locked.
		var grow := clampf(1.0 - _timer / CHARGE_TIME, 0.0, 1.0)
		var locked := _timer <= LOCK_TIME
		var alpha := 0.15 + 0.35 * grow
		if locked and fmod(_anim, 0.1) < 0.05:
			alpha = 0.8
		draw_line(Vector2.ZERO, _beam_end - global_position, Color(COLOR_SPARK, alpha), 1.0)
		draw_circle(Vector2.ZERO, 6.0 + 8.0 * grow, Color(COLOR_SPARK, 0.15 + 0.25 * grow))
		tint = tint * Color(1.0 + grow, 1.0 + grow * 0.8, 1.0 + grow)
	if _state == St.ZAP:
		var end := _beam_end - global_position
		var pts := PackedVector2Array()
		var steps := maxi(2, int(end.length() / 10.0))
		for i in steps + 1:
			var t := float(i) / steps
			var side := Vector2(-end.y, end.x).normalized() * (randf_range(-3, 3) if i > 0 and i < steps else 0.0)
			pts.append(end * t + side)
		draw_polyline(pts, Color(COLOR_SPARK, 0.5), BEAM_WIDTH)
		draw_polyline(pts, COLOR_CORE, 2.0)
	var bob := Vector2(0, sin(_anim * 3.0) * 1.5)
	draw_texture_rect_region(TEX, Rect2(bob - Vector2(DRAW, DRAW) / 2.0, Vector2(DRAW, DRAW)),
		Rect2(frame * FRAME, 0, FRAME, FRAME), tint)
