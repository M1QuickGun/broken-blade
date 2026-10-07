extends CanvasLayer
## The title screen: the kingdom on its mountain (the intro's first painting), the name over
## the reforged blade, motes of light drifting down, and the three save slots: pick an empty
## one to begin, a full one to carry on. "Erase a save" then a slot (twice) clears it.

signal chosen(choice: String)

const MenuList := preload("res://scripts/menu_list.gd")
const BACKDROP := preload("res://art/story/intro_1.png")
const Rooms := preload("res://scripts/rooms.gd")
const BLADE := preload("res://art/blade/blade_3_full.png")
const SIZE := Vector2(960, 540)
const COLOR_TITLE := Color("e8ecf4")
const COLOR_SUB := Color("8f9bb0")
const COLOR_LIGHT := Color(1.0, 0.93, 0.7)

var _canvas: Control
var _menu: Control
var _time := 0.0
var _motes: Array[Dictionary] = []
var _fade := 1.0
var _leaving := false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.size = SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_title)
	add_child(_canvas)
	for i in 70:
		_motes.append({"x": randf() * SIZE.x, "y": randf() * SIZE.y, "speed": randf_range(8, 22),
			"phase": randf() * TAU})
	_menu = MenuList.new()
	_menu.position = Vector2(0, 340)
	_menu.size = Vector2(SIZE.x, 160)
	_menu.options = []
	for n in range(1, Game.SLOTS + 1):
		_menu.options.append({"text": func() -> String: return _slot_text(n), "pick": func() -> void: _pick_slot(n)})
	_menu.options.append({"text": func() -> String: return "New games: %s" % ("Hard mode" if _hard else "Normal"),
		"visible": func() -> bool: return Game.any_finished(),
		"adjust": func(_step: int) -> void: _hard = not _hard, "pick": func() -> void: _hard = not _hard})
	_menu.options.append({"text": func() -> String:
			return "Boss rush" + ("   best %s" % Game.clock(Game.rush_best) if Game.rush_best > 0.0 else ""),
		"visible": func() -> bool: return Game.any_finished(),
		"pick": func() -> void: _choose("rush")})
	_menu.options.append({"text": func() -> String: return "Cancel erasing" if _erasing else "Erase a save",
		"pick": func() -> void:
			_erasing = not _erasing
			_confirm = 0})
	_menu.options.append({"text": "Quit", "pick": func() -> void: get_tree().quit()})
	_menu.font_size = 16
	_menu.moved.connect(func() -> void: _confirm = 0)
	Game.playing = false
	add_child(_menu)
	Music.play("exploration")


func _process(delta: float) -> void:
	_time += delta
	_fade = move_toward(_fade, 1.0 if _leaving else 0.0, delta * 1.5)
	if _leaving and _fade >= 1.0:
		chosen.emit(_choice)
		queue_free()
	_canvas.queue_redraw()


var _choice := ""
var _erasing := false
var _hard := false
var _confirm := 0


func _slot_text(n: int) -> String:
	var info := Game.slot_summary(n)
	if _erasing and _confirm == n:
		return "Erase slot %d? Pick it again" % n
	if info.is_empty():
		return "Slot %d   -   %s" % [n, "empty" if _erasing else "New game"]
	var where: String = Rooms.REGION_TITLES[Rooms.region_of(info.room)] if info.room != "" else "The Foothills"
	return "Slot %d   %s   %d%%   %s%s%s" % [n, where, info.completion, Game.clock(info.time),
		"   (hard)" if info.hard else "", "   (the end)" if info.done else ""]


func _pick_slot(n: int) -> void:
	var filled := not Game.slot_summary(n).is_empty()
	if _erasing:
		if not filled:
			return
		if _confirm == n:
			Game.erase_slot(n)
			_erasing = false
			_confirm = 0
		else:
			_confirm = n
		return
	Game.slot = n
	Game.hard = _hard and not filled
	_choose("continue" if filled else "new")


func _choose(choice: String) -> void:
	if _leaving:
		return
	_choice = choice
	_leaving = true
	_menu.active = false
	_menu.visible = false


func _draw_title() -> void:
	# The forest, drifting slowly, dimmed.
	var scale := maxf(SIZE.x / BACKDROP.get_width(), SIZE.y / BACKDROP.get_height()) * 1.06
	var drift := Vector2(sin(_time * 0.05) * 12.0, cos(_time * 0.04) * 6.0)
	var tex_size := Vector2(BACKDROP.get_size()) * scale
	_canvas.draw_texture_rect(BACKDROP, Rect2((SIZE - tex_size) / 2.0 + drift, tex_size), false, Color(0.62, 0.64, 0.7))
	_canvas.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.02, 0.03, 0.04, 0.35))
	for m in _motes:
		var y := fmod(m.y + _time * m.speed, SIZE.y)
		var x: float = m.x + sin(_time * 0.6 + m.phase) * 10.0
		var glint := 0.3 + 0.3 * sin(_time * 1.7 + m.phase * 2.0)
		_canvas.draw_circle(Vector2(x, y), 1.5, Color(COLOR_LIGHT, glint))
	# The reforged blade lying behind the name.
	_canvas.draw_set_transform(Vector2(SIZE.x / 2.0, 205), PI / 2.0, Vector2(3.0, 3.0))
	_canvas.draw_texture(BLADE, -Vector2(BLADE.get_size()) / 2.0, Color(1, 1, 1, 0.55))
	_canvas.draw_set_transform(Vector2.ZERO)
	var font := Game.font
	_centered(font, "BROKEN BLADE", 150, 64, COLOR_TITLE)
	_centered(font, "a shard, a hilt, and a mountain to climb", 268, 16, COLOR_SUB)
	var version := "v%s%s" % [ProjectSettings.get_setting("application/config/version", ""), "  demo" if Game.demo else ""]
	_canvas.draw_string(font, Vector2(16, SIZE.y - 16), version, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(COLOR_SUB, 0.6))
	_canvas.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0, 0, 0, _fade))


func _centered(font: Font, text: String, y: float, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2((SIZE.x - width) / 2.0, y)
	_canvas.draw_string(font, at + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.7))
	_canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
