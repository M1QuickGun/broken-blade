extends CanvasLayer
## The credits, rolling up the screen after the ending. Jump hurries them; Esc ends them.

signal finished

const SIZE := Vector2(960, 540)
const SPEED := 34.0
const COLOR_HEAD := Color(0.75, 0.62, 0.45)
const COLOR_TEXT := Color(0.88, 0.88, 0.9)
## [heading, lines] in order; a heading of "" is a gap.
const ROLL := [
	["BROKEN BLADE", []],
	["", []],
	["Created by", ["Storm Wassel"]],
	["Design and direction", ["Storm Wassel"]],
	["Programming, music and sound", ["Built with Claude (Anthropic), directed by Storm Wassel"]],
	["Art", ["Made with PixelLab, directed by Storm Wassel"]],
	["Made with", ["Godot Engine (godotengine.org), under the MIT license"]],
	["", []],
	["Thank you for playing.", []],
]

var _y := 0.0
var _canvas: Control
var _done := false


func _ready() -> void:
	layer = 46
	process_mode = Node.PROCESS_MODE_ALWAYS
	_y = SIZE.y + 20.0
	_canvas = Control.new()
	_canvas.size = SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_roll)
	add_child(_canvas)


func _process(delta: float) -> void:
	var fast := Input.is_action_pressed("jump") or Input.is_action_pressed("ui_accept")
	_y -= SPEED * (4.0 if fast else 1.0) * delta
	if _y < -_height() - 40.0:
		_finish()
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func _height() -> float:
	var h := 0.0
	for entry: Array in ROLL:
		h += 64.0 + entry[1].size() * 32.0
	return h


func _draw_roll() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, SIZE), Color.BLACK)
	var font := Game.font
	var y := _y
	for entry: Array in ROLL:
		if entry[0] != "":
			var big: bool = entry[0] == "BROKEN BLADE"
			_canvas.draw_string(font, Vector2(0, y), entry[0], HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 64 if big else 32,
				COLOR_TEXT if big else COLOR_HEAD)
		y += 64.0
		for line: String in entry[1]:
			_canvas.draw_string(font, Vector2(0, y - 24), line, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 16, COLOR_TEXT)
			y += 32.0
