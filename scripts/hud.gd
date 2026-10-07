extends CanvasLayer
## Health masks, blade piece count, on-screen messages and screen fades.

const Rooms := preload("res://scripts/rooms.gd")
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
	"dash": "Ice shard recovered. {dash} to dash.",
	"double_jump": "Fire shard recovered. Jump again in midair.",
	"shockline": "Lightning shard recovered. {shockline} to cast the shockline.",
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
## The boss being fought (any boss, or an elite), or null. Untyped: read for its title and hp.
var _boss = null
var _message_tween: Tween
## The boss's name across the screen as its fight begins (and when it changes, mid-fight).
var _crowns: Control
var _danger: Control
var _timer: Control
var _card: Control
var _card_title := ""
var _card_sub := ""
var _card_time := -1.0
var _shown_title := ""
var _area_title := ""
var _area_time := -1.0
var _hurt: ColorRect


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

	_danger = Control.new()
	_danger.size = Vector2(480, 270)
	_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger.draw.connect(_draw_danger)
	add_child(_danger)
	move_child(_danger, 0)

	_timer = Control.new()
	_timer.position = Vector2(400, 6)
	_timer.draw.connect(_draw_timer)
	add_child(_timer)

	_crowns = Control.new()
	_crowns.position = FLASKS_POS + Vector2(0, 14)
	_crowns.draw.connect(_draw_crowns)
	add_child(_crowns)
	Game.crowns_changed.connect(func(_count: int) -> void: _crowns.queue_redraw())
	Game.achieved.connect(func(title: String) -> void: show_area("Achievement:  " + title))

	_card = Control.new()
	_card.size = Vector2(480, 270)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.draw.connect(_draw_card)
	add_child(_card)

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


const CARD_TIME := 3.2


func _process(delta: float) -> void:
	var boss = get_tree().get_first_node_in_group("boss")
	if boss != _boss:
		_boss = boss
	if boss and boss.title != _shown_title:
		_shown_title = boss.title
		_card_title = boss.title
		var sub = boss.get("subtitle")
		_card_sub = sub if sub is String else ""
		for info: Dictionary in Rooms.BOSSES.values():
			if _card_sub == "" and info.id == boss.get("boss_id") and info.title == boss.title:
				_card_sub = info.get("subtitle", "")
		_card_time = 0.0
	elif not boss:
		_shown_title = ""
	if _area_time >= 0.0:
		_area_time += delta
		if _area_time > CARD_TIME:
			_area_time = -1.0
		_card.queue_redraw()
	if _card_time >= 0.0:
		_card_time += delta
		if _card_time > CARD_TIME:
			_card_time = -1.0
		_card.queue_redraw()
	# (Read every frame: a boss can change its name mid-fight.)
	_boss_label.text = boss.title if boss else ""
	_boss_bar.queue_redraw()
	_timer.queue_redraw()
	if _hp == 1:
		_danger.queue_redraw()


## An area's name, fading in and out across the top of the screen.
func show_area(text: String) -> void:
	_area_title = text
	_area_time = 0.0


## The boss's name, large, with a line under it and a smaller line of who it is.
func _draw_card() -> void:
	if _area_time >= 0.0:
		var a := clampf(minf(_area_time / 0.8, (CARD_TIME - _area_time) / 0.8), 0.0, 1.0)
		var f := Game.font
		_card.draw_string(f, Vector2(0, 47), _area_title, HORIZONTAL_ALIGNMENT_CENTER, 480, 16, Color(0, 0, 0, a * 0.8))
		_card.draw_string(f, Vector2(0, 46), _area_title, HORIZONTAL_ALIGNMENT_CENTER, 480, 16, Color(0.88, 0.86, 0.8, a))
		_card.draw_line(Vector2(190, 52), Vector2(290, 52), Color(0.75, 0.62, 0.45, a * 0.8), 1.0)
	if _card_time < 0.0:
		return
	var alpha := clampf(minf(_card_time / 0.5, (CARD_TIME - _card_time) / 0.8), 0.0, 1.0)
	var font := Game.font
	var y := 96.0
	_card.draw_rect(Rect2(0, y - 30, 480, 58), Color(0, 0, 0, 0.35 * alpha))
	_card.draw_string(font, Vector2(0, y + 1), _card_title, HORIZONTAL_ALIGNMENT_CENTER, 480, 16, Color(0, 0, 0, alpha))
	_card.draw_string(font, Vector2(0, y), _card_title, HORIZONTAL_ALIGNMENT_CENTER, 480, 16, Color(0.92, 0.9, 0.86, alpha))
	var grow := clampf(_card_time / 0.9, 0.0, 1.0)
	_card.draw_line(Vector2(240 - 110 * grow, y + 7), Vector2(240 + 110 * grow, y + 7), Color(0.75, 0.62, 0.45, alpha), 1.0)
	if _card_sub != "":
		_card.draw_string(font, Vector2(0, y + 21), _card_sub, HORIZONTAL_ALIGNMENT_CENTER, 480, 8, Color(0.7, 0.72, 0.8, alpha))


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
	_danger.queue_redraw()


## On the last mask, the edges of the screen breathe red.
func _draw_danger() -> void:
	if _hp != 1 or _max_hp <= 1:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
	var c := Color(0.6, 0.04, 0.06, 0.1 + 0.12 * pulse)
	for i in 4:
		var w := 6.0 + i * 6.0
		_danger.draw_rect(Rect2(0, 0, 480, w), Color(c, c.a * (1.0 - i * 0.22)))
		_danger.draw_rect(Rect2(0, 270 - w, 480, w), Color(c, c.a * (1.0 - i * 0.22)))
		_danger.draw_rect(Rect2(0, 0, w, 270), Color(c, c.a * (1.0 - i * 0.22)))
		_danger.draw_rect(Rect2(480 - w, 0, w, 270), Color(c, c.a * (1.0 - i * 0.22)))


func show_message(text: String) -> void:
	_message.text = Game.fill_prompts(text)
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(_message, "modulate:a", 1.0, 0.3)
	_message_tween.tween_interval(2.0)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.8)


## A red flash at the screen's edges when Storm is hurt.
func flash_hurt() -> void:
	if _hurt == null:
		_hurt = ColorRect.new()
		_hurt.size = Vector2(480, 270)
		_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hurt.color = Color(0.7, 0.05, 0.08, 0.0)
		add_child(_hurt)
		move_child(_hurt, 0)
	_hurt.color.a = 0.32
	var tween := create_tween()
	tween.tween_property(_hurt, "color:a", 0.0, 0.35)


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
	label.add_theme_font_size_override("font_size", 8)
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


func _draw_timer() -> void:
	if Game.show_timer:
		var font := Game.font
		_timer.draw_string(font, Vector2(0, 10), Game.clock(Game.play_time), HORIZONTAL_ALIGNMENT_RIGHT, 70, 8, Color(COLOR_TEXT, 0.8))


func _draw_crowns() -> void:
	var font := Game.font
	_crowns.draw_rect(Rect2(-1, -4, 7, 8), Color("6b4f22"))
	_crowns.draw_rect(Rect2(0, -3, 5, 6), Color(0.95, 0.78, 0.36))
	_crowns.draw_rect(Rect2(1, -2, 1, 2), Color(1, 0.96, 0.8))
	_crowns.draw_string(font, Vector2(10, 4), str(Game.crowns), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_TEXT)


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
