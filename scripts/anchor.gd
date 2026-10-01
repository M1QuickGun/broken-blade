extends Node2D
## A ring the lightning shockline can latch onto (Storm hooks his sword through it and
## hangs). Each region has its own: mossy bronze in the Foothills, ice in the Frozen village,
## molten iron on the fire slopes, crackling brass on the lightning peaks.

const SKINS := {
	"forest": preload("res://art/world/rings/forest.png"),
	"ice": preload("res://art/world/rings/ice.png"),
	"fire": preload("res://art/world/rings/fire.png"),
	"storm": preload("res://art/world/rings/storm.png"),
}
const GLOW := {
	"forest": Color(0.9, 0.85, 0.5), "ice": Color(0.6, 0.9, 1.0),
	"fire": Color(1.0, 0.55, 0.2), "storm": Color(1.0, 0.92, 0.4),
}

## Set by the room before it's added.
var style := "storm"

var _time := 0.0


func _ready() -> void:
	add_to_group("shock_target")
	_time = randf() * 5.0


func shock_point() -> Vector2:
	return global_position


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	draw_circle(Vector2.ZERO, 9.0 + pulse * 2.0, Color(GLOW[style], 0.12 + 0.08 * pulse))
	var tex: Texture2D = SKINS[style]
	draw_texture_rect(tex, Rect2(-8, -8, 16, 16), false)
