extends Area2D
## A piece of the broken blade (or, for the wall jump, a technique for the hilt).
## Touching it grants that ability.

const COLORS := {
	"dash": Color("bfe9ff"),
	"double_jump": Color("ffb36b"),
	"shockline": Color("f3e98a"),
	"wall_jump": Color("d8b25a"),  # the hilt's gold
}

var ability := "dash"
## The wall jump comes with the hilt itself, so that pickup shows the hilt.
const HILT := preload("res://art/blade/blade_0_hilt.png")
const HILT_ART := Rect2(0, 58, 32, 38)

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
	Sfx.play("pickup", 0.0, 0.0)
	Game.unlock(ability)
	queue_free()


func _draw() -> void:
	var core: Color = COLORS[ability]
	var bob := Vector2(0, sin(_time * 2.5) * 2.0)
	draw_circle(bob, 9.0 + sin(_time * 4.0), Color(core, 0.25))
	if ability == "wall_jump":
		# Just the hilt from the 32x96 icon (its bottom third), at the size it flies in at
		# when the centipede drops it.
		draw_texture_rect_region(HILT, Rect2(bob + HILT_ART.size * -0.2, HILT_ART.size * 0.4), HILT_ART)
		return
	draw_colored_polygon(PackedVector2Array([
		bob + Vector2(0, -7), bob + Vector2(3, 0), bob + Vector2(0, 7), bob + Vector2(-3, 0),
	]), core)
