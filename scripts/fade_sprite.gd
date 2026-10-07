extends Node2D
## A foe's last moment: its final frame flashed white, then sinking a little and fading out,
## coming apart into ash. Made with FadeSprite.leave(...) where something dies.

const LIFE := 0.5

var texture: Texture2D
var region := Rect2()
var rect := Rect2()
var flip := 1.0
var color := Color.WHITE
var _time := 0.0


## Leaves a fading copy of a drawn frame: `rect` is where it was drawn, around `at`.
static func leave(parent: Node, at: Vector2, tex: Texture2D, src: Rect2, dst: Rect2, flip_x: float, tint: Color) -> void:
	if parent == null or not parent.is_inside_tree() or tex == null:
		return
	var ghost: Node2D = load("res://scripts/fade_sprite.gd").new()
	ghost.texture = tex
	ghost.region = src
	ghost.rect = dst
	ghost.flip = flip_x
	ghost.color = tint
	ghost.position = at
	parent.add_child(ghost)


func _process(delta: float) -> void:
	_time += delta
	if _time >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _time / LIFE
	var tint := Color(3, 3, 3, 1) if t < 0.12 else Color(color.r, color.g, color.b, color.a * (1.0 - t))
	draw_set_transform(Vector2(0, t * 4.0), 0.0, Vector2(flip * (1.0 + t * 0.1), 1.0 - t * 0.15))
	draw_texture_rect_region(texture, rect, region, tint)
	draw_set_transform(Vector2.ZERO)
