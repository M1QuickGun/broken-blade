extends CanvasLayer
## Travelling between shrines: at any lit shrine, the list of every shrine Storm has rested at,
## by region. Up / down to choose, jump to go, Esc to stay. The game holds still meanwhile.

signal chosen(room: String, point: Vector2)
signal closed

const Rooms := preload("res://scripts/rooms.gd")
const SIZE := Vector2(480, 270)
const COLOR_PANEL := Color(0.06, 0.06, 0.09, 0.92)
const COLOR_EDGE := Color(0.62, 0.8, 0.9)
const COLOR_TEXT := Color(0.88, 0.88, 0.9)
const COLOR_DIM := Color(0.55, 0.56, 0.62)

## Where Storm is now (marked "here" and not picked).
var here := ""
var _choice := 0
var _canvas: Control
var _list: Array = []


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	scale = Vector2(Game.ART_SCALE, Game.ART_SCALE)
	get_tree().paused = true
	for key in Game.shrines:
		_list.append(Game.shrines[key])
	_list.sort_custom(func(a: Array, b: Array) -> bool:
		return Rooms.REGION_TITLES.keys().find(Rooms.region_of(a[0])) < Rooms.REGION_TITLES.keys().find(Rooms.region_of(b[0])))
	_canvas = Control.new()
	_canvas.size = SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_list)
	add_child(_canvas)
	Sfx.play("rest", -10.0, 0.0)


static func room_title(room: String) -> String:
	return room.replace("_", " ").capitalize()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("look_down"):
		_choice = mini(_choice + 1, _list.size() - 1)
		Sfx.play("menu_move", -8.0, 0.0)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("look_up"):
		_choice = maxi(_choice - 1, 0)
		Sfx.play("menu_move", -8.0, 0.0)
	elif event.is_action_pressed("jump") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		var pick: Array = _list[_choice]
		if pick[0] != here:
			get_tree().paused = false
			Sfx.play("menu_pick", -4.0, 0.0)
			chosen.emit(pick[0], Vector2(pick[1], pick[2]))
			queue_free()
	else:
		return
	get_viewport().set_input_as_handled()
	_canvas.queue_redraw()


func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()


func _draw_list() -> void:
	var font := Game.font
	var panel := Rect2(110, 30, 260, 210)
	_canvas.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0, 0, 0, 0.45))
	_canvas.draw_rect(panel, COLOR_PANEL)
	_canvas.draw_rect(panel, COLOR_EDGE, false, 1.0)
	_canvas.draw_string(font, panel.position + Vector2(12, 18), "Travel to a shrine", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_EDGE)
	var first := clampi(_choice - 5, 0, maxi(0, _list.size() - 11))
	for row in mini(11, _list.size() - first):
		var i := first + row
		var entry: Array = _list[i]
		var y := panel.position.y + 42 + row * 15
		if i == _choice:
			_canvas.draw_rect(Rect2(panel.position.x + 6, y - 11, panel.size.x - 12, 14), Color(COLOR_EDGE, 0.15))
		var region: String = Rooms.REGION_TITLES[Rooms.region_of(entry[0])].trim_prefix("The ")
		var text := "%s  -  %s%s" % [region, room_title(entry[0]), "   (here)" if entry[0] == here else ""]
		_canvas.draw_string(font, Vector2(panel.position.x + 14, y), text, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 24, 8,
			COLOR_TEXT if i == _choice else COLOR_DIM)
	_canvas.draw_string(font, Vector2(panel.position.x + 12, panel.end.y - 8),
		Game.fill_prompts("{jump}: travel     {pause}: stay"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(COLOR_DIM, 0.8))
