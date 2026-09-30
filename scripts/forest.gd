extends Node2D
## The Foothills forest at the foot of the mountain, drawn in two layers around a room's
## tiles: behind them a painted forest (art/world/forest_bg.png) that drifts slowly as the
## camera moves, and in front a leaf canopy over the ceiling with shafts of light breaking
## through it and dust drifting in the light.
## The room adds one of each (front = false / true) and hands over its size and cells.

const TILE := 16
const BACKDROP := preload("res://art/world/forest_bg.png")
## How much the backdrop follows the camera's movement across the room: 0 would pin it
## to the screen, 1 to the room.
const PARALLAX := 0.3
## A room's viewport in world units (480x270, see Game.ART_SCALE).
const VIEW := Vector2(480, 270)

const COLOR_SKY := Color("0b120e")
const COLOR_TRUNK_FAR := Color("111a14")
const COLOR_TRUNK_MID := Color("16211a")
const COLOR_TRUNK_EDGE := Color("1d2a21")
const COLOR_VINE := Color("1c2f22")
const COLOR_LEAF_DARK := Color("0f1d13")
const COLOR_LEAF := Color("18301d")
const COLOR_LEAF_LIGHT := Color("24452a")
const COLOR_LIGHT := Color(1.0, 0.93, 0.7)

var front := false
var size_px := Vector2.ZERO
## Solid cells ("#"), row by row, so shafts know where they land and the canopy which
## ceiling cells to cover.
var solid := PackedStringArray()
var seed_text := ""
## How bright the backdrop is: the open forest, or dim through the walls of the ruins.
var backdrop_tint := Color(0.72, 0.76, 0.74)

var _time := 0.0
var _shafts: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _trunks: Array[Dictionary] = []
var _vines: Array[Dictionary] = []
var _leaves: Array[Dictionary] = []
var _backdrop: Sprite2D


func _ready() -> void:
	z_index = 1 if front else -1
	if not front:
		_backdrop = Sprite2D.new()
		_backdrop.texture = BACKDROP
		_backdrop.modulate = backdrop_tint
		# Big enough to cover the view wherever the camera goes in this room.
		var travel := (size_px - VIEW).max(Vector2.ZERO) * PARALLAX
		var need := VIEW + travel + Vector2(8, 8)
		var tex := Vector2(BACKDROP.get_size())
		_backdrop.scale = Vector2.ONE * maxf(1.0, maxf(need.x / tex.x, need.y / tex.y))
		add_child(_backdrop)
		_update_backdrop()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var cols := int(size_px.x / TILE)
	# Light: a shaft every dozen tiles or so, slanting the same way, landing on the ground.
	var x := rng.randf_range(2.0, 8.0) * TILE
	while x < size_px.x - TILE:
		var top := x
		var slant := 0.35
		var land := _land_y(top, slant)
		_shafts.append({"x": top, "w": rng.randf_range(10.0, 22.0), "slant": slant, "land": land,
			"phase": rng.randf() * TAU})
		x += rng.randf_range(9.0, 16.0) * TILE
	for i in int(_shafts.size() * 10):
		_motes.append({"shaft": i % _shafts.size(), "t": rng.randf(), "off": rng.randf_range(-0.5, 0.5),
			"speed": rng.randf_range(0.02, 0.06), "phase": rng.randf() * TAU})
	# Trunks: far ones thin and faint, nearer ones wider with a lit edge.
	for layer in 2:
		var tx := rng.randf_range(0.0, 6.0) * TILE
		while tx < size_px.x:
			_trunks.append({"x": tx, "w": rng.randf_range(10.0, 18.0) if layer == 1 else rng.randf_range(5.0, 9.0),
				"layer": layer, "lean": rng.randf_range(-4.0, 4.0)})
			tx += rng.randf_range(4.0, 9.0) * TILE if layer == 0 else rng.randf_range(8.0, 15.0) * TILE
	for i in cols / 3:
		_vines.append({"x": rng.randf_range(0.0, size_px.x), "len": rng.randf_range(12.0, 56.0),
			"phase": rng.randf() * TAU})
	# Leaf clusters along the ceiling cells, thinning out where the light breaks through.
	for cx in cols:
		for cy in solid.size():
			if not _solid(cx, cy):
				break
			var bottom := cy
			if not _solid(cx, cy + 1):
				for n in 3:
					var p := Vector2((cx + rng.randf()) * TILE, (bottom + 1) * TILE - rng.randf_range(2.0, 10.0))
					if _near_shaft(p.x):
						continue
					_leaves.append({"pos": p, "r": rng.randf_range(4.0, 8.0), "shade": rng.randi_range(0, 2)})


func _process(delta: float) -> void:
	if front:
		_time += delta
		queue_redraw()
	else:
		_update_backdrop()


func _update_backdrop() -> void:
	var camera := get_viewport().get_camera_2d()
	var room_center := size_px / 2.0
	var view_center := room_center
	if camera:
		view_center = to_local(camera.get_screen_center_position())
	_backdrop.position = view_center - (view_center - room_center) * PARALLAX


func _draw() -> void:
	if front:
		_draw_front()
	else:
		_draw_back()


func _draw_back() -> void:
	draw_rect(Rect2(Vector2.ZERO, size_px), COLOR_SKY)
	if _backdrop:
		return  # the painted forest covers it
	for t in _trunks:
		var color := COLOR_TRUNK_FAR if t.layer == 0 else COLOR_TRUNK_MID
		var base_w: float = t.w
		var x: float = t.x
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + t.lean, 0), Vector2(x + t.lean + base_w * 0.8, 0),
			Vector2(x + base_w * 1.15, size_px.y), Vector2(x - base_w * 0.15, size_px.y),
		]), color)
		if t.layer == 1:
			# Light catches one edge of the nearer trunks, plus a branch or two.
			draw_line(Vector2(x + t.lean + base_w * 0.8, 0), Vector2(x + base_w * 1.15, size_px.y),
				COLOR_TRUNK_EDGE, 1.5)
			var by := size_px.y * 0.3
			draw_line(Vector2(x + base_w * 0.5, by), Vector2(x + base_w * 0.5 + 18.0, by - 14.0), color, 3.0)
	for v in _vines:
		var y := 0.0
		var pts := PackedVector2Array()
		while y <= v.len:
			pts.append(Vector2(v.x + sin(y * 0.2 + v.phase) * 1.5, y + TILE * 0.8))
			y += 4.0
		if pts.size() > 1:
			draw_polyline(pts, COLOR_VINE, 1.0)


func _draw_front() -> void:
	for s in _shafts:
		var pulse := 0.8 + 0.2 * sin(_time * 0.7 + s.phase)
		var top_x: float = s.x
		var land: float = s.land
		var bottom_x: float = top_x + land * s.slant
		var w: float = s.w
		draw_colored_polygon(PackedVector2Array([
			Vector2(top_x, 0), Vector2(top_x + w, 0),
			Vector2(bottom_x + w * 1.8, land), Vector2(bottom_x - w * 0.4, land),
		]), Color(COLOR_LIGHT, 0.06 * pulse))
		draw_colored_polygon(PackedVector2Array([
			Vector2(top_x + w * 0.3, 0), Vector2(top_x + w * 0.7, 0),
			Vector2(bottom_x + w * 1.0, land), Vector2(bottom_x + w * 0.4, land),
		]), Color(COLOR_LIGHT, 0.05 * pulse))
		# A warm pool where it lands.
		var pool := Vector2(bottom_x + w * 0.7, land)
		for i in 3:
			var rx := w * (1.4 - i * 0.35)
			_draw_ellipse(pool, Vector2(rx, 2.5 - i * 0.6), Color(COLOR_LIGHT, 0.06 + i * 0.03))
	for m in _motes:
		var s: Dictionary = _shafts[m.shaft]
		var t := fmod(m.t + _time * m.speed, 1.0)
		var y: float = t * s.land
		var x: float = s.x + y * s.slant + s.w * (0.7 + m.off) + sin(_time + m.phase) * 3.0
		var fade := sin(t * PI)
		draw_rect(Rect2(x, y, 1, 1), Color(COLOR_LIGHT, 0.55 * fade))
	for leaf in _leaves:
		var color: Color = [COLOR_LEAF_DARK, COLOR_LEAF, COLOR_LEAF_LIGHT][leaf.shade]
		draw_circle(leaf.pos, leaf.r, color)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _solid(cx: int, cy: int) -> bool:
	if cy < 0 or cy >= solid.size():
		return false
	var row: String = solid[cy]
	return cx >= 0 and cx < row.length() and row[cx] == "#"


## How far down a shaft starting at x (at the top) travels before it hits solid ground.
func _land_y(x: float, slant: float) -> float:
	var y := TILE * 2.0
	while y < size_px.y:
		var cx := int((x + y * slant) / TILE)
		if _solid(cx, int(y / TILE)):
			return floorf(y / TILE) * TILE
		y += 4.0
	return size_px.y


func _near_shaft(x: float) -> bool:
	for s in _shafts:
		if x > s.x - 4.0 and x < s.x + s.w + 4.0:
			return true
	return false
