extends CanvasLayer
## The pause menu (Esc / P / Start): resume, the map, music and sound volume, fullscreen,
## screen shake, the play timer, the controls (each rebindable), quit to the title (progress
## is saved), quit the game (picked twice).

signal map_requested
signal quit_to_title

const MenuList := preload("res://scripts/menu_list.gd")
const SIZE := Vector2(960, 540)

var _canvas: Control
var _menu: Control
var _open := false
var _main_options: Array = []
## Rebinding: the action waiting for a key, or "".
var _waiting := ""
var _quit_armed := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.size = SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_backing)
	add_child(_canvas)
	_menu = MenuList.new()
	_menu.position = Vector2(0, 170)
	_menu.size = Vector2(SIZE.x, 340)
	_menu.font_size = 16
	_menu.options = [
		{"text": "Resume", "pick": close},
		{"text": "Map", "pick": _pick_map},
		{"text": "Journal", "pick": _open_journal},
		{"text": func() -> String: return "Music   < %d%% >" % roundi(Game.music_volume * 100),
			"adjust": func(step: int) -> void: _volume("music_volume", step), "pick": func() -> void: _volume("music_volume", 1)},
		{"text": func() -> String: return "Sound   < %d%% >" % roundi(Game.sfx_volume * 100),
			"adjust": func(step: int) -> void: _volume("sfx_volume", step), "pick": func() -> void: _volume("sfx_volume", 1)},
		{"text": func() -> String: return "Fullscreen   %s" % ("On" if Game.fullscreen else "Off"),
			"adjust": func(_step: int) -> void: _toggle_fullscreen(), "pick": _toggle_fullscreen},
		{"text": func() -> String: return "Screen shake   %s" % ("On" if Game.screen_shake else "Off"),
			"adjust": func(_step: int) -> void: _toggle("screen_shake"), "pick": func() -> void: _toggle("screen_shake")},
		{"text": func() -> String: return "Play timer   %s" % ("On" if Game.show_timer else "Off"),
			"adjust": func(_step: int) -> void: _toggle("show_timer"), "pick": func() -> void: _toggle("show_timer")},
		{"text": "Controls", "pick": _show_controls},
		{"text": "Quit to title", "pick": _pick_quit_to_title},
		{"text": func() -> String: return "Quit game? Pick again" if _quit_armed else "Quit game",
			"pick": func() -> void:
				if _quit_armed:
					get_tree().quit()
				_quit_armed = true},
	]
	_main_options = _menu.options
	_menu.moved.connect(func() -> void: _quit_armed = false)
	add_child(_menu)
	_set_open(false)


## The controls: each action and its key; pick one, then press the key to put in its place.
func _show_controls() -> void:
	var list := []
	for entry: Array in Game.REBINDABLE:
		var action: String = entry[0]
		var label: String = entry[1]
		list.append({"text": func() -> String: return "%s   %s" % [label, "press a key..." if _waiting == action else Game.key_names(action)],
			"pick": func() -> void:
				_waiting = action
				_menu.active = false})
	list.append({"text": "Back", "pick": func() -> void:
		_menu.options = _main_options
		_menu.selected = 0})
	_menu.options = list
	_menu.selected = 0


func _unhandled_input(event: InputEvent) -> void:
	if _waiting != "" and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode != KEY_ESCAPE:
			Game.rebind(_waiting, event.physical_keycode)
		_waiting = ""
		_menu.active = true
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _open:
			close()
		elif not get_tree().paused:
			open()
	elif _open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _open_journal() -> void:
	var journal: CanvasLayer = load("res://scripts/journal.gd").new()
	_menu.active = false
	journal.closed.connect(func() -> void: _menu.active = true)
	add_child(journal)


func _pick_map() -> void:
	close()
	map_requested.emit()


func _pick_quit_to_title() -> void:
	close()
	quit_to_title.emit()


func open() -> void:
	_menu.options = _main_options
	_menu.selected = 0
	_quit_armed = false
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


func _toggle(setting: String) -> void:
	Game.set(setting, not Game.get(setting))
	Game.save_settings()


func _toggle_fullscreen() -> void:
	Game.fullscreen = not Game.fullscreen
	Game.apply_settings()
	Game.save_settings()


func _draw_backing() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.02, 0.03, 0.05, 0.72))
	var font := Game.font
	var text := "Paused"
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	_canvas.draw_string(font, Vector2((SIZE.x - width) / 2.0, 130), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32,
		Color("e8ecf4"))
