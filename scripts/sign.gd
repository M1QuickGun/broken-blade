extends Area2D
## A weathered signpost. Walking past it shows its text. The node's origin is at its base.

signal read(text: String)

const COLOR_WOOD := Color("5b4636")
const COLOR_WOOD_LIGHT := Color("7a6049")

var text := ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 24)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -12)
	add_child(col)
	body_entered.connect(func(_body: Node2D) -> void: read.emit(text))


func _draw() -> void:
	draw_rect(Rect2(-1, -14, 2, 14), COLOR_WOOD)
	draw_rect(Rect2(-7, -15, 14, 7), COLOR_WOOD)
	draw_rect(Rect2(-6, -14, 12, 1), COLOR_WOOD_LIGHT)
	draw_rect(Rect2(-5, -12, 10, 1), COLOR_WOOD_LIGHT)
