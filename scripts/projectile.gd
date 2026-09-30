extends Area2D
## A boss's thrown hazard: an icicle falling from the ceiling, or a shockwave running along
## the floor. It hurts Storm like an enemy does, and he can smash it with the blade.

const LAYER_WORLD := 1
const LAYER_ENEMY := 4

const COLOR_ICE := Color("bfe9ff")
const COLOR_ICE_DARK := Color("5d8fb8")
const COLOR_DUST := Color("8a7a66")
const COLOR_CLOD := Color("3b352b")
const COLOR_CLOD_LIGHT := Color("5e5443")

## "icicle" or "clod" (falls or is thrown, breaks on the ground), "frost_wave" or "dust_wave"
## (runs along the floor).
var kind := "icicle"
var velocity := Vector2.ZERO
var fall_accel := 0.0
var life := 2.0

var _size := Vector2(6, 12)


func _ready() -> void:
	collision_layer = LAYER_ENEMY
	var falls := kind == "icicle" or kind == "clod"
	collision_mask = LAYER_WORLD if falls else 0
	monitoring = falls
	if kind == "clod":
		_size = Vector2(8, 8)
	elif not falls:
		_size = Vector2(12, 10)
	var shape := RectangleShape2D.new()
	shape.size = _size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2.ZERO if falls else Vector2(0, -_size.y / 2)
	add_child(col)
	body_entered.connect(func(_body: Node2D) -> void: queue_free())


func _physics_process(delta: float) -> void:
	velocity.y += fall_accel * delta
	position += velocity * delta
	life -= delta
	if life <= 0.0 or (kind.ends_with("wave") and _wall_ahead()):
		queue_free()
	queue_redraw()


## The blade breaks it.
func take_hit(_damage: int, _from_dir: Vector2) -> void:
	queue_free()


func _wall_ahead() -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position + Vector2(signf(velocity.x) * (_size.x / 2 + 1), -4)
	q.collision_mask = LAYER_WORLD
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


func _draw() -> void:
	match kind:
		"icicle":
			draw_colored_polygon(PackedVector2Array([Vector2(-3, -6), Vector2(3, -6), Vector2(0, 6)]), COLOR_ICE)
			draw_line(Vector2(-1, -5), Vector2(0, 3), COLOR_ICE_DARK, 1.0)
		"clod":
			draw_circle(Vector2.ZERO, 4.0, COLOR_CLOD)
			draw_circle(Vector2(-1, -1.5), 2.0, COLOR_CLOD_LIGHT)
			draw_rect(Rect2(2, -3, 2, 2), COLOR_CLOD_LIGHT)
		"frost_wave":
			var fade := clampf(life * 2.0, 0.0, 1.0)
			for i in 3:
				var x := -5.0 + i * 5.0
				var h := 6.0 + 3.0 * ((i + int(life * 20.0)) % 2)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - 2.5, 0), Vector2(x, -h), Vector2(x + 2.5, 0),
				]), Color(COLOR_ICE, fade))
		"dust_wave":
			var fade := clampf(life * 2.0, 0.0, 1.0)
			draw_circle(Vector2(0, -3), 5.0, Color(COLOR_DUST, 0.7 * fade))
			draw_circle(Vector2(-4, -2), 3.5, Color(COLOR_DUST, 0.5 * fade))
			draw_circle(Vector2(4, -2), 3.5, Color(COLOR_DUST, 0.5 * fade))
