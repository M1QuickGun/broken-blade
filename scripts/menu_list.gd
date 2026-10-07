extends Control
## A vertical list of menu options, driven by keyboard or controller: up and down to choose,
## left and right to change a setting, jump / enter / attack to pick. The title screen and
## the pause menu use it.
##
## Each option is a dictionary: {"text": String or Callable returning one, "pick": Callable,
## "adjust": Callable taking -1 or 1 (optional), "visible": Callable returning bool
## (optional)}.

signal moved

const COLOR_TEXT := Color("9aa3b5")
const COLOR_CHOSEN := Color("f2f4f8")
const COLOR_MARK := Color("9fe6ff")
const LINE_HEIGHT := 30.0

var options: Array = []
var font_size := 16
var selected := 0
## Read input this frame (menus beneath one that's open stay still).
var active := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hidden(1)


func _shown() -> Array:
	return options.filter(func(o: Dictionary) -> bool: return not o.has("visible") or o.visible.call())


func _skip_hidden(step: int) -> void:
	var shown := _shown()
	if shown.is_empty():
		return
	selected = clampi(selected, 0, shown.size() - 1)


func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	var shown := _shown()
	if shown.is_empty():
		return
	if _pressed(event, ["ui_up", "look_up"]):
		selected = (selected - 1 + shown.size()) % shown.size()
		moved.emit()
	elif _pressed(event, ["ui_down", "look_down"]):
		selected = (selected + 1) % shown.size()
		moved.emit()
	elif _pressed(event, ["ui_left", "move_left"]) and shown[selected].has("adjust"):
		shown[selected].adjust.call(-1)
		moved.emit()
	elif _pressed(event, ["ui_right", "move_right"]) and shown[selected].has("adjust"):
		shown[selected].adjust.call(1)
		moved.emit()
	elif _pressed(event, ["ui_accept", "jump", "attack"]) and shown[selected].has("pick"):
		get_viewport().set_input_as_handled()
		Sfx.play("menu_pick", -4.0, 0.0)
		shown[selected].pick.call()
		return
	else:
		return
	get_viewport().set_input_as_handled()
	Sfx.play("menu_move", -6.0, 0.0)
	queue_redraw()


func _pressed(event: InputEvent, actions: Array) -> bool:
	for action in actions:
		if InputMap.has_action(action) and event.is_action_pressed(action, false):
			return true
	return false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := Game.font
	var shown := _shown()
	for i in shown.size():
		var option: Dictionary = shown[i]
		var text: String = option.text.call() if option.text is Callable else option.text
		var chosen := i == selected
		var y := i * LINE_HEIGHT
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x := (size.x - width) / 2.0
		if chosen:
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 220.0)
			draw_string(font, Vector2(x - 26, y + font_size), "-", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Color(COLOR_MARK, pulse))
			draw_string(font, Vector2(x + width + 12, y + font_size), "-", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Color(COLOR_MARK, pulse))
		draw_string(font, Vector2(x + 1, y + font_size + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(x, y + font_size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			COLOR_CHOSEN if chosen else COLOR_TEXT)
