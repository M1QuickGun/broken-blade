extends Area2D
## The crowns Storm was carrying when he fell, left where he last stood on solid ground: a
## purse glowing faintly, smoke curling off it. Touching it takes them back. Fall again
## before reaching it and they're gone for good. The node's origin is at its base.

const COLOR_PURSE := Color("5a4230")
const COLOR_TIE := Color("a88a50")
const COLOR_GLOW := Color(0.95, 0.78, 0.36)

var _time := 0.0
var _taken := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 18)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -9)
	add_child(col)
	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node2D) -> void:
	if _taken:
		return
	_taken = true
	Sfx.play("pickup", -6.0, 0.0)
	Game.recover_crowns()
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.7 + 0.3 * sin(_time * 3.0)
	draw_circle(Vector2(0, -7), 12.0, Color(COLOR_GLOW, 0.12 * pulse))
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		pts.append(Vector2(-cos(a) * 6.0, -sin(a) * 8.0))
	draw_colored_polygon(pts, COLOR_PURSE)
	draw_rect(Rect2(-2.5, -11, 5, 3), COLOR_PURSE)
	draw_rect(Rect2(-3, -9, 6, 1), COLOR_TIE)
	draw_rect(Rect2(-1, -6, 2, 2), Color(COLOR_GLOW, pulse))
	for i in 3:
		var rise := fmod(_time * 0.5 + i * 0.33, 1.0)
		draw_circle(Vector2(sin(_time + i * 2.0) * 3.0, -12.0 - rise * 14.0), 1.5 + rise * 2.0, Color(0.3, 0.28, 0.32, 0.4 * (1.0 - rise)))
