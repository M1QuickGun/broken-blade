extends CanvasLayer
## Trading with a survivor at the refuge: what they have, what it costs in crowns, and what
## Storm carries. Up / down to choose, jump or attack to buy, Esc to leave. The
## game holds still meanwhile.

signal closed

const SIZE := Vector2(480, 270)
const COLOR_PANEL := Color(0.06, 0.06, 0.09, 0.92)
const COLOR_EDGE := Color(0.75, 0.62, 0.45)
const COLOR_TEXT := Color(0.88, 0.88, 0.9)
const COLOR_DIM := Color(0.55, 0.56, 0.62)
const COLOR_GOLD := Color(0.95, 0.78, 0.36)

## Each shop's wares: [id, name, what it does, price]. Some appear only once others are
## bought (see _available), and each is bought once.
const WARES := {
	"smith": [
		["hone_1", "Hone the blade", "Bram works the old edge true again. Your blows strike harder.", 150],
		["hone_2", "Hone it finer", "Another pass at the whetstone, the way he did for your grandfather.", 400],
	],
	"healer": [
		["flask_1", "A spare flask", "One more sip of the shrine's flame to carry.", 120],
		["flask_2", "Another flask", "And one more. Maud keeps them for those who come back.", 320],
		["shop_mask", "An old guard's mask", "From a soldier who didn't need it any more. Your health grows.", 450],
	],
	"maps": [
		["map_foothills", "Map of the Foothills", "Every room of the forest, drawn before the fall.", 30],
		["map_ice", "Map of the Frozen village", "The village and its caverns, as they were.", 40],
		["map_cross", "Map of the Crossroads", "The roads, the refuge and the pass above.", 40],
		["map_fire", "Map of the Fire slopes", "The burned village, the forge and the climb.", 50],
		["map_storm", "Map of the Lightning peaks", "The cliff road, the spire and the eyrie.", 50],
		["map_castle", "Map of the Castle", "Drawn from memory: the halls, the tower, the throne.", 60],
	],
}

var shop := "smith"
var title := ""
var _choice := 0
var _note := ""
var _note_time := 0.0
var _canvas: Control


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_canvas = Control.new()
	_canvas.size = SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_shop)
	add_child(_canvas)
	scale = Vector2(Game.ART_SCALE, Game.ART_SCALE)
	Sfx.play("menu_move", -6.0, 0.0)


## The wares on offer now: not yet bought, and the next of a series only once the one
## before it is.
func _available() -> Array:
	var list := []
	for ware: Array in WARES[shop]:
		if _owned(ware[0]):
			continue
		if ware[0] == "hone_2" and Game.hone < 1:
			continue
		if ware[0] == "flask_2" and not Game.collected.has("flask_1"):
			continue
		list.append(ware)
	return list


func _owned(id: String) -> bool:
	if id.begins_with("map_"):
		return Game.maps.has(id.trim_prefix("map_"))
	if id.begins_with("hone_"):
		return Game.hone >= int(id.trim_prefix("hone_"))
	return Game.collected.has(id)


func _process(delta: float) -> void:
	_note_time -= delta
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var list := _available()
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("look_down"):
		_choice = mini(_choice + 1, maxi(list.size() - 1, 0))
		Sfx.play("menu_move", -8.0, 0.0)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("look_up"):
		_choice = maxi(_choice - 1, 0)
		Sfx.play("menu_move", -8.0, 0.0)
	elif event.is_action_pressed("jump") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		_buy(list)
	else:
		return
	get_viewport().set_input_as_handled()


func _buy(list: Array) -> void:
	if list.is_empty():
		return
	var ware: Array = list[clampi(_choice, 0, list.size() - 1)]
	if not Game.spend(ware[3]):
		_say("Not enough crowns.")
		Sfx.play("menu_move", -2.0, 0.0)
		return
	Sfx.play("pickup", -4.0, 0.0)
	var id: String = ware[0]
	if id.begins_with("hone_"):
		Game.hone += 1
		_say("The edge sings.")
	elif id.begins_with("flask_"):
		Game.collected[id] = true
		Game.max_flasks += 1
		Game.refill_flasks()
		_say("Another flask at your belt.")
	elif id.begins_with("map_"):
		Game.maps[id.trim_prefix("map_")] = true
		_say("Wren hands it over. It's on your map now.")
	elif id == "shop_mask":
		Game.add_mask(id)
		_say("Your health grows.")
	Game.save_game()
	_choice = clampi(_choice, 0, maxi(_available().size() - 1, 0))


func _say(text: String) -> void:
	_note = text
	_note_time = 2.0


func _close() -> void:
	get_tree().paused = false
	Sfx.play("menu_pick", -8.0, 0.0)
	closed.emit()
	queue_free()


func _draw_shop() -> void:
	var font := ThemeDB.fallback_font
	var panel := Rect2(90, 40, 300, 190)
	_canvas.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0, 0, 0, 0.45))
	_canvas.draw_rect(panel, COLOR_PANEL)
	_canvas.draw_rect(panel, COLOR_EDGE, false, 1.0)
	_canvas.draw_string(font, Vector2(panel.position.x + 12, panel.position.y + 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_EDGE)
	# What Storm carries.
	var purse := "%d" % Game.crowns
	_canvas.draw_rect(Rect2(panel.end.x - 46, panel.position.y + 9, 5, 6), COLOR_GOLD)
	_canvas.draw_string(font, Vector2(panel.end.x - 38, panel.position.y + 16), purse, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GOLD)
	_canvas.draw_line(Vector2(panel.position.x + 10, panel.position.y + 25), Vector2(panel.end.x - 10, panel.position.y + 25), Color(COLOR_EDGE, 0.5), 1.0)
	var list := _available()
	if list.is_empty():
		_canvas.draw_string(font, Vector2(panel.position.x + 12, panel.position.y + 50), "Nothing more to trade.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_DIM)
	var y := panel.position.y + 42
	for i in list.size():
		var ware: Array = list[i]
		var chosen := i == clampi(_choice, 0, list.size() - 1)
		if chosen:
			_canvas.draw_rect(Rect2(panel.position.x + 6, y - 11, panel.size.x - 12, 15), Color(COLOR_EDGE, 0.15))
		var afford: bool = Game.crowns >= ware[3]
		_canvas.draw_string(font, Vector2(panel.position.x + 14, y), ware[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			COLOR_TEXT if chosen else COLOR_DIM)
		_canvas.draw_string(font, Vector2(panel.end.x - 60, y), "%d" % ware[3], HORIZONTAL_ALIGNMENT_RIGHT, 46, 10,
			COLOR_GOLD if afford else Color(0.6, 0.35, 0.3))
		y += 16
	if not list.is_empty():
		var ware: Array = list[clampi(_choice, 0, list.size() - 1)]
		_canvas.draw_multiline_string(font, Vector2(panel.position.x + 12, panel.end.y - 34), ware[2],
			HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 24, 9, -1, COLOR_DIM)
	if _note_time > 0.0:
		_canvas.draw_string(font, Vector2(panel.position.x, panel.end.y + 14), _note, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 10,
			Color(COLOR_TEXT, clampf(_note_time, 0.0, 1.0)))
	_canvas.draw_string(font, Vector2(panel.position.x + 12, panel.end.y - 8), "Up / down: choose     Jump: buy     Esc: leave",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(COLOR_DIM, 0.7))
