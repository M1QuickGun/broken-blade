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
## Each blade piece, cut from the sword's own art (art/blade/piece_*.png, point up).
const PIECES := {
	"dash": preload("res://art/blade/piece_ice.png"),
	"double_jump": preload("res://art/blade/piece_fire.png"),
	"shockline": preload("res://art/blade/piece_tip.png"),
}
## The pieces are drawn at 2x detail, a touch bigger to stand out.
const PIECE_SCALE := 0.6

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
	draw_piece(self, ability, bob)


## A blade piece glowing at `at` on `canvas`, turned by `angle` (0: point up). Bosses draw
## the piece they hold this way as it comes free of them.
static func draw_piece(canvas: CanvasItem, ability: String, at: Vector2, angle := 0.0, alpha := 1.0) -> void:
	var tex: Texture2D = PIECES[ability]
	var size := Vector2(tex.get_size()) * PIECE_SCALE
	var glow: Color = COLORS[ability]
	canvas.draw_circle(at, size.y * 0.45, Color(glow, 0.18 * alpha))
	canvas.draw_circle(at, size.y * 0.3, Color(glow, 0.15 * alpha))
	canvas.draw_set_transform(at, angle)
	canvas.draw_texture_rect(tex, Rect2(-size / 2.0, size), false, Color(1, 1, 1, alpha))
	canvas.draw_set_transform(Vector2.ZERO)
