extends CanvasLayer
## The pause menu (Esc / P / Start): resume, the map, music and sound volume, fullscreen,
## quit to the title (progress is saved), quit the game.

signal map_requested
signal quit_to_title

const MenuList := preload("res://scripts/menu_list.gd")
const SIZE := Vector2(960, 540)

var _canvas: Control
var _menu: Control
var _open := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.size = SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_backing)
	add_child(_canvas)
	_menu = MenuList.new()
	_menu.position = Vector2(0, 190)
	_menu.size = Vector2(SIZE.x, 260)
	_menu.options = [
		{"text": "Resume", "pick": close},
		{"text": "Map", "pick": _pick_map},
		{"text": func() -> String: return "Music   < %d%% >" % roundi(Game.music_volume * 100),
			"adjust": func(step: int) -> void: _volume("music_volume", step), "pick": func() -> void: _volume("music_volume", 1)},
		{"text": func() -> String: return "Sound   < %d%% >" % roundi(Game.sfx_volume * 100),
			"adjust": func(step: int) -> void: _volume("sfx_volume", step), "pick": func() -> void: _volume("sfx_volume", 1)},
		{"text": func() -> String: return "Fullscreen   %s" % ("On" if Game.fullscreen else "Off"),
			"adjust": func(_step: int) -> void: _toggle_fullscreen(), "pick": _toggle_fullscreen},
		{"text": "Quit to title", "pick": _pick_quit_to_title},
		{"text": "Quit game", "pick": func() -> void: get_tree().quit()},
	]
	add_child(_menu)
	_set_open(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _open:
			close()
		elif not get_tree().paused:
			open()
	elif _open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _pick_map() -> void:
	close()
	map_requested.emit()


func _pick_quit_to_title() -> void:
	close()
	quit_to_title.emit()


func open() -> void:
	_menu.selected = 0
	_set_open(true)
	get_tree().paused = true


func close() -> void:
	_set_open(false)
	get_tree().paused = false


func _set_open(on: bool) -> void:
	_open = on
	visible = on
	_menu.active = on


func _volume(setting: String, step: int) -> void:
	var value: float = Game.get(setting)
	value = clampf(snappedf(value + step * 0.1, 0.1), 0.0, 1.0)
	if step > 0 and value >= 1.0 and Game.get(setting) >= 1.0:
		value = 0.0  # picking past full wraps round to silent
	Game.set(setting, value)
	Game.apply_settings()
	Game.save_settings()


func _toggle_fullscreen() -> void:
	Game.fullscreen = not Game.fullscreen
	Game.apply_settings()
	Game.save_settings()


func _draw_backing() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.02, 0.03, 0.05, 0.72))
	var font := ThemeDB.fallback_font
	var text := "Paused"
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	_canvas.draw_string(font, Vector2((SIZE.x - width) / 2.0, 150), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36,
		Color("e8ecf4"))
