extends CharacterBody2D
## A basic ground enemy: patrols back and forth, turning at walls and ledges.
## The node's origin is at its feet.

const LAYER_WORLD := 1
const LAYER_ENEMY := 4

const SPEED := 35.0
const GRAVITY := 900.0
const MAX_FALL := 400.0
const KNOCKBACK_SPEED := 150.0
const KNOCKBACK_TIME := 0.15
const SIZE := Vector2(16, 12)

const COLOR_SHELL := Color("4a2a2e")
const COLOR_SHELL_EDGE := Color("6e3a3a")
const COLOR_EYES := Color("ff8a3d")

var hp := 3
var dir := -1

var _knockback := 0.0
var _flash := 0.0


func _ready() -> void:
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -SIZE.y / 2)
	add_child(col)
	add_to_group("shock_target")


## Where the shockline latches on.
func shock_point() -> Vector2:
	return global_position + Vector2(0, -SIZE.y / 2)


func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	_flash -= delta
	_knockback -= delta
	if _knockback > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	else:
		if is_on_floor() and (_facing_wall() or not _ground_ahead()):
			dir = -dir
		velocity.x = dir * SPEED
	move_and_slide()
	queue_redraw()


func take_hit(damage: int, from_dir: Vector2) -> void:
	hp -= damage
	_flash = 0.1
	if hp <= 0:
		queue_free()
		return
	if from_dir.x != 0.0:
		velocity.x = from_dir.x * KNOCKBACK_SPEED
		_knockback = KNOCKBACK_TIME


func _facing_wall() -> bool:
	return is_on_wall() and signf(get_wall_normal().x) == -dir


func _ground_ahead() -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position + Vector2(dir * (SIZE.x / 2 + 2), 4)
	q.collision_mask = LAYER_WORLD
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


func _draw() -> void:
	var shell := Color.WHITE if _flash > 0.0 else COLOR_SHELL
	draw_rect(Rect2(-SIZE.x / 2, -SIZE.y, SIZE.x, SIZE.y), shell)
	draw_rect(Rect2(-SIZE.x / 2, -SIZE.y, SIZE.x, 3), COLOR_SHELL_EDGE)
	draw_rect(Rect2(dir * 4 - 1, -8, 2, 2), COLOR_EYES)
	draw_rect(Rect2(dir * 7 - 1, -8, 2, 2), COLOR_EYES)
