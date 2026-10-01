extends Node2D
## Short-lived hit effects: a spray of sparks where a blow lands, a puff when an enemy dies.
## Spawn them with the static helpers; each frees itself when done. Also the slow-motion
## moment for a boss's killing blow.

## Sparks: quick bright streaks flying out from a point.
static func sparks(parent: Node, at: Vector2, color: Color, count := 8, speed := 140.0) -> void:
	_spawn(parent, at, color, count, speed, 0.22, true)


## A puff: slower, rounder bits drifting out and fading (an enemy coming apart).
static func puff(parent: Node, at: Vector2, color: Color, count := 12, speed := 70.0) -> void:
	_spawn(parent, at, color, count, speed, 0.5, false)


static func _spawn(parent: Node, at: Vector2, color: Color, count: int, speed: float, life: float,
		streaks: bool) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var burst: Node2D = load("res://scripts/effects.gd").new()
	burst.position = at
	burst.z_index = 2
	burst._setup(color, count, speed, life, streaks)
	parent.add_child(burst)


## The killing blow on a boss: everything slows for a moment.
static func slow_motion(tree: SceneTree, scale := 0.25, seconds := 0.7) -> void:
	Engine.time_scale = scale
	await tree.create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


var _color := Color.WHITE
var _bits: Array[Dictionary] = []
var _life := 0.3
var _age := 0.0
var _streaks := true


func _setup(color: Color, count: int, speed: float, life: float, streaks: bool) -> void:
	_color = color
	_life = life
	_streaks = streaks
	for i in count:
		var dir := Vector2.from_angle(randf() * TAU)
		_bits.append({"pos": Vector2.ZERO, "vel": dir * speed * randf_range(0.5, 1.2),
			"size": randf_range(1.0, 2.5)})


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	for bit in _bits:
		bit.pos += bit.vel * delta
		bit.vel *= 1.0 - 6.0 * delta
		if not _streaks:
			bit.vel.y -= 30.0 * delta
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _age / _life
	for bit in _bits:
		if _streaks:
			draw_line(bit.pos, bit.pos - bit.vel * 0.04, Color(_color, fade), 1.0)
		else:
			draw_circle(bit.pos, bit.size * (0.5 + fade), Color(_color, fade * 0.8))
