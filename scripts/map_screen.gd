extends CanvasLayer
## The map (M / Tab / Back, or from the pause menu): every room Storm has been in, laid out
## as Rooms.MAP places them, with the one he's in highlighted, where he stands in it, and the
## rest shrines. It opens centred on him; move to pan around. Pauses the game while open.

const Rooms := preload("res://scripts/rooms.gd")
const SIZE := Vector2(960, 540)
## Screen pixels per tile.
const ZOOM := 3.0
const PAN_SPEED := 420.0
const COLOR_BACK := Color(0.03, 0.04, 0.06, 0.92)
const COLOR_ROOM := Color("1d2330")
const COLOR_ROOM_EDGE := Color("6f7a90")
const COLOR_HERE := Color("2c3a52")
const COLOR_HERE_EDGE := Color("c9d6ee")
const COLOR_SHRINE := Color("9fe6ff")
const COLOR_STORM := Color("f3e6b0")
const COLOR_TEXT := Color("9aa3b5")
## Each region's colour on the map: [fill, edge].
const REGION_COLORS := {
	"foothills": [Color("1c2a20"), Color("6f9a72")],
	"ice": [Color("1b2734"), Color("7fb3d8")],
	"fire": [Color("2e2019"), Color("d0875a")],
	"storm": [Color("26213a"), Color("b9a4ec")],
	"cross": [Color("2a2720"), Color("d6c58c")],
	"castle": [Color("241f2c"), Color("c9b6d8")],
	"other": [Color("1d2330"), Color("6f7a90")],
}
const REGION_NAMES := [["foothills", "Foothills"], ["ice", "Frozen village"], ["cross", "Crossroads"],
	["fire", "Fire slopes"], ["storm", "Lightning peaks"], ["castle", "Castle"]]

## Set by Main: the room Storm is in and where he is in it (world units).
var current_room := ""
var storm_at := Vector2.ZERO

var _canvas: Control
var _open := false
var _pan := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	layer = 41
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.size = SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	add_child(_canvas)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		if _open:
			close()
		elif not get_tree().paused:
			open()
	elif _open and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_open = true
	visible = true
	_pan = Vector2.ZERO
	get_tree().paused = true


func close() -> void:
	_open = false
	visible = false
	get_tree().paused = false


func _process(delta: float) -> void:
	if not _open:
		return
	_time += delta
	var move := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("look_up", "look_down"))
	_pan -= move * PAN_SPEED * delta
	_canvas.queue_redraw()


func _region(room: String) -> String:
	if room in Rooms.CASTLE_ROOMS:
		return "castle"
	if room in Rooms.CROSS_ROOMS or room in Rooms.SUMMIT_ROOMS:
		return "cross"
	if room in Rooms.FIRE_ROOMS:
		return "fire"
	if room in Rooms.STORM_ROOMS:
		return "storm"
	if room in Rooms.ICE_ROOMS:
		return "ice"
	if room in Rooms.FOREST_ROOMS or room in Rooms.CAVE_ROOMS:
		return "foothills"
	return "other"


## A room's rectangle on screen, given where the view is centred (in tiles).
func _room_rect(room: String, center: Vector2) -> Rect2:
	var at: Vector2i = Rooms.MAP[room]
	var rows: Array = Rooms.LAYOUTS[room]
	var tiles := Vector2(String(rows[0]).length(), rows.size())
	return Rect2((Vector2(at) - center) * ZOOM + SIZE / 2.0 + _pan, tiles * ZOOM)


func _draw_map() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, SIZE), COLOR_BACK)
	if not Rooms.MAP.has(current_room):
		return
	var center := Vector2(Rooms.MAP[current_room]) + storm_at / Rooms.TILE
	for room in Rooms.MAP:
		if not Game.visited.has(room) and room != current_room:
			# A room not yet walked: drawn faintly from Wren's map of its region, if bought.
			if Game.maps.has(_region(room)) and room not in Rooms.SECRET_ROOMS:
				var faint := _room_rect(room, center)
				var edge: Color = REGION_COLORS[_region(room)][1]
				_canvas.draw_rect(faint, Color(edge, 0.08))
				_canvas.draw_rect(faint, Color(edge, 0.35), false, 1.0)
			continue
		var r := _room_rect(room, center)
		var here: bool = room == current_room
		var colors: Array = REGION_COLORS[_region(room)]
		_canvas.draw_rect(r, colors[0].lightened(0.15) if here else colors[0])
		_canvas.draw_rect(r, COLOR_HERE_EDGE if here else colors[1], false, 2.0 if here else 1.0)
		# Rest shrines.
		var rows: Array = Rooms.LAYOUTS[room]
		for y in rows.size():
			var x := String(rows[y]).find("R")
			if x == -1 and Rooms.BOSSES.has(room) and Game.defeated.has(Rooms.BOSSES[room].id):
				x = String(rows[y]).find("S")  # kindled when its boss fell
			if x != -1:
				var p := r.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * ZOOM
				_canvas.draw_circle(p, 3.5, COLOR_SHRINE)
	# Storm, blinking.
	if fmod(_time, 0.8) < 0.55:
		var p := SIZE / 2.0 + _pan
		_canvas.draw_circle(p, 4.5, Color(0, 0, 0, 0.6))
		_canvas.draw_circle(p, 3.5, COLOR_STORM)
	var font := ThemeDB.fallback_font
	_canvas.draw_string(font, Vector2(24, 36), "Map", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e8ecf4"))
	_canvas.draw_string(font, Vector2(24, SIZE.y - 24), "Move to look around.   M / Esc to close.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_TEXT)
	for i in REGION_NAMES.size():
		var key: String = REGION_NAMES[i][0]
		var at := Vector2(24 + i * 150, 60)
		_canvas.draw_rect(Rect2(at, Vector2(12, 10)), REGION_COLORS[key][0])
		_canvas.draw_rect(Rect2(at, Vector2(12, 10)), REGION_COLORS[key][1], false, 1.0)
		_canvas.draw_string(font, at + Vector2(18, 10), REGION_NAMES[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_TEXT)
	_canvas.draw_circle(Vector2(SIZE.x - 150, SIZE.y - 30), 3.5, COLOR_SHRINE)
	_canvas.draw_string(font, Vector2(SIZE.x - 140, SIZE.y - 24), "Rest shrine", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		COLOR_TEXT)
