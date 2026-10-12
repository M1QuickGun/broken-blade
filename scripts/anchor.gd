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
	if style == "castle":
		# An iron chandelier: a hoop on its chain, three candles burning on it.
		draw_line(Vector2(0, -7), Vector2(0, -40), Color(0.25, 0.24, 0.28), 1.0)
		draw_arc(Vector2(0, 2), 9.0, 0.0, TAU, 20, Color(0.22, 0.2, 0.24), 3.0)
		draw_arc(Vector2(0, 2), 9.0, PI, TAU, 12, Color(0.45, 0.42, 0.48), 1.0)
		for x in [-8.0, 0.0, 8.0]:
			var flick := sin(_time * 9.0 + x) * 0.6
			draw_rect(Rect2(x - 1.0, -4.0, 2.0, 5.0), Color(0.86, 0.82, 0.7))
			draw_circle(Vector2(x, -6.0 + flick * 0.3), 1.6, Color(1.0, 0.75, 0.35))
			draw_circle(Vector2(x, -6.0), 5.0 + pulse, Color(1.0, 0.7, 0.3, 0.08))
		return
	draw_circle(Vector2.ZERO, 9.0 + pulse * 2.0, Color(GLOW[style], 0.12 + 0.08 * pulse))
	var tex: Texture2D = SKINS[style]
	draw_texture_rect(tex, Rect2(-8, -8, 16, 16), false)
