extends Node2D
## Builds one room from its ASCII layout in rooms.gd: collision, hazards, doors,
## enemies and pickups. Also draws the placeholder tiles.

signal door_entered(door: String)

const Rooms := preload("res://scripts/rooms.gd")
const Crawler := preload("res://scripts/crawler.gd")
const Shard := preload("res://scripts/shard.gd")
const Anchor := preload("res://scripts/anchor.gd")

const PIECE_ABILITIES := {"I": "dash", "F": "double_jump", "L": "shockline"}

const TILE := Rooms.TILE
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_HAZARD := 8

const COLOR_BG := Color("0f1119")
const COLOR_PILLAR := Color("131622")
const COLOR_STONE := Color("262a36")
const COLOR_STONE_TOP := Color("3d4354")
const COLOR_SPIKE := Color("9aa0ad")

var room_name := ""
var size_tiles := Vector2i.ZERO
var size_px := Vector2.ZERO
var spawn_point := Vector2.ZERO

var _grid: PackedStringArray
## Door letter -> Rect2i of the door's cells.
var _doors := {}


func build(name_: String) -> void:
	room_name = name_
	_grid = PackedStringArray(Rooms.LAYOUTS[name_])
	size_tiles = Vector2i(_grid[0].length(), _grid.size())
	size_px = Vector2(size_tiles) * TILE
	for y in _grid.size():
		assert(_grid[y].length() == size_tiles.x, "%s row %d has the wrong width" % [name_, y])
	_build_solids()
	_scan_cells()
	_build_doors()


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


func _cell(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= size_tiles.x or y >= size_tiles.y:
		return "#"
	return _grid[y][x]


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
					crawler.position = feet
					add_child(crawler)
				"I", "F", "L":
					var ability: String = PIECE_ABILITIES[c]
					if not Game.has_ability(ability):
						var shard := Shard.new()
						shard.ability = ability
						shard.position = Vector2((x + 0.5) * TILE, (y + 0.5) * TILE)
						add_child(shard)
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
		area.body_entered.connect(func(_body: Node2D) -> void: door_entered.emit(letter))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size_px), COLOR_BG)
	# Faint pillars in the background for a sense of ruined architecture.
	for i in range(3, size_tiles.x, 9):
		draw_rect(Rect2(i * TILE, 0, TILE * 2, size_px.y), COLOR_PILLAR)

	for y in size_tiles.y:
		for x in size_tiles.x:
			var c := _cell(x, y)
			var pos := Vector2(x, y) * TILE
			if c == "#":
				draw_rect(Rect2(pos, Vector2(TILE, TILE)), COLOR_STONE)
				if _cell(x, y - 1) != "#":
					draw_rect(Rect2(pos, Vector2(TILE, 2)), COLOR_STONE_TOP)
			elif c == "^":
				for i in 3:
					var bx := pos.x + 1 + i * 5
					draw_colored_polygon(PackedVector2Array([
						Vector2(bx, pos.y + TILE), Vector2(bx + 2.5, pos.y + 5), Vector2(bx + 5, pos.y + TILE),
					]), COLOR_SPIKE)
