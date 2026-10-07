extends CanvasLayer
## The opening, played on a new game: four painted panels (art/story/intro_*.png), each
## drifting slowly while a line of the story types out beneath it. Jump / enter moves on;
## Esc / pause skips the lot. The ending plays the same way with its own panels (ENDING);
## a panel with no painting is just its words on black.

signal finished

const SIZE := Vector2(960, 540)
const PANELS := [
	["res://art/story/intro_1.png", "The kingdom stood upon the mountain, and above it the great blade held an ancient evil sealed."],
	["res://art/story/intro_2.png", "Then the blade shattered, and the evil it held poured out over the kingdom."],
	["res://art/story/intro_3.png", "With the last of his power, the King cast his son from the summit."],
	["res://art/story/intro_4.png", "Storm woke at the foot of the mountain, with only a shard of the blade in his hand."],
]
## The end, after the Hollow King falls.
const ENDING := [
	["res://art/story/ending_1.png", "The evil came apart into smoke, and the pieces of the blade rang as they came together in Storm's hand."],
	["res://art/story/ending_1.png", "But a blade alone had never held it. The seal needed a life bound to it, as the first king had given his."],
	["res://art/story/ending_2.png", "So Storm drove the blade into the stone before the throne, and bound himself to it. The evil sank back into the dark beneath the mountain."],
	["res://art/story/intro_1.png", "Spring came to the mountain at last. The survivors climbed to the castle, and found him there, kneeling, his hands on the blade."],
	["", "His watch had only begun.

Broken Blade
Thank you for playing."],
]
const PANEL_TIME := 7.0
const FADE := 1.0
const TYPE_SPEED := 38.0
const COLOR_TEXT := Color("e8ecf4")

## Which panels to play (the opening, unless set to ENDING before it's added).
var panels: Array = PANELS
var _canvas: Control
var _panel := 0
var _time := 0.0
var _textures: Array[Texture2D] = []
var _done := false


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	for panel in panels:
		_textures.append(load(panel[0]) if panel[0] != "" and ResourceLoader.exists(panel[0]) else null)
	_canvas = Control.new()
	_canvas.size = SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_panel)
	add_child(_canvas)


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	if _time >= PANEL_TIME:
		_next()
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()
	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		var text: String = tr(panels[_panel][1])
		if _time < FADE + text.length() / TYPE_SPEED:
			_time = FADE + text.length() / TYPE_SPEED  # show the whole line first
		else:
			_next()


func _next() -> void:
	_panel += 1
	_time = 0.0
	if _panel >= panels.size():
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func _draw_panel() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, SIZE), Color.BLACK)
	if _panel >= panels.size():
		return
	var fade := clampf(minf(_time / FADE, (PANEL_TIME - _time) / FADE), 0.0, 1.0)
	var tex := _textures[_panel]
	if tex:
		# A slow drift and zoom across the painting.
		var t := _time / PANEL_TIME
		var scale := maxf(SIZE.x / tex.get_width(), SIZE.y / tex.get_height()) * (1.08 + 0.06 * t)
		var tex_size := Vector2(tex.get_size()) * scale
		var drift := Vector2(lerpf(-14.0, 14.0, t) * (1 if _panel % 2 == 0 else -1), lerpf(6.0, -6.0, t))
		_canvas.draw_texture_rect(tex, Rect2((SIZE - tex_size) / 2.0 + drift, tex_size), false, Color(1, 1, 1, fade))
	# The story, typed out over a dark band at the bottom.
	_canvas.draw_rect(Rect2(0, SIZE.y - 96, SIZE.x, 96), Color(0, 0, 0, 0.55 * fade))
	var text: String = tr(panels[_panel][1])
	var shown := text.left(int(maxf(0.0, _time - FADE * 0.6) * TYPE_SPEED))
	var font := Game.font
	var at := Vector2(80, SIZE.y - 62)
	_canvas.draw_multiline_string(font, at + Vector2(2, 2), shown, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x - 160, 16,
		-1, Color(0, 0, 0, fade))
	_canvas.draw_multiline_string(font, at, shown, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x - 160, 16, -1,
		Color(COLOR_TEXT, fade))
	_canvas.draw_string(font, Vector2(SIZE.x - 210, 30), Game.fill_prompts("{jump}: next     {pause}: skip"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(0.6, 0.65, 0.75, 0.6 * fade))
