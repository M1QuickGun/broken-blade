extends Area2D
## A mask shard of the old royal guard: picking it up adds one mask of health for good.

const COLOR_MASK := Color("e6e9f0")
const COLOR_GLOW := Color("ff9ad5")

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
	Sfx.play("mask", 0.0, 0.0)
	Game.add_mask(id)
	queue_free()


func _draw() -> void:
	# The same shield shape as the masks in the health bar, bobbing in a soft glow.
	var o := Vector2(-5, -7 + sin(_time * 2.5) * 2.0)
	draw_circle(o + Vector2(5, 6), 9.0 + sin(_time * 4.0), Color(COLOR_GLOW, 0.22))
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(0, 0), o + Vector2(10, 0), o + Vector2(10, 8), o + Vector2(5, 13), o + Vector2(0, 8),
	]), COLOR_MASK)
