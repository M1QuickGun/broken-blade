extends Area2D
## One of the survivors at the refuge. Walking up to them, they say something (a new line
## each time, round and round); they turn to face Storm when he's near. The node's origin is
## at their feet.

signal read(text: String)

const FRAME := 64
const DRAW := 40.0
const FPS := 4.0

## Set by the room (see Rooms.NPCS): who they are, their idle animation strip (facing right),
## and what they have to say.
var title := ""
var art: Texture2D
var lines: Array = []

var _line := 0
var _time := randf() * 3.0
var _facing := 1


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 28)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -14)
	add_child(col)
	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node2D) -> void:
	if lines.is_empty():
		return
	read.emit("%s: %s" % [title, lines[_line]])
	_line = (_line + 1) % lines.size()


func _process(delta: float) -> void:
	_time += delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and absf(player.global_position.x - global_position.x) < 120.0:
		# Turned to face him (the art faces right).
		_facing = 1 if player.global_position.x > global_position.x else -1
	queue_redraw()


func _draw() -> void:
	if art == null:
		return
	var frames := maxi(1, art.get_width() / FRAME)
	var frame := int(_time * FPS) % frames
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing, 1))
	draw_texture_rect_region(art, Rect2(-DRAW / 2.0, -DRAW, DRAW, DRAW), Rect2(frame * FRAME, 0, FRAME, FRAME))
	draw_set_transform(Vector2.ZERO)
