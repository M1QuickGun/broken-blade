extends Area2D
## An empty flask, left behind in some hidden corner: picking it up gives Storm one more
## flask to carry, for good (filled at once, as at a shrine).

const COLOR_GLASS := Color("5a6275")
const COLOR_FLAME := Color("9fe6ff")
const COLOR_CORK := Color("7a6049")

## Unique per pickup so it stays taken (set by the room: "<room>:<x>,<y>").
var id := ""

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
	Sfx.play("flask", 0.0, 0.0)
	Game.add_flask(id)
	queue_free()


func _draw() -> void:
	var o := Vector2(0, sin(_time * 2.5) * 2.0)
	draw_circle(o, 9.0 + sin(_time * 4.0), Color(COLOR_FLAME, 0.18))
	draw_circle(o + Vector2(0, 2), 4.5, COLOR_GLASS)
	draw_circle(o + Vector2(0, 2.5), 3.0, Color(COLOR_FLAME, 0.7 + 0.3 * sin(_time * 3.0)))
	draw_rect(Rect2(o + Vector2(-1.5, -5), Vector2(3, 4)), COLOR_GLASS)
	draw_rect(Rect2(o + Vector2(-1.5, -7), Vector2(3, 2)), COLOR_CORK)
