extends Area2D
## A blade shard pickup. Placeholder for the real pieces that bosses will guard.

const COLOR_CORE := Color("cfeeff")
const COLOR_GLOW := Color(0.55, 0.8, 1.0, 0.25)

var pickup_id := ""

var _time := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _on_body_entered(_body: Node2D) -> void:
	Game.collected[pickup_id] = true
	Game.add_piece()
	queue_free()


func _draw() -> void:
	var bob := Vector2(0, sin(_time * 2.5) * 2.0)
	draw_circle(bob, 9.0 + sin(_time * 4.0), COLOR_GLOW)
	draw_colored_polygon(PackedVector2Array([
		bob + Vector2(0, -7), bob + Vector2(3, 0), bob + Vector2(0, 7), bob + Vector2(-3, 0),
	]), COLOR_CORE)
