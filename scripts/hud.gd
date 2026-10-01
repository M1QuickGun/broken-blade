extends CanvasLayer
## Health masks, blade piece count, on-screen messages and screen fades.

const COLOR_MASK_FULL := Color("e6e9f0")
const COLOR_MASK_EMPTY := Color("2a2e3a")
const COLOR_TEXT := Color("c9ced9")
const COLOR_FLASK := Color("9fe6ff")
const COLOR_FLASK_GLASS := Color("5a6275")
const COLOR_FLASK_EMPTY := Color("1c2029")
const COLOR_CORK := Color("7a6049")
## The healing flasks sit in a row under the masks.
const FLASKS_POS := Vector2(32, 34)

const ABILITY_NAMES := {"dash": "Ice", "double_jump": "Fire", "shockline": "Lightning"}
## The blade as it's been reforged so far (see Game.blade_stage): ice is the right half
## of the blade, fire the left half, lightning the tip.
const BLADE_ICONS := {
	"bare": preload("res://art/blade/blade_bare.png"),
	"hilt": preload("res://art/blade/blade_0_hilt.png"),
	"ice": preload("res://art/blade/blade_1_ice.png"),
	"ice_fire": preload("res://art/blade/blade_2_ice_fire.png"),
	"ice_lightning": preload("res://art/blade/blade_2_ice_lightning.png"),
	"full": preload("res://art/blade/blade_3_full.png"),
}
## The blade icons are 32x96. At scale 1 an icon pixel is one HUD unit, the same size
## as the masks' pixels, so the two read as one piece.
const BLADE_ICON_SCALE := 1.0
const BLADE_ICON_CENTER := Vector2(50, 17)
## The masks start just past the crossguard, so they sit along the blade.
const MASKS_POS := Vector2(30, 10)

const MASK_MESSAGE := "A mask of the old royal guard. Your health grows."
const BOSS_BAR_POS := Vector2(140, 250)
const BOSS_BAR_SIZE := Vector2(200, 4)
const COLOR_BOSS_BAR := Color("b33a3a")
const COLOR_BOSS_BAR_BACK := Color("2a1a1e")

const UNLOCK_MESSAGES := {
	"dash": "Ice shard recovered. Press Shift or L to dash.",
	"double_jump": "Fire shard recovered. Jump again in midair.",
	"shockline": "Lightning shard recovered. Right click to cast the shockline.",
	"wall_jump": "The hilt is yours again. Its sword catcher bites stone: hold toward a wall to cling, then jump.",
}

var _hp := 0
var _max_hp := 0
var _masks: Control
var _flasks: Control
var _pieces_label: Label
var _blade_icon: Sprite2D
var _message: Label
var _fade: ColorRect
var _boss_bar: Control
var _boss_label: Label
## The boss being fought (a boss.gd node), or null. Untyped: read for its title and hp.
var _boss = null
var _message_tween: Tween


func _ready() -> void:
	# Lay out in 480x270 units like the world, drawn at 2x on the 960x540 viewport.
	scale = Vector2(Game.ART_SCALE, Game.ART_SCALE)

	# The blade lies on its side behind the health masks, hilt at the left and tip to the
	# right, so the health bar itself grows grander as the blade is reforged.
	_blade_icon = Sprite2D.new()
	_blade_icon.rotation = PI / 2
	_blade_icon.scale = Vector2.ONE * BLADE_ICON_SCALE
	_blade_icon.position = BLADE_ICON_CENTER
	add_child(_blade_icon)

	_masks = Control.new()
	_masks.position = MASKS_POS
	_masks.draw.connect(_draw_masks)
	add_child(_masks)
	_flasks = Control.new()
	_flasks.position = FLASKS_POS
	_flasks.draw.connect(_draw_flasks)
	add_child(_flasks)
	_pieces_label = _make_label(Vector2(12, 46))
	_message = _make_label(Vector2(0, 200))
	_message.size = Vector2(480, 20)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0

	# The boss's name and health along the bottom of the screen while one is fighting.
	_boss_bar = Control.new()
	_boss_bar.position = BOSS_BAR_POS
	_boss_bar.draw.connect(_draw_boss_bar)
	add_child(_boss_bar)
	_boss_label = _make_label(BOSS_BAR_POS + Vector2(0, -14))
	_boss_label.size = Vector2(BOSS_BAR_SIZE.x, 12)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.size = Vector2(480, 270)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	Game.pieces_changed.connect(func(_count: int) -> void: _update_pieces())
	Game.ability_unlocked.connect(_on_ability_unlocked)
	Game.rested.connect(func() -> void: show_message("You rest. Your wounds are mended and your flasks refilled."))
	Game.flasks_changed.connect(func(_count: int, _max: int) -> void: _flasks.queue_redraw())
	Game.max_hp_changed.connect(func(_max: int) -> void: show_message(MASK_MESSAGE))
	_update_pieces()


func _process(_delta: float) -> void:
	var boss = get_tree().get_first_node_in_group("boss")
	if boss != _boss:
		_boss = boss
		_boss_label.text = boss.title if boss else ""
	_boss_bar.queue_redraw()


func _draw_boss_bar() -> void:
	if not is_instance_valid(_boss) or _boss.max_hp <= 0:
		return
	var frac := clampf(float(_boss.hp) / _boss.max_hp, 0.0, 1.0)
	_boss_bar.draw_rect(Rect2(Vector2(-1, -1), BOSS_BAR_SIZE + Vector2(2, 2)), COLOR_BOSS_BAR_BACK)
	_boss_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(BOSS_BAR_SIZE.x * frac, BOSS_BAR_SIZE.y)), COLOR_BOSS_BAR)


func set_hp(hp: int, max_hp: int) -> void:
	_hp = hp
	_max_hp = max_hp
	_masks.queue_redraw()


func show_message(text: String) -> void:
	_message.text = text
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(_message, "modulate:a", 1.0, 0.3)
	_message_tween.tween_interval(2.0)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.8)


## Straight to black (the world starts hidden and fades in).
func set_black() -> void:
	_fade.color.a = 1.0


func fade_out(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, duration)
	await tween.finished


func fade_in(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, duration)
	await tween.finished


func _make_label(pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	add_child(label)
	return label


func _on_ability_unlocked(ability: String) -> void:
	show_message(UNLOCK_MESSAGES[ability])


func _update_pieces() -> void:
	var names: Array[String] = []
	for ability: String in ["dash", "double_jump", "shockline"]:
		if Game.has_ability(ability):
			names.append(ABILITY_NAMES[ability])
	_blade_icon.texture = BLADE_ICONS[Game.blade_stage()]
	_pieces_label.text = "Blade  %d / %d" % [Game.pieces, Game.MAX_PIECES]
	if not names.is_empty():
		_pieces_label.text += "   " + "  ".join(names)


func _draw_flasks() -> void:
	for i in Game.max_flasks:
		var o := Vector2(i * 9, 0)
		var full := i < Game.flasks
		# Glass body, neck and cork; the pale flame fills the full ones.
		_flasks.draw_rect(Rect2(o + Vector2(0, 3), Vector2(7, 6)), COLOR_FLASK_GLASS)
		_flasks.draw_rect(Rect2(o + Vector2(1, 4), Vector2(5, 4)), COLOR_FLASK if full else COLOR_FLASK_EMPTY)
		_flasks.draw_rect(Rect2(o + Vector2(2, 1), Vector2(3, 2)), COLOR_FLASK_GLASS)
		_flasks.draw_rect(Rect2(o + Vector2(2, 0), Vector2(3, 1)), COLOR_CORK)
		if full:
			_flasks.draw_rect(Rect2(o + Vector2(2, 5), Vector2(1, 2)), Color(1, 1, 1, 0.7))


func _draw_masks() -> void:
	for i in _max_hp:
		var color := COLOR_MASK_FULL if i < _hp else COLOR_MASK_EMPTY
		var o := Vector2(i * 13, 0)
		_masks.draw_colored_polygon(PackedVector2Array([
			o + Vector2(0, 0), o + Vector2(10, 0), o + Vector2(10, 8),
			o + Vector2(5, 13), o + Vector2(0, 8),
		]), color)
