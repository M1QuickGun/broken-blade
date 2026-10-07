extends Area2D
## A clay urn left standing in the ruins. Strike it and it shatters, spilling a few crowns.
## It's back the next time the room is entered. The node's origin is at its base.

const Coin := preload("res://scripts/coin.gd")
const LAYER_ENEMY := 4
const COLOR_CLAY := Color("6b4a36")
const COLOR_CLAY_DARK := Color("4a3226")
const COLOR_CLAY_LIGHT := Color("8a6448")

## Set by the room: the region's tint for the clay.
var tint := Color.WHITE
## The urn's shape, varied a little each time.
var _wide := randf_range(5.0, 7.0)
var _tall := randf_range(11.0, 15.0)
## A pot is a target to swing at, but it never hurts Storm.
var harmless := true


func _ready() -> void:
	collision_layer = LAYER_ENEMY
	collision_mask = 0
	monitoring = false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(_wide * 2.0, _tall)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -_tall / 2.0)
	add_child(col)


func take_hit(_damage: int, _from_dir: Vector2) -> void:
	Sfx.play("shatter", -10.0, 0.25)
	var room := get_parent()
	if room.has_method("_spawn_debris"):
		for i in 5:
			room._spawn_debris(position + Vector2(randf_range(-5, 5), -_tall / 2.0), COLOR_CLAY * tint)
	Coin.drop(get_parent(), position + Vector2(0, -6), randi_range(2, 5))
	queue_free()


func _draw() -> void:
	# A squat urn: a round belly, a narrow neck, a lip.
	var c := COLOR_CLAY * tint
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		pts.append(Vector2(-cos(a) * _wide, -sin(a) * _tall * 0.75))
	draw_colored_polygon(pts, c)
	draw_rect(Rect2(-_wide * 0.45, -_tall, _wide * 0.9, _tall * 0.3), c)
	draw_rect(Rect2(-_wide * 0.6, -_tall - 1.0, _wide * 1.2, 2.0), COLOR_CLAY_LIGHT * tint)
	draw_rect(Rect2(-_wide * 0.8, -_tall * 0.45, _wide * 1.6, 1.0), COLOR_CLAY_DARK * tint)
	draw_rect(Rect2(-_wide * 0.5, -_tall * 0.62, 1.5, _tall * 0.3), Color(COLOR_CLAY_LIGHT * tint, 0.6))
