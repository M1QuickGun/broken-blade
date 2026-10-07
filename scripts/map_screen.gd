extends CanvasLayer
## The map (M / Tab / Back, or from the pause menu): every room Storm has been in, laid out
## as Rooms.MAP places them, with the one he's in highlighted, where he stands in it, and the
## rest shrines, bosses and elites (struck through once beaten), the refuge's trades, a
## survivor waiting to be found, and Storm's own pins (jump to drop one where the view is
## centred, attack to lift the nearest). It opens centred on him; move to pan around. Pauses
## the game while open.

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
const COLOR_BOSS := Color("e05a4a")
const COLOR_BEATEN := Color("6a6e78")
const COLOR_SHOP := Color(0.95, 0.78, 0.36)
const COLOR_SURVIVOR := Color("f0e2c8")
const COLOR_PIN := Color("f2d04a")
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
	elif _open and event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		Game.pins.append(_view_center())
		Sfx.play("menu_pick", -6.0, 0.0)
	elif _open and event.is_action_pressed("attack") and not Game.pins.is_empty():
		get_viewport().set_input_as_handled()
		var at := _view_center()
		var nearest := 0
		for i in Game.pins.size():
			if (Game.pins[i] as Vector2).distance_to(at) < (Game.pins[nearest] as Vector2).distance_to(at):
				nearest = i
		if (Game.pins[nearest] as Vector2).distance_to(at) < 12.0:
			Game.pins.remove_at(nearest)
			Sfx.play("menu_move", -6.0, 0.0)


## The map tile at the middle of the screen.
func _view_center() -> Vector2:
	return Vector2(Rooms.MAP[current_room]) + storm_at / Rooms.TILE - _pan / ZOOM


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
		# A boss or an elite: a red mark, crossed out grey once beaten.
		var foe: Dictionary = Rooms.BOSSES.get(room, Rooms.ELITES.get(room, {}))
		if not foe.is_empty():
			_draw_foe(r.get_center() + Vector2(0, -r.size.y * 0.2), Game.defeated.has(foe.id))
		if room == "refuge":
			_canvas.draw_circle(r.get_center() + Vector2(10, 0), 4.0, COLOR_SHOP)
			_canvas.draw_circle(r.get_center() + Vector2(10, 0), 2.0, Color(0.6, 0.45, 0.2))
		var who: Dictionary = Rooms.SURVIVORS.get(room, {})
		if not who.is_empty() and not Game.rescued.has(who.id):
			_draw_survivor(r.get_center())
	for pin: Vector2 in Game.pins:
		_draw_pin((pin - center) * ZOOM + SIZE / 2.0 + _pan)
	# Where a pin would go: the middle of the view.
	var mid := SIZE / 2.0
	_canvas.draw_line(mid + Vector2(-5, 0), mid + Vector2(5, 0), Color(1, 1, 1, 0.25), 1.0)
	_canvas.draw_line(mid + Vector2(0, -5), mid + Vector2(0, 5), Color(1, 1, 1, 0.25), 1.0)
	# Storm, blinking.
	if fmod(_time, 0.8) < 0.55:
		var p := SIZE / 2.0 + _pan
		_canvas.draw_circle(p, 4.5, Color(0, 0, 0, 0.6))
		_canvas.draw_circle(p, 3.5, COLOR_STORM)
	var font := Game.font
	_canvas.draw_string(font, Vector2(24, 36), "Map", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("e8ecf4"))
	_canvas.draw_string(font, Vector2(24, SIZE.y - 24),
		Game.fill_prompts("Move to look around.   {jump}: drop a pin   {attack}: lift a pin   {map} / {pause}: close"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_TEXT)
	for i in REGION_NAMES.size():
		var key: String = REGION_NAMES[i][0]
		var at := Vector2(24 + i * 150, 60)
		_canvas.draw_rect(Rect2(at, Vector2(12, 10)), REGION_COLORS[key][0])
		_canvas.draw_rect(Rect2(at, Vector2(12, 10)), REGION_COLORS[key][1], false, 1.0)
		_canvas.draw_string(font, at + Vector2(18, 10), REGION_NAMES[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_TEXT)
	# The legend, down the right side.
	var key_at := Vector2(SIZE.x - 170, SIZE.y - 150)
	var keys := [["Rest shrine", 0], ["Boss or elite", 1], ["Beaten", 2], ["Trades", 3], ["Someone lost", 4], ["Your pin", 5]]
	for i in keys.size():
		var p: Vector2 = key_at + Vector2(0, i * 20)
		match keys[i][1]:
			0:
				_canvas.draw_circle(p, 3.5, COLOR_SHRINE)
			1:
				_draw_foe(p, false)
			2:
				_draw_foe(p, true)
			3:
				_canvas.draw_circle(p, 4.0, COLOR_SHOP)
			4:
				_draw_survivor(p)
			5:
				_draw_pin(p + Vector2(0, 5))
		_canvas.draw_string(font, p + Vector2(14, 6), keys[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_TEXT)


func _draw_foe(at: Vector2, beaten: bool) -> void:
	var c := COLOR_BEATEN if beaten else COLOR_BOSS
	_canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -5), at + Vector2(5, 0), at + Vector2(0, 5), at + Vector2(-5, 0)]), c)
	if beaten:
		_canvas.draw_line(at + Vector2(-5, -5), at + Vector2(5, 5), Color(0.9, 0.9, 0.9, 0.7), 1.5)


func _draw_survivor(at: Vector2) -> void:
	_canvas.draw_circle(at + Vector2(0, -4), 2.5, COLOR_SURVIVOR)
	_canvas.draw_rect(Rect2(at + Vector2(-2.5, -1.5), Vector2(5, 6)), COLOR_SURVIVOR)


func _draw_pin(at: Vector2) -> void:
	_canvas.draw_line(at, at + Vector2(0, -12), Color(0.85, 0.85, 0.85), 1.5)
	_canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -12), at + Vector2(8, -9), at + Vector2(0, -6)]), COLOR_PIN)
