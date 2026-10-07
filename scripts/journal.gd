extends CanvasLayer
## The journal (from the pause menu): the bestiary (every kind of foe Storm has put down,
## with a few words on it) and the lore (every sign, carving and note he's read). Left /
## right turns between them, up / down chooses, Esc closes.

signal closed

const Rooms := preload("res://scripts/rooms.gd")
const SIZE := Vector2(480, 270)
const COLOR_PANEL := Color(0.06, 0.06, 0.09, 0.95)
const COLOR_EDGE := Color(0.75, 0.62, 0.45)
const COLOR_TEXT := Color(0.88, 0.88, 0.9)
const COLOR_DIM := Color(0.55, 0.56, 0.62)
const ROWS := 11

var _page := 0
var _choice := 0
var _canvas: Control


func _ready() -> void:
	layer = 41
	process_mode = Node.PROCESS_MODE_ALWAYS
	scale = Vector2(Game.ART_SCALE, Game.ART_SCALE)
	_canvas = Control.new()
	_canvas.size = SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_journal)
	add_child(_canvas)


## The entries on the page open: [name, text], or ["???", ""] for a foe not yet met.
func _entries() -> Array:
	var list := []
	if _page == 0:
		for id in Rooms.BESTIARY:
			var info: Array = Rooms.BESTIARY[id]
			list.append(info if Game.journal.has(id) else ["???", "Not yet met."])
	else:
		for text in Game.lore:
			list.append([text.left(34) + ("..." if text.length() > 34 else ""), text])
		if list.is_empty():
			list.append(["(nothing yet)", "Signs, carvings and notes Storm reads are kept here."])
	return list


func _unhandled_input(event: InputEvent) -> void:
	var count := _entries().size()
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		closed.emit()
		queue_free()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left") \
			or event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_page = 1 - _page
		_choice = 0
		Sfx.play("menu_move", -6.0, 0.0)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("look_down"):
		_choice = mini(_choice + 1, count - 1)
		Sfx.play("menu_move", -8.0, 0.0)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("look_up"):
		_choice = maxi(_choice - 1, 0)
		Sfx.play("menu_move", -8.0, 0.0)
	else:
		return
	get_viewport().set_input_as_handled()
	_canvas.queue_redraw()


func _draw_journal() -> void:
	var font := ThemeDB.fallback_font
	var panel := Rect2(30, 24, 420, 222)
	_canvas.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0, 0, 0, 0.5))
	_canvas.draw_rect(panel, COLOR_PANEL)
	_canvas.draw_rect(panel, COLOR_EDGE, false, 1.0)
	var tabs := ["Bestiary", "Lore"]
	for i in 2:
		var at := Vector2(panel.position.x + 14 + i * 80, panel.position.y + 16)
		_canvas.draw_string(font, at, tabs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_EDGE if i == _page else COLOR_DIM)
	_canvas.draw_line(Vector2(panel.position.x + 8, panel.position.y + 22), Vector2(panel.end.x - 8, panel.position.y + 22),
		Color(COLOR_EDGE, 0.5), 1.0)
	var list := _entries()
	_choice = clampi(_choice, 0, list.size() - 1)
	var first := clampi(_choice - ROWS / 2, 0, maxi(0, list.size() - ROWS))
	for row in mini(ROWS, list.size() - first):
		var i := first + row
		var y := panel.position.y + 38 + row * 16
		if i == _choice:
			_canvas.draw_rect(Rect2(panel.position.x + 6, y - 11, 170, 15), Color(COLOR_EDGE, 0.15))
		_canvas.draw_string(font, Vector2(panel.position.x + 12, y), list[i][0], HORIZONTAL_ALIGNMENT_LEFT, 160, 9,
			COLOR_TEXT if i == _choice else COLOR_DIM)
	_canvas.draw_line(Vector2(panel.position.x + 184, panel.position.y + 28), Vector2(panel.position.x + 184, panel.end.y - 18),
		Color(COLOR_EDGE, 0.3), 1.0)
	var entry: Array = list[_choice]
	if _page == 0:
		_canvas.draw_string(font, Vector2(panel.position.x + 194, panel.position.y + 40), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_EDGE)
	_canvas.draw_multiline_string(font, Vector2(panel.position.x + 194, panel.position.y + (58 if _page == 0 else 40)), entry[1],
		HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 206, 10, -1, COLOR_TEXT)
	var found := 0
	if _page == 0:
		for id in Rooms.BESTIARY:
			if Game.journal.has(id):
				found += 1
	var footer := "%d / %d" % [found, Rooms.BESTIARY.size()] if _page == 0 else "%d read" % Game.lore.size()
	_canvas.draw_string(font, Vector2(panel.position.x + 12, panel.end.y - 6), "Left / right: page     Esc: close     " + footer,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(COLOR_DIM, 0.7))
