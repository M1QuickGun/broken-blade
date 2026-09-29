extends Area2D
## A piece of the broken blade. Touching it grants that piece's ability.

const COLORS := {
	"dash": Color("bfe9ff"),
	"double_jump": Color("ffb36b"),
	"shockline": Color("f3e98a"),
}

var ability := "dash"

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
	Game.unlock(ability)
	queue_free()


func _draw() -> void:
	var core: Color = COLORS[ability]
	var bob := Vector2(0, sin(_time * 2.5) * 2.0)
	draw_circle(bob, 9.0 + sin(_time * 4.0), Color(core, 0.25))
	draw_colored_polygon(PackedVector2Array([
		bob + Vector2(0, -7), bob + Vector2(3, 0), bob + Vector2(0, 7), bob + Vector2(-3, 0),
	]), core)
