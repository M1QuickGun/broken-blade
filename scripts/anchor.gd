extends Node2D
## A grapple point the lightning shockline can latch onto.

const COLOR_RING := Color("8f86d9")
const COLOR_CORE := Color("f3e98a")

var _time := 0.0


func _ready() -> void:
	add_to_group("shock_target")


func shock_point() -> Vector2:
	return global_position


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 16, COLOR_RING, 2.0)
	draw_circle(Vector2.ZERO, 1.5 + 0.5 * sin(_time * 5.0), COLOR_CORE)
