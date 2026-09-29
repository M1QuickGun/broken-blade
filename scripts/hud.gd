extends CanvasLayer
## Health masks, blade piece count, on-screen messages and screen fades.

const COLOR_MASK_FULL := Color("e6e9f0")
const COLOR_MASK_EMPTY := Color("2a2e3a")
const COLOR_TEXT := Color("c9ced9")

var _hp := 0
var _max_hp := 0
var _masks: Control
var _pieces_label: Label
var _message: Label
var _fade: ColorRect
var _message_tween: Tween


func _ready() -> void:
	_masks = Control.new()
	_masks.position = Vector2(12, 10)
	_masks.draw.connect(_draw_masks)
	add_child(_masks)

	_pieces_label = _make_label(Vector2(12, 28))
	_message = _make_label(Vector2(0, 200))
	_message.size = Vector2(480, 20)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.size = Vector2(480, 270)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	Game.pieces_changed.connect(_on_pieces_changed)
	_update_pieces()


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


func _on_pieces_changed(count: int) -> void:
	_update_pieces()
	if count >= Game.MAX_PIECES:
		show_message("The blade is whole.")
	else:
		show_message("A shard returns. The blade grows longer.")


func _update_pieces() -> void:
	_pieces_label.text = "Blade  %d / %d" % [Game.pieces, Game.MAX_PIECES]


func _draw_masks() -> void:
	for i in _max_hp:
		var color := COLOR_MASK_FULL if i < _hp else COLOR_MASK_EMPTY
		var o := Vector2(i * 13, 0)
		_masks.draw_colored_polygon(PackedVector2Array([
			o + Vector2(0, 0), o + Vector2(10, 0), o + Vector2(10, 8),
			o + Vector2(5, 13), o + Vector2(0, 8),
		]), color)
