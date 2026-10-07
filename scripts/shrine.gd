extends Area2D
## A rest shrine: a small stone altar with a pale flame. Touching it mends Storm's wounds
## and makes it the place he wakes after falling. The node's origin is at its base.

const COLOR_STONE := Color("3d4354")
const COLOR_STONE_TOP := Color("5a6275")
const COLOR_FLAME := Color("9fe6ff")
const COLOR_FLAME_CORE := Color("f2fbff")

## Set by the room that builds it.
var room_name := ""
## Asked to travel from here (interact at a lit shrine, with somewhere else to go).
signal travel
## Kindled the moment a boss falls: it rises out of the floor, already lit.
var kindle := false

var _time := 0.0
var _lit := false
var _near := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 20)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -10)
	add_child(col)
	body_entered.connect(_on_body_entered)
	_lit = kindle or (Game.rest_room == room_name and Game.rest_point == global_position)
	if kindle:
		scale = Vector2(1, 0)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	_near = _lit and Game.shrines.size() > 1 and player != null \
		and player.global_position.distance_to(global_position) < 24.0
	if _near and Input.is_action_just_pressed("interact") and not get_tree().paused:
		travel.emit()
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	Sfx.play("rest", -2.0, 0.0)
	if body.has_method("heal_full"):
		body.heal_full()
	_lit = true
	Game.rest_at(room_name, global_position)


func _draw() -> void:
	# A squat altar: base, pillar and a bowl on top.
	draw_rect(Rect2(-7, -4, 14, 4), COLOR_STONE)
	draw_rect(Rect2(-4, -11, 8, 7), COLOR_STONE)
	draw_rect(Rect2(-6, -13, 12, 2), COLOR_STONE_TOP)
	var flicker := sin(_time * 7.0) * 0.6 + sin(_time * 11.0) * 0.4
	var height := 7.0 + flicker if _lit else 3.0 + flicker * 0.5
	var glow := 0.35 if _lit else 0.15
	draw_circle(Vector2(0, -16), 6.0 + flicker, Color(COLOR_FLAME, glow * 0.6))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3, -13), Vector2(0, -13 - height), Vector2(3, -13),
	]), Color(COLOR_FLAME, 0.9))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1.5, -13), Vector2(0, -13 - height * 0.55), Vector2(1.5, -13),
	]), COLOR_FLAME_CORE)
	if _near:
		var bob := sin(_time * 3.0)
		draw_string(Game.font, Vector2(-40, -30 + bob), "%s: travel" % Game.prompt("interact"),
			HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color(0.75, 0.92, 1.0))
