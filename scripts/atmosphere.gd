extends Node2D
## A region's atmosphere, drawn in two layers around a room's tiles: behind them a painted
## backdrop that drifts slowly as the camera moves, and in front the weather and light.
## - "forest" (the Foothills): a leaf canopy over any ceiling, shafts of light breaking
##   through, dust drifting in the light.
## - "snow" (the Frozen village, outdoors): snow falling and blowing across the room, and
##   icicles under every overhang.
## - "cave" (the frozen caverns): frost glinting as it drifts up through the cold air, a faint
##   glow off the ice, and icicles under every overhang.
## - "ash" (the Fire slopes, outdoors): embers rising off the burned village, ash drifting
##   down through slow smoke, a red glow low in the sky, and embers smouldering on the ground.
## - "forge" (the Fire slopes, under rock): the same embers thicker, heat glowing up from
##   below, and molten drips glowing under every overhang.
## - "rain" (the Lightning peaks, outdoors): rain slanting down in the wind and splashing on
##   the ground, and now and then lightning: the room flashes white and thunder follows.
## - "static" (the Lightning peaks, under rock: the spire and the tower): static drifting and
##   flickering in the dark, water dripping from the overhangs, and arcs of lightning
##   jumping across the rock now and then.
## - "refuge" (the Crossroads and the survivors' camp): snow drifting down slowly, warm
##   firelight low in the room, embers drifting up from the campfires.
## - "battlefield" (the Last Stand, on the summit): mist rolling low over the ground, ash and
##   snow blowing across, and now and then a distant flash, fire or lightning, over the pass.
## - "castle" (inside the king's castle): pale moonlight slanting in through the broken
##   windows, dust hanging in it, and now and then the evil's violet breathing through the
##   walls.
## The room adds one of each (front = false / true) and hands over its size and cells.

const TILE := 16
const BACKDROPS := {
	"forest": preload("res://art/world/forest_bg.png"),
	"snow": preload("res://art/world/ice_village_bg.png"),
	"cave": preload("res://art/world/ice_cave_bg.png"),
	"ash": preload("res://art/world/fire_village_bg.png"),
	"forge": preload("res://art/world/forge_bg.png"),
	"rain": preload("res://art/world/storm_peaks_bg.png"),
	"static": preload("res://art/world/spire_bg.png"),
	"refuge": preload("res://art/world/refuge_bg.png"),
	"battlefield": preload("res://art/world/last_stand_bg.png"),
	"castle": preload("res://art/world/castle_bg.png"),
}
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
const COLOR_SNOW := Color(0.9, 0.95, 1.0)
const COLOR_FROST := Color(0.7, 0.92, 1.0)
const COLOR_ICICLE := Color(0.72, 0.88, 1.0, 0.85)
const COLOR_ICICLE_SHINE := Color(0.95, 1.0, 1.0, 0.9)
const COLOR_EMBER := Color(1.0, 0.55, 0.18)
const COLOR_EMBER_HOT := Color(1.0, 0.86, 0.5)
const COLOR_ASH := Color(0.62, 0.6, 0.58)
const COLOR_SMOKE := Color(0.08, 0.07, 0.07)
const COLOR_HEAT := Color(1.0, 0.36, 0.1)
const COLOR_RAIN := Color(0.7, 0.78, 0.92)
const COLOR_FLASH := Color(0.9, 0.9, 1.0)
const COLOR_SPARK := Color(0.78, 0.66, 1.0)
const COLOR_ARC := Color(0.92, 0.88, 1.0)
const COLOR_MOON := Color(0.72, 0.82, 1.0)
const COLOR_EVIL := Color(0.45, 0.25, 0.7)
## Seconds between lightning flashes outdoors (at random within this range).
const FLASH_EVERY := Vector2(5.0, 11.0)

## "forest", "snow", "cave", "ash", "forge", "rain", "static", "refuge" or "battlefield".
var style := "forest"
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
var _flakes: Array[Dictionary] = []
var _icicles: Array[Dictionary] = []
var _embers: Array[Dictionary] = []
var _smoke: Array[Dictionary] = []
## Smouldering spots on the ground (outdoors) or molten drips under overhangs (the forge).
var _glows: Array[Dictionary] = []
## The storm: raindrops, splashes on the ground (where each lands), drips under the rock,
## arcs crackling across it, and when the next flash comes and how bright the last one is.
var _rain: Array[Dictionary] = []
var _ground: Array[Vector2] = []
var _splashes: Array[Dictionary] = []
var _drips: Array[Dictionary] = []
var _arcs: Array[Dictionary] = []
var _arc_spots: Array[Vector2] = []
var _next_flash := 0.0
var _flash := 0.0
var _thunder_in := -1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 1 if front else -2  # the centipede burrows at -1, between it and the tiles
	if not front:
		_backdrop = Sprite2D.new()
		_backdrop.texture = BACKDROPS[style]
		_backdrop.modulate = backdrop_tint
		# Big enough to cover the view wherever the camera goes in this room.
		var travel := (size_px - VIEW).max(Vector2.ZERO) * PARALLAX
		var need := VIEW + travel + Vector2(8, 8)
		var tex := Vector2(_backdrop.texture.get_size())
		_backdrop.scale = Vector2.ONE * maxf(1.0, maxf(need.x / tex.x, need.y / tex.y))
		add_child(_backdrop)
		_update_backdrop()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var cols := int(size_px.x / TILE)
	if style == "ash" or style == "forge":
		_setup_fire(rng, cols)
		return
	if style == "rain" or style == "static":
		_setup_storm(rng, cols)
		return
	if style == "refuge" or style == "battlefield" or style == "castle":
		_setup_pass(rng)
		return
	if style != "forest":
		_setup_frost(rng, cols)
		return
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


## Snowflakes or frost motes scattered through the room, and icicles under the overhangs.
func _setup_frost(rng: RandomNumberGenerator, cols: int) -> void:
	var count := int(size_px.x * size_px.y / (1400.0 if style == "snow" else 2600.0))
	for i in count:
		_flakes.append({
			"x": rng.randf() * size_px.x, "y": rng.randf() * size_px.y,
			"speed": rng.randf_range(14.0, 34.0) if style == "snow" else rng.randf_range(3.0, 9.0),
			"sway": rng.randf_range(4.0, 12.0), "phase": rng.randf() * TAU,
			# Depth: far flakes are small, slow and faint; near ones larger and brighter.
			"depth": rng.randf(),
		})
	# An icicle or two under most cells that hang over open air.
	for cy in solid.size():
		for cx in cols:
			if _solid(cx, cy) and not _solid(cx, cy + 1) and cy + 1 < solid.size() and rng.randf() < 0.55:
				for n in rng.randi_range(1, 2):
					_icicles.append({
						"x": (cx + rng.randf_range(0.15, 0.85)) * TILE, "y": (cy + 1) * TILE,
						"len": rng.randf_range(4.0, 13.0), "w": rng.randf_range(1.5, 3.0),
					})


## Embers rising, ash and smoke drifting, and glowing spots on the ground or under the rock.
func _setup_fire(rng: RandomNumberGenerator, cols: int) -> void:
	var forge := style == "forge"
	var area := size_px.x * size_px.y
	for i in int(area / (1800.0 if forge else 2600.0)):
		_embers.append({
			"x": rng.randf() * size_px.x, "y": rng.randf() * size_px.y,
			"speed": rng.randf_range(10.0, 30.0), "sway": rng.randf_range(3.0, 10.0),
			"phase": rng.randf() * TAU, "depth": rng.randf(),
		})
	if not forge:
		for i in int(area / 2200.0):
			_flakes.append({
				"x": rng.randf() * size_px.x, "y": rng.randf() * size_px.y,
				"speed": rng.randf_range(5.0, 12.0), "sway": rng.randf_range(6.0, 14.0),
				"phase": rng.randf() * TAU, "depth": rng.randf(),
			})
	for i in int(area / 30000.0) + 3:
		_smoke.append({
			"x": rng.randf() * size_px.x, "y": rng.randf_range(0.2, 0.9) * size_px.y,
			"r": rng.randf_range(24.0, 56.0), "speed": rng.randf_range(4.0, 9.0),
			"phase": rng.randf() * TAU,
		})
	for cy in solid.size():
		for cx in cols:
			if not _solid(cx, cy):
				continue
			if forge and not _solid(cx, cy + 1) and cy + 1 < solid.size() and rng.randf() < 0.3:
				_glows.append({"x": (cx + rng.randf_range(0.2, 0.8)) * TILE, "y": (cy + 1) * TILE,
					"len": rng.randf_range(3.0, 8.0), "phase": rng.randf() * TAU, "drip": true})
			elif not forge and cy > 0 and not _solid(cx, cy - 1) and rng.randf() < 0.18:
				_glows.append({"x": (cx + rng.randf_range(0.2, 0.8)) * TILE, "y": cy * TILE,
					"len": rng.randf_range(2.0, 5.0), "phase": rng.randf() * TAU, "drip": false})


## Snow and embers at the refuge; mist, blowing ash and far-off flashes on the battlefield.
func _setup_pass(rng: RandomNumberGenerator) -> void:
	_rng.seed = rng.randi()
	var area := size_px.x * size_px.y
	for i in int(area / (2400.0 if style == "refuge" else 3000.0 if style == "castle" else 1600.0)):
		_flakes.append({"x": rng.randf() * size_px.x, "y": rng.randf() * size_px.y,
			"speed": rng.randf_range(8.0, 18.0), "sway": rng.randf_range(4.0, 12.0),
			"phase": rng.randf() * TAU, "depth": rng.randf()})
	if style == "castle":
		# Moonbeams through the windows, every dozen tiles or so, all slanting the same way.
		var x := rng.randf_range(3.0, 10.0) * TILE
		while x < size_px.x:
			_shafts.append({"x": x, "w": rng.randf_range(14.0, 30.0), "phase": rng.randf() * TAU})
			x += rng.randf_range(10.0, 16.0) * TILE
		return
	if style == "refuge":
		for i in int(area / 9000.0):
			_embers.append({"x": rng.randf() * size_px.x, "y": rng.randf() * size_px.y,
				"speed": rng.randf_range(8.0, 18.0), "sway": rng.randf_range(3.0, 8.0),
				"phase": rng.randf() * TAU, "depth": rng.randf()})
	else:
		for i in int(size_px.x / 90.0) + 2:
			_smoke.append({"x": rng.randf() * size_px.x, "y": size_px.y - rng.randf_range(10.0, 70.0),
				"r": rng.randf_range(30.0, 70.0), "speed": rng.randf_range(5.0, 12.0), "phase": rng.randf() * TAU})
		_next_flash = rng.randf_range(4.0, 10.0)


## Rain and splashes outdoors; drips, static and arcs under the rock.
func _setup_storm(rng: RandomNumberGenerator, cols: int) -> void:
	_rng.seed = rng.randi()
	var area := size_px.x * size_px.y
	for cy in solid.size():
		for cx in cols:
			if not _solid(cx, cy):
				continue
			if cy > 0 and not _solid(cx, cy - 1):
				_ground.append(Vector2((cx + 0.5) * TILE, cy * TILE))
			if not _solid(cx, cy + 1) and cy + 1 < solid.size():
				_arc_spots.append(Vector2((cx + 0.5) * TILE, (cy + 1) * TILE))
				if style == "static" and rng.randf() < 0.12:
					_drips.append({"x": (cx + rng.randf_range(0.2, 0.8)) * TILE, "y": (cy + 1) * TILE,
						"t": rng.randf() * 3.0, "every": rng.randf_range(1.5, 3.5)})
	if style == "rain":
		for i in int(area / 700.0):
			_rain.append({"x": rng.randf() * size_px.x, "y": rng.randf() * size_px.y,
				"speed": rng.randf_range(320.0, 420.0), "len": rng.randf_range(5.0, 10.0), "depth": rng.randf()})
		_next_flash = rng.randf_range(2.0, FLASH_EVERY.y)
	else:
		for i in int(area / 2600.0):
			_flakes.append({"x": rng.randf() * size_px.x, "y": rng.randf() * size_px.y,
				"speed": rng.randf_range(3.0, 9.0), "sway": rng.randf_range(4.0, 12.0),
				"phase": rng.randf() * TAU, "depth": rng.randf()})
		_next_flash = rng.randf_range(1.0, 3.0)  # (here: the next arc across the rock)


func _update_storm(delta: float) -> void:
	_next_flash -= delta
	_flash = maxf(0.0, _flash - delta * 2.5)
	if style == "rain":
		if _next_flash <= 0.0:
			_next_flash = _rng.randf_range(FLASH_EVERY.x, FLASH_EVERY.y)
			_flash = 1.0
			_thunder_in = _rng.randf_range(0.3, 1.2)
		if _thunder_in > 0.0:
			_thunder_in -= delta
			if _thunder_in <= 0.0:
				Sfx.play("thunder", -6.0, 0.15)
		# A splash or two where the rain hits the ground.
		if not _ground.is_empty():
			for i in 2:
				if _rng.randf() < 0.6:
					_splashes.append({"pos": _ground[_rng.randi() % _ground.size()] + Vector2(_rng.randf_range(-8, 8), 0),
						"life": 0.25})
	else:
		for d in _drips:
			d.t += delta
		if _next_flash <= 0.0 and _arc_spots.size() > 1:
			_next_flash = _rng.randf_range(1.5, 4.0)
			var a: Vector2 = _arc_spots[_rng.randi() % _arc_spots.size()]
			var b: Vector2 = a + Vector2(_rng.randf_range(-60, 60), _rng.randf_range(10, 50))
			_arcs.append({"from": a, "to": b, "life": 0.18, "seed": _rng.randi()})
			Sfx.play("crackle", -18.0, 0.2)
	for sp in _splashes:
		sp.life -= delta
	_splashes = _splashes.filter(func(sp: Dictionary) -> bool: return sp.life > 0.0)
	for arc in _arcs:
		arc.life -= delta
	_arcs = _arcs.filter(func(arc: Dictionary) -> bool: return arc.life > 0.0)


func _process(delta: float) -> void:
	if front:
		_time += delta
		if style == "rain" or style == "static":
			_update_storm(delta)
		elif style == "battlefield":
			_next_flash -= delta
			_flash = maxf(0.0, _flash - delta * 1.5)
			if _next_flash <= 0.0:
				_next_flash = _rng.randf_range(6.0, 12.0)
				_flash = 1.0
				_thunder_in = 1.0 if _rng.randf() < 0.5 else -1.0  # (which: fire or lightning)
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
	if style == "castle":
		_draw_castle()
		return
	if style == "refuge" or style == "battlefield":
		_draw_pass()
		return
	if style == "rain" or style == "static":
		_draw_storm()
		return
	if style == "ash" or style == "forge":
		_draw_fire()
		return
	if style != "forest":
		_draw_frost()
		return
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


func _draw_frost() -> void:
	for ice in _icicles:
		var x: float = ice.x
		var y: float = ice.y
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - ice.w, y), Vector2(x + ice.w, y), Vector2(x, y + ice.len),
		]), COLOR_ICICLE)
		draw_line(Vector2(x - ice.w * 0.4, y), Vector2(x - 0.2, y + ice.len * 0.7), COLOR_ICICLE_SHINE, 1.0)
	for f in _flakes:
		var x: float
		var y: float
		var alpha := 0.75
		if style == "snow":
			# Falling and blowing a little sideways, wrapping round the room.
			var fall: float = f.speed * lerpf(0.5, 1.2, f.depth)
			y = fmod(f.y + _time * fall, size_px.y)
			x = fmod(f.x + _time * fall * 0.35 + sin(_time * 0.9 + f.phase) * f.sway, size_px.x)
		else:
			# Frost drifting slowly up through the cold, glinting on and off.
			y = fmod(f.y - _time * f.speed + size_px.y * 4.0, size_px.y)
			x = f.x + sin(_time * 0.5 + f.phase) * f.sway
			alpha = 0.25 + 0.5 * maxf(0.0, sin(_time * 1.3 + f.phase * 3.0))
		if x < 0.0:
			x += size_px.x
		var color := COLOR_SNOW if style == "snow" else COLOR_FROST
		var depth: float = f.depth
		var radius := lerpf(0.35, 0.9, depth)
		alpha *= lerpf(0.35, 0.85, depth)
		draw_circle(Vector2(x, y), radius + 0.5, Color(color, alpha * 0.35))
		draw_circle(Vector2(x, y), radius, Color(color, alpha))


func _draw_fire() -> void:
	var forge := style == "forge"
	# Heat glowing up from below the room, breathing slowly.
	var breathe := 0.8 + 0.2 * sin(_time * 0.8)
	var band := 70.0 if forge else 50.0
	for i in 4:
		var h := band * (1.0 - i * 0.22)
		draw_rect(Rect2(0, size_px.y - h, size_px.x, h), Color(COLOR_HEAT, (0.035 if forge else 0.025) * breathe))
	for s in _smoke:
		var x: float = fmod(s.x + _time * s.speed, size_px.x + s.r * 2.0) - s.r
		var y: float = s.y + sin(_time * 0.3 + s.phase) * 6.0
		draw_circle(Vector2(x, y), s.r, Color(COLOR_SMOKE, 0.1))
		draw_circle(Vector2(x + s.r * 0.5, y - s.r * 0.2), s.r * 0.7, Color(COLOR_SMOKE, 0.08))
	for g in _glows:
		var pulse := 0.55 + 0.45 * sin(_time * 1.7 + g.phase)
		if g.drip:
			# A bead of molten metal hanging off the rock, swelling and glowing.
			var x: float = g.x
			var y: float = g.y
			var drop: float = g.len * (0.8 + 0.2 * pulse)
			draw_circle(Vector2(x, y + drop * 0.5), 3.5, Color(COLOR_HEAT, 0.12 * pulse))
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - 1.5, y), Vector2(x + 1.5, y), Vector2(x + 1.0, y + drop), Vector2(x - 1.0, y + drop),
			]), Color(COLOR_EMBER, 0.9))
			draw_circle(Vector2(x, y + drop), 1.3, Color(COLOR_EMBER_HOT, 0.6 + 0.4 * pulse))
		else:
			# Embers smouldering in the ash on the ground.
			var p := Vector2(g.x, g.y - 0.5)
			_draw_ellipse(p, Vector2(g.len + 3.0, 2.0), Color(COLOR_HEAT, 0.12 * pulse))
			draw_rect(Rect2(p.x - g.len * 0.5, p.y - 1.0, g.len, 1.0), Color(COLOR_EMBER, 0.5 + 0.5 * pulse))
	for f in _flakes:
		# Ash drifting down, slower and lazier than snow.
		var fall: float = f.speed * lerpf(0.5, 1.2, f.depth)
		var y: float = fmod(f.y + _time * fall, size_px.y)
		var x: float = fmod(f.x + _time * fall * 0.6 + sin(_time * 0.6 + f.phase) * f.sway + size_px.x * 4.0, size_px.x)
		draw_rect(Rect2(x, y, 1.0, 1.0), Color(COLOR_ASH, lerpf(0.25, 0.6, f.depth)))
	for e in _embers:
		# Rising and weaving, flickering as they go.
		var rise: float = e.speed * lerpf(0.6, 1.3, e.depth)
		var y: float = fmod(e.y - _time * rise + size_px.y * 8.0, size_px.y)
		var x: float = e.x + sin(_time * 1.1 + e.phase) * e.sway + sin(_time * 2.9 + e.phase * 2.0) * 1.5
		var flicker := 0.45 + 0.55 * maxf(0.0, sin(_time * 4.0 + e.phase * 5.0))
		# Fading out near the top of their climb.
		var fade := clampf(y / (size_px.y * 0.25), 0.0, 1.0)
		var alpha := flicker * fade * lerpf(0.4, 1.0, e.depth)
		var r := lerpf(0.5, 1.1, e.depth)
		draw_circle(Vector2(x, y), r + 1.5, Color(COLOR_EMBER, alpha * 0.2))
		draw_circle(Vector2(x, y), r, Color(COLOR_EMBER_HOT if e.depth > 0.7 else COLOR_EMBER, alpha))


func _draw_pass() -> void:
	var refuge := style == "refuge"
	if refuge:
		# Firelight low in the hollow, breathing.
		var breathe := 0.85 + 0.15 * sin(_time * 1.3)
		for i in 3:
			var h := 60.0 * (1.0 - i * 0.3)
			draw_rect(Rect2(0, size_px.y - h, size_px.x, h), Color(COLOR_HEAT, 0.022 * breathe))
	else:
		for s in _smoke:
			# Mist rolling low over the field.
			var x: float = fmod(s.x + _time * s.speed, size_px.x + s.r * 2.0) - s.r
			var y: float = s.y + sin(_time * 0.4 + s.phase) * 4.0
			_draw_ellipse(Vector2(x, y), Vector2(s.r * 1.6, s.r * 0.35), Color(0.7, 0.72, 0.78, 0.07))
			_draw_ellipse(Vector2(x + s.r * 0.6, y - 4.0), Vector2(s.r, s.r * 0.25), Color(0.75, 0.77, 0.82, 0.05))
		if _flash > 0.0:
			var tint := COLOR_EMBER if _thunder_in > 0.0 else COLOR_SPARK
			draw_rect(Rect2(Vector2.ZERO, size_px), Color(tint, (0.02 if Game.reduce_flashes else 0.08) * _flash))
	for f in _flakes:
		# Snow at the refuge; ash and snow blowing across the battlefield.
		var fall: float = f.speed * lerpf(0.5, 1.2, f.depth)
		var y: float = fmod(f.y + _time * fall, size_px.y)
		var drift: float = 0.2 if refuge else 1.4
		var x: float = fmod(f.x + _time * fall * drift + sin(_time * 0.7 + f.phase) * f.sway + size_px.x * 8.0, size_px.x)
		var color := COLOR_SNOW if refuge or int(f.phase * 10.0) % 3 != 0 else COLOR_ASH
		draw_circle(Vector2(x, y), lerpf(0.4, 0.9, f.depth), Color(color, lerpf(0.25, 0.7, f.depth)))
	for e in _embers:
		var rise: float = e.speed * lerpf(0.6, 1.2, e.depth)
		var y: float = fmod(e.y - _time * rise + size_px.y * 8.0, size_px.y)
		var x: float = e.x + sin(_time * 1.1 + e.phase) * e.sway
		var flicker := 0.4 + 0.6 * maxf(0.0, sin(_time * 4.0 + e.phase * 5.0))
		draw_circle(Vector2(x, y), 0.8, Color(COLOR_EMBER, flicker * clampf(y / (size_px.y * 0.4), 0.0, 1.0)))


func _draw_castle() -> void:
	# The evil breathing through the walls: a slow violet swell over the whole room.
	var breath := maxf(0.0, sin(_time * 0.5)) ** 3
	draw_rect(Rect2(Vector2.ZERO, size_px), Color(COLOR_EVIL, 0.05 * breath))
	var slant := size_px.y * 0.35
	for s in _shafts:
		var pulse: float = 0.8 + 0.2 * sin(_time * 0.6 + s.phase)
		var x: float = s.x
		var w: float = s.w
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w + slant, size_px.y), Vector2(x + slant, size_px.y),
		]), Color(COLOR_MOON, 0.05 * pulse))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + w * 0.3, 0), Vector2(x + w * 0.7, 0), Vector2(x + w * 0.7 + slant, size_px.y),
			Vector2(x + w * 0.3 + slant, size_px.y),
		]), Color(COLOR_MOON, 0.04 * pulse))
	for f in _flakes:
		# Dust hanging in the air, barely drifting, brighter where the moonlight catches it.
		var y: float = fmod(f.y + _time * f.speed * 0.15, size_px.y)
		var x: float = fmod(f.x + sin(_time * 0.3 + f.phase) * f.sway + size_px.x, size_px.x)
		var lit := 0.0
		for s in _shafts:
			var along: float = s.x + slant * y / size_px.y
			if x > along and x < along + s.w:
				lit = 1.0
		draw_circle(Vector2(x, y), lerpf(0.4, 0.8, f.depth), Color(COLOR_MOON, lerpf(0.08, 0.2, f.depth) + 0.35 * lit))


func _draw_storm() -> void:
	if style == "rain":
		# Rain slanting in the wind, near drops longer and brighter.
		var slant := Vector2(0.28, 1.0).normalized()
		for r in _rain:
			var fall: float = r.speed * lerpf(0.7, 1.15, r.depth)
			var y: float = fmod(r.y + _time * fall, size_px.y + 20.0) - 10.0
			var x: float = fmod(r.x + (y + 10.0) * 0.28 + size_px.x * 4.0, size_px.x)
			var tail: Vector2 = slant * r.len * lerpf(0.6, 1.2, r.depth)
			draw_line(Vector2(x, y), Vector2(x, y) - tail, Color(COLOR_RAIN, lerpf(0.15, 0.4, r.depth)), 1.0)
		for sp in _splashes:
			var t: float = 1.0 - sp.life / 0.25
			var p: Vector2 = sp.pos
			draw_line(p, p + Vector2(-2.0 - 2.0 * t, -2.0 - t), Color(COLOR_RAIN, 0.5 * (1.0 - t)), 1.0)
			draw_line(p, p + Vector2(2.0 + 2.0 * t, -2.0 - t), Color(COLOR_RAIN, 0.5 * (1.0 - t)), 1.0)
		if _flash > 0.0:
			# Lightning: the whole room lit white for a moment, flickering.
			var flicker := 1.0 if _flash > 0.75 or (_flash > 0.4 and _flash < 0.55) else 0.45
			var strength := 0.06 if Game.reduce_flashes else 0.28
			draw_rect(Rect2(Vector2.ZERO, size_px), Color(COLOR_FLASH, strength * _flash * (1.0 if Game.reduce_flashes else flicker)))
		return
	# Under the rock: static drifting and flickering.
	for f in _flakes:
		var y: float = fmod(f.y - _time * f.speed + size_px.y * 4.0, size_px.y)
		var x: float = f.x + sin(_time * 0.5 + f.phase) * f.sway
		var alpha := 0.2 + 0.6 * maxf(0.0, sin(_time * 3.1 + f.phase * 3.0))
		draw_rect(Rect2(x, y, 1, 1), Color(COLOR_SPARK, alpha * lerpf(0.4, 1.0, f.depth)))
	for d in _drips:
		# A drop swelling under the rock, falling, and swelling again.
		var t: float = fmod(d.t, d.every)
		var swell := clampf(t / (d.every - 0.6), 0.0, 1.0)
		var x: float = d.x
		var y0: float = d.y
		if t < d.every - 0.6:
			draw_circle(Vector2(x, y0 + 1.0 + swell), 0.6 + swell, Color(COLOR_RAIN, 0.6))
		else:
			var fall: float = (t - (d.every - 0.6)) * 260.0
			draw_line(Vector2(x, y0 + fall), Vector2(x, y0 + fall - 4.0), Color(COLOR_RAIN, 0.6), 1.0)
	for arc in _arcs:
		# A jagged arc of lightning jumping across the rock.
		var rng := RandomNumberGenerator.new()
		rng.seed = arc.seed + int(_time * 30.0)
		var pts := PackedVector2Array()
		var from: Vector2 = arc.from
		var to: Vector2 = arc.to
		for i in 7:
			var t := i / 6.0
			var off := Vector2.ZERO if i == 0 or i == 6 else Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
			pts.append(from.lerp(to, t) + off)
		draw_polyline(pts, Color(COLOR_SPARK, 0.5), 3.0)
		draw_polyline(pts, COLOR_ARC, 1.0)


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
