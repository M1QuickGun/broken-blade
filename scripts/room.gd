extends Node2D
## Builds one room from its ASCII layout in rooms.gd: collision, hazards, doors,
## enemies and pickups. Also draws the placeholder tiles.

signal door_entered(door: String)
signal sign_read(text: String)
signal boss_defeated(title: String)

const Rooms := preload("res://scripts/rooms.gd")
const Crawler := preload("res://scripts/crawler.gd")
const Shard := preload("res://scripts/shard.gd")
const Anchor := preload("res://scripts/anchor.gd")
const Shrine := preload("res://scripts/shrine.gd")
const MaskShard := preload("res://scripts/mask_shard.gd")
const Sign := preload("res://scripts/sign.gd")
const Boss := preload("res://scripts/boss.gd")
const Centipede := preload("res://scripts/centipede.gd")

const PIECE_ABILITIES := {"I": "dash", "F": "double_jump", "L": "shockline", "W": "wall_jump"}

const TILE := Rooms.TILE
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_HAZARD := 8

const COLOR_BG := Color("0f1119")
const COLOR_PILLAR := Color("131622")
const COLOR_BG_ICE := Color("0c1320")
const COLOR_PILLAR_ICE := Color("111c2c")
const COLOR_GATE := Color("3a3f4f")
const COLOR_GATE_LIGHT := Color("6a7186")
const COLOR_ICE_GATE := Color(0.62, 0.86, 1.0, 0.78)
const COLOR_DIRT := Color("2a2a22")
const COLOR_BG_CAVE := Color("0b0d0c")

## Ruined stone, a 4x4 sheet of 32 px corner tiles (2x detail, 16 world px each).
## Tiles are drawn on the dual grid: one per cell corner, picked by which of the four
## cells around that corner are solid.
const STONE_SHEET := preload("res://art/world/ruins_tileset.png")
## The Frozen village's frosted bricks; same corner layout as STONE_SHEET.
const ICE_SHEET := preload("res://art/world/ice_tileset.png")
## A spike trap seen from the side, drawn at 2x detail over one tile.
const SPIKE_TEX := preload("res://art/world/spikes.png")
## The Foothills forest floor: earth, roots and moss; same corner layout as STONE_SHEET.
const FOREST_SHEET := preload("res://art/world/forest_tileset.png")
const Atmosphere := preload("res://scripts/atmosphere.gd")
const ICE_GATE_TEX := preload("res://art/world/frozen_gate.png")
## The part of the gate's art that isn't empty margin, so it can fill its doorway exactly.
const ICE_GATE_ART := Rect2(0, 8, 64, 169)
const SHEET_TILE := 32
## How many rows of rock are drawn above a room that has a ceiling.
const ROOF_ROWS := 6
## Solid-corner mask (NW 8, NE 4, SW 2, SE 1) -> tile in the sheet.
const STONE_TILES := {
	0: Vector2i(0, 3), 1: Vector2i(1, 3), 2: Vector2i(0, 0), 3: Vector2i(3, 0),
	4: Vector2i(0, 2), 5: Vector2i(1, 0), 6: Vector2i(2, 3), 7: Vector2i(1, 1),
	8: Vector2i(3, 3), 9: Vector2i(0, 1), 10: Vector2i(3, 2), 11: Vector2i(2, 0),
	12: Vector2i(1, 2), 13: Vector2i(2, 2), 14: Vector2i(3, 1), 15: Vector2i(2, 1),
}

var room_name := ""
var size_tiles := Vector2i.ZERO
var size_px := Vector2.ZERO
var spawn_point := Vector2.ZERO
## A room with a ceiling has this much more solid rock drawn above it (and the camera may
## look up into it), so a jump never shows where the roof ends. 0 for rooms open to the sky.
var roof_px := 0.0

var _grid: PackedStringArray
## Door letter -> Rect2i of the door's cells.
var _doors := {}
## While the room's boss is alive its doors are barred shut.
var _locked := false
var _gate: StaticBody2D
var _boss_spawn := Vector2.ZERO
var _sign_count := 0
var _ice := false
var _forest := false
## Trees and light behind and in front of the tiles (forest and overgrown rooms).
var _woods := false
var _cave := false
## The breakable earth lid ("=") and the frozen gate ("G"), while they stand.
var _lid: StaticBody2D
var _backdrop: Node2D
var _ice_gate: StaticBody2D


func build(name_: String) -> void:
	room_name = name_
	_ice = room_name in Rooms.ICE_ROOMS
	_forest = room_name in Rooms.FOREST_ROOMS
	# Ice rooms get their painted backdrop, snow or frost too.
	_woods = _forest or room_name in Rooms.OVERGROWN_ROOMS or _ice
	_cave = room_name in Rooms.CAVE_ROOMS
	_grid = PackedStringArray(Rooms.LAYOUTS[name_])
	# Once the room's boss is beaten, its lid has fallen in and its frozen gate is broken.
	if Rooms.BOSSES.has(room_name) and Game.defeated.has(Rooms.BOSSES[room_name].id):
		for y in _grid.size():
			_grid[y] = _grid[y].replace("=", ".").replace("G", ".")
	size_tiles = Vector2i(_grid[0].length(), _grid.size())
	size_px = Vector2(size_tiles) * TILE
	if "." not in _grid[0].substr(1, size_tiles.x - 2):
		roof_px = ROOF_ROWS * TILE
	for y in _grid.size():
		assert(_grid[y].length() == size_tiles.x, "%s row %d has the wrong width" % [name_, y])
	_backdrop = Node2D.new()
	_backdrop.z_index = -2
	_backdrop.draw.connect(_draw_backdrop)
	add_child(_backdrop)
	_build_solids()
	_scan_cells()
	_build_doors()
	_setup_boss()
	_add_props()
	if _woods:
		for is_front in [false, true]:
			var woods := Atmosphere.new()
			woods.style = _atmosphere_style()
			woods.front = is_front
			woods.size_px = size_px
			woods.solid = _grid
			woods.seed_text = room_name
			if _ice:
				# The cave painting is bright: dimmed and cooled more, to sit behind the ice.
				woods.backdrop_tint = Color(0.66, 0.7, 0.76) if woods.style == "snow" else Color(0.42, 0.5, 0.58)
			elif not _forest:
				woods.backdrop_tint = Color(0.4, 0.43, 0.42)  # glimpsed through ruined walls
			add_child(woods)


## Feet position for a player arriving through the given door.
func door_spawn(door: String) -> Vector2:
	var r: Rect2i = _doors[door]
	var center_x := (r.position.x + r.size.x / 2.0) * TILE
	if r.position.x == 0:
		return Vector2(2 * TILE, r.end.y * TILE)
	if r.end.x == size_tiles.x:
		return Vector2((size_tiles.x - 2) * TILE, r.end.y * TILE)
	if r.position.y == 0:
		return Vector2(center_x, 3 * TILE)
	return Vector2(center_x, (size_tiles.y - 2) * TILE)


## Past the edge, a room carries on as its edge does: walled rooms stay walled, and rooms
## open to the sky (or to a drop) stay open instead of growing a rim of tiles.
func _cell(x: int, y: int) -> String:
	return _grid[clampi(y, 0, size_tiles.y - 1)][clampi(x, 0, size_tiles.x - 1)]


## Cells drawn as solid earth. The frozen gate counts too, so the rock is whole behind it and
## the gate fills its doorway edge to edge.
func _earth(x: int, y: int) -> bool:
	var c := _cell(x, y)
	return c == "#" or c == "=" or c == "G"


## Merges solid cells into as few rectangles as possible, so the player
## doesn't snag on seams between tiles.
func _build_solids() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	var used := {}
	for y in size_tiles.y:
		for x in size_tiles.x:
			if _cell(x, y) != "#" or used.has(Vector2i(x, y)):
				continue
			var w := 1
			while x + w < size_tiles.x and _cell(x + w, y) == "#" and not used.has(Vector2i(x + w, y)):
				w += 1
			var h := 1
			while y + h < size_tiles.y and _row_solid(x, w, y + h, used):
				h += 1
			for yy in range(y, y + h):
				for xx in range(x, x + w):
					used[Vector2i(xx, yy)] = true
			_add_rect(body, Rect2(x * TILE, y * TILE, w * TILE, h * TILE))
	# Unseen walls just past the room's edges, for rooms open to the sky or the drop.
	_add_rect(body, Rect2(-TILE * 2, -TILE * 4, size_px.x + TILE * 4, TILE * 2))
	_add_rect(body, Rect2(-TILE * 2, -TILE * 4, TILE * 2, size_px.y + TILE * 4))
	_add_rect(body, Rect2(size_px.x, -TILE * 4, TILE * 2, size_px.y + TILE * 4))
	_lid = _cells_body("=")
	_ice_gate = _cells_body("G")


## Scenery from Rooms.PROPS, on one layer behind Storm (and in front of the backdrop).
func _add_props() -> void:
	var list: Array = Rooms.PROPS.get(room_name, [])
	if list.is_empty():
		return
	var layer := Node2D.new()
	layer.z_index = -1
	layer.draw.connect(func() -> void:
		for prop: Array in list:
			var tex: Texture2D = load("res://art/world/props/%s.png" % prop[0])
			var size := Vector2(tex.get_size()) / 2.0
			var foot := Vector2((prop[1] + 0.5) * TILE, prop[2] * TILE)
			layer.draw_texture_rect(tex, Rect2(foot - Vector2(size.x / 2.0, size.y), size), false))
	add_child(layer)


## Forest in the Foothills; in the ice, the snowy village wherever the room is open to the
## sky, the frozen cavern wherever it has a roof.
func _atmosphere_style() -> String:
	if not _ice:
		return "forest"
	return "snow" if roof_px == 0.0 else "cave"


## A separate solid body for every cell of one kind, so it can be taken away whole.
func _cells_body(kind: String) -> StaticBody2D:
	var body: StaticBody2D = null
	for y in size_tiles.y:
		for x in size_tiles.x:
			if _cell(x, y) != kind:
				continue
			if body == null:
				body = StaticBody2D.new()
				body.collision_layer = LAYER_WORLD
				body.collision_mask = 0
				add_child(body)
			_add_rect(body, Rect2(x * TILE, y * TILE, TILE, TILE))
	return body


## The earth lid gives way (the centipede bursting up under Storm's feet).
func break_lid() -> void:
	_clear_cells("=", COLOR_DIRT)
	if _lid:
		_lid.queue_free()
		_lid = null


## The frozen gate shatters.
func shatter_gate() -> void:
	_clear_cells("G", COLOR_ICE_GATE)
	if _ice_gate:
		_ice_gate.queue_free()
		_ice_gate = null


func _clear_cells(kind: String, debris_color: Color) -> void:
	var count := 0
	for row in _grid:
		count += row.count(kind)
	# A big cave-in throws up a share of its cells as chunks, not every one.
	var share := minf(1.0, 60.0 / maxf(1.0, count))
	for y in _grid.size():
		if kind not in _grid[y]:
			continue
		for x in _grid[y].length():
			if _grid[y][x] == kind and randf() < share:
				_spawn_debris(Vector2((x + 0.5) * TILE, (y + 0.5) * TILE), debris_color)
		_grid[y] = _grid[y].replace(kind, ".")
	queue_redraw()


func _spawn_debris(at: Vector2, color: Color) -> void:
	for i in 3:
		var chunk := Debris.new()
		chunk.position = at + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		chunk.velocity = Vector2(randf_range(-60, 60), randf_range(-160, -20))
		chunk.color = color
		add_child(chunk)


## A chunk of earth or ice flying loose, falling and fading.
class Debris extends Node2D:
	var velocity := Vector2.ZERO
	var color := Color.WHITE
	var life := 1.2

	func _process(delta: float) -> void:
		velocity.y += 500.0 * delta
		position += velocity * delta
		life -= delta
		if life <= 0.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-2, -2, 4, 3), Color(color, clampf(life, 0.0, 1.0)))


func _row_solid(x: int, w: int, y: int, used: Dictionary) -> bool:
	for xx in range(x, x + w):
		if _cell(xx, y) != "#" or used.has(Vector2i(xx, y)):
			return false
	return true


func _add_rect(owner_: CollisionObject2D, rect: Rect2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = rect.get_center()
	owner_.add_child(col)


func _scan_cells() -> void:
	var hazards := Area2D.new()
	hazards.collision_layer = LAYER_HAZARD
	hazards.collision_mask = 0
	hazards.monitoring = false
	hazards.add_to_group("hazard")
	add_child(hazards)

	for y in size_tiles.y:
		for x in size_tiles.x:
			var c := _cell(x, y)
			var feet := Vector2((x + 0.5) * TILE, (y + 1) * TILE)
			match c:
				"P":
					spawn_point = feet
				"E":
					var crawler := Crawler.new()
					crawler.frost = _ice
					crawler.position = feet
					add_child(crawler)
				"I", "F", "L", "W":
					var ability: String = PIECE_ABILITIES[c]
					if not Game.has_ability(ability):
						var shard := Shard.new()
						shard.ability = ability
						shard.position = Vector2((x + 0.5) * TILE, (y + 0.5) * TILE)
						add_child(shard)
				"R":
					var shrine := Shrine.new()
					shrine.room_name = room_name
					shrine.position = feet
					add_child(shrine)
				"H":
					_add_mask_shard("%s:%d,%d" % [room_name, x, y], Vector2((x + 0.5) * TILE, (y + 0.5) * TILE))
				"B":
					_boss_spawn = feet
				"?":
					var post := Sign.new()
					var texts: Array = Rooms.SIGNS.get(room_name, [])
					post.text = texts[_sign_count] if _sign_count < texts.size() else ""
					_sign_count += 1
					post.position = feet
					post.read.connect(func(text: String) -> void: sign_read.emit(text))
					add_child(post)
				"*":
					var anchor := Anchor.new()
					anchor.position = Vector2((x + 0.5) * TILE, (y + 0.5) * TILE)
					add_child(anchor)
				"^":
					# Only the lower part of the tile hurts, so brushing the tips is forgiven.
					_add_rect(hazards, Rect2(x * TILE + 2, y * TILE + 6, TILE - 4, TILE - 6))
				_:
					if c >= "a" and c <= "z":
						var cell := Rect2i(x, y, 1, 1)
						_doors[c] = _doors[c].merge(cell) if _doors.has(c) else cell


func _build_doors() -> void:
	for letter in _doors:
		var r: Rect2i = _doors[letter]
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = LAYER_PLAYER
		add_child(area)
		_add_rect(area, Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE))
		area.body_entered.connect(_on_door_body_entered.bind(letter))


func _on_door_body_entered(_body: Node2D, letter: String) -> void:
	if not _locked:
		door_entered.emit(letter)


func _add_mask_shard(id: String, pos: Vector2) -> void:
	if Game.collected.has(id):
		return
	var mask := MaskShard.new()
	mask.id = id
	mask.position = pos
	add_child(mask)


## Spawns what a boss drops: a blade piece or a mask shard (unless already taken).
func _add_reward(letter: String, pos: Vector2) -> void:
	if letter == "H":
		_add_mask_shard("%s:boss" % room_name, pos)
	elif PIECE_ABILITIES.has(letter) and not Game.has_ability(PIECE_ABILITIES[letter]):
		var shard := Shard.new()
		shard.ability = PIECE_ABILITIES[letter]
		shard.position = pos
		add_child(shard)


func _setup_boss() -> void:
	if not Rooms.BOSSES.has(room_name):
		return
	var info: Dictionary = Rooms.BOSSES[room_name]
	var reward_pos := _boss_spawn + Vector2(0, -TILE)
	if Game.defeated.has(info.id):
		# Beaten already; its reward waits where it fell if it wasn't picked up.
		if info.has("reward"):
			_add_reward(info.reward, reward_pos)
		return
	var boss: Node2D = Centipede.new() if info.kind == "centipede" else Boss.new()
	boss.boss_id = info.id
	boss.kind = info.kind
	boss.phase = info.phase
	boss.title = info.title
	boss.max_hp = info.hp
	boss.position = _boss_spawn
	add_child(boss)
	boss.defeated.connect(func() -> void: _on_boss_defeated(info, boss.global_position))
	if boss.has_signal("engaged"):
		boss.engaged.connect(_lock_doors)  # it lies in wait: the doors bar only once it wakes
	else:
		_lock_doors()


## Bars every door until the boss falls.
func _lock_doors() -> void:
	_locked = true
	_gate = StaticBody2D.new()
	_gate.collision_layer = LAYER_WORLD
	_gate.collision_mask = 0
	add_child(_gate)
	for letter in _doors:
		var r: Rect2i = _doors[letter]
		_add_rect(_gate, Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE))
	queue_redraw()


func _on_boss_defeated(info: Dictionary, where: Vector2) -> void:
	_locked = false
	if _gate:
		_gate.queue_free()
		_gate = null
	queue_redraw()
	if info.has("reward"):
		_add_reward(info.reward, Vector2(where.x, _boss_spawn.y - TILE))
	boss_defeated.emit(info.title)


## The plain background, on its own layer well behind the tiles (and behind anything that
## hides in the rock, like the burrowing centipede).
func _draw_backdrop() -> void:
	if _cave:
		_backdrop.draw_rect(Rect2(Vector2.ZERO, size_px), COLOR_BG_CAVE)
	elif not _woods:
		_backdrop.draw_rect(Rect2(Vector2.ZERO, size_px), COLOR_BG_ICE if _ice else COLOR_BG)
		# Faint pillars in the background for a sense of ruined architecture.
		for i in range(3, size_tiles.x, 9):
			_backdrop.draw_rect(Rect2(i * TILE, 0, TILE * 2, size_px.y), COLOR_PILLAR_ICE if _ice else COLOR_PILLAR)


func _draw() -> void:
	var sheet: Texture2D = ICE_SHEET if _ice else (FOREST_SHEET if _forest or _cave else STONE_SHEET)

	for vy in range(-int(roof_px / TILE), size_tiles.y + 1):
		for vx in size_tiles.x + 1:
			var mask := int(_earth(vx - 1, vy - 1)) * 8 + int(_earth(vx, vy - 1)) * 4 \
				+ int(_earth(vx - 1, vy)) * 2 + int(_earth(vx, vy))
			if mask == 0:
				continue
			var src := Rect2(Vector2(STONE_TILES[mask]) * SHEET_TILE, Vector2(SHEET_TILE, SHEET_TILE))
			var dst := Rect2(Vector2(vx - 0.5, vy - 0.5) * TILE, Vector2(TILE, TILE))
			draw_texture_rect_region(sheet, dst, src)

	for y in size_tiles.y:
		for x in size_tiles.x:
			var c := _cell(x, y)
			var pos := Vector2(x, y) * TILE
			if _locked and c >= "a" and c <= "z":
				# Iron bars across the door.
				draw_rect(Rect2(pos, Vector2(TILE, TILE)), COLOR_GATE)
				for i in 3:
					draw_rect(Rect2(pos + Vector2(2 + i * 5, 0), Vector2(2, TILE)), COLOR_GATE_LIGHT)
			if c == "^":
				draw_texture_rect(SPIKE_TEX, Rect2(pos, Vector2(TILE, TILE)), false)
			elif c == "G" and _cell(x - 1, y) != "G" and _cell(x, y - 1) != "G":
				_draw_ice_gate(x, y)


## The frozen gate (art/world/frozen_gate.png) stretched over its block of G cells, drawn
## from the block's top-left cell.
func _draw_ice_gate(x0: int, y0: int) -> void:
	var w := 0
	while _cell(x0 + w, y0) == "G" and x0 + w < size_tiles.x:
		w += 1
	var h := 0
	while _cell(x0, y0 + h) == "G" and y0 + h < size_tiles.y:
		h += 1
	draw_texture_rect_region(ICE_GATE_TEX, Rect2(Vector2(x0, y0) * TILE, Vector2(w, h) * TILE), ICE_GATE_ART)
