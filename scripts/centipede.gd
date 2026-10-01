extends Node2D
## The Guardian Centipede, the Foothills' boss, fought twice. It lives in the earth: it moves
## underground and through the rock, and everywhere it's about to come out, the ground
## rumbles first. Its attacks come in a fixed order, each one announced, so a player can learn
## the pattern: it's the first boss, so its moves are easy to read and dodge.
##
## Phase 1, the ring: it lies under the stone ring with the hilt driven into its tail, only the
## pommel showing above the earth. Pulling at the hilt breaks the ground and drops Storm into
## the pit with it. Its pattern:
## - Breach: a rumble tracks Storm under the floor, stops and swells, then the centipede bursts
##   up in an arc toward him and dives back in. Step away from the rumble.
## - Stuck breach: the same, but it dives headfirst into the ground and sticks: free hits.
## - Floor crawl: a wall rumbles low down; it bursts out and crawls across two thirds of the
##   floor, then stops, winded (more free hits), and burrows. The far third is safe.
## Beaten, it shrieks, the hilt tears loose from its tail and floats to the middle of the pit,
## and the centipede burrows away and flees, seemingly for good. The hilt is the wall jump.
##
## Phase 2, the gate cavern: risen, bigger and armored. It bursts up out of the floor behind
## Storm and climbs to the ceiling, its body sealing off the way back; then it comes down
## through the ceiling in front of the frozen gate, sealing that too. Those two living coils
## trap Storm between them (walls he can cling to). It adds a ceiling
## drop, where dust trickles from the spot it'll fall on. At half health the coils close in, it
## moves faster, and hatchlings drop in. Beaten, its coils crumble apart; the ground rumbles
## one last time by the frozen gate, and it bursts out and smashes into the gate, blowing it
## open, then collapses and sinks away.
##
## The node's origin is the room's B marker, the middle of the arena's floor. The body follows
## the head's path like a train, so wherever the head went (into the earth, up a coil, along
## the ceiling), the body goes too.

signal defeated
## Sent when it wakes: the room bars its doors then.
signal engaged

const Projectile := preload("res://scripts/projectile.gd")
const Crawler := preload("res://scripts/crawler.gd")
const Shard := preload("res://scripts/shard.gd")
const HEAD_TEX := preload("res://art/enemies/centipede_head.png")
const SEG_TEX := preload("res://art/enemies/centipede_segment.png")
## Risen, its plates have grown spined and heavy.
const SEG_TEX_ARMORED := preload("res://art/enemies/centipede_segment_armored.png")
const HILT_TEX := preload("res://art/blade/blade_0_hilt.png")

const TILE := 16
const LAYER_ENEMY := 4
## How far under the floor (or past a wall's face) it travels while hidden.
const DEPTH := 26.0
const COLOR_DIRT := Color("3b352b")
const COLOR_DIRT_LIGHT := Color("5e5443")

enum St {
	DORMANT, EMERGE, TUNNEL, RUMBLE, FLEE, BREACH, STUCK, SUBMERGE, TO_WALL, WALL_RUMBLE, LUNGE,
	TO_CEILING, DUST, DROP, DYING, LAST_RUMBLE, CHARGE_GATE, GONE,
	COIL_UP, COIL_ACROSS, COIL_DOWN,
}

## The attack order, looped.
## The opening breach is the first move. No two arcs ever come back to back.
const PATTERN_1 := ["breach", "wall", "breach_stuck", "wall"]
const PATTERN_2 := ["breach", "drop", "wall", "breach_stuck", "drop", "wall"]
## Only the head and the front of the body hurt to touch; the rest of an arc or a coil of
## body is safe to pass, so Storm can never be boxed in by it.
const HARMFUL_SEGMENTS := 6

## Set by the room before it's added (see Rooms.BOSSES).
var boss_id := ""
var kind := "centipede"
var phase := 1
var title := ""
var max_hp := 12

var hp := 0

var _state := St.DORMANT
var _timer := 0.0
var _time := 0.0
var _flash := 0.0
var _scale := 0.5
var _spacing := 10.0
var _seg_tex: Texture2D = SEG_TEX
var _segs: Array[Vector2] = []
var _trail: Array[Vector2] = []
var _path: Array[Vector2] = []
var _head := Vector2.ZERO
var _head_dir := Vector2.RIGHT
var _move := 0
var _attack := ""
## Where the next attack comes out, and which way it goes.
var _spot := Vector2.ZERO
var _dir := 1
## A breach: its arc's start, width, height, and how far along it is (0 to 1).
var _arc_from := Vector2.ZERO
var _arc_width := 120.0
var _arc_height := 64.0
var _arc_t := 0.0
var _arc_stuck := false
var _arc_reach := 120.0
var _rumble_puff := 0.0
var _shake := 0.0
var _cam_base := Vector2.ZERO
var _near_hilt := false
## The hilt flying free when phase 1 ends: from where, and how far along (0 to 1).
var _hilt_from := Vector2.ZERO
var _hilt_t := -1.0
var _head_box: Hitbox
var _body_boxes: Array[Hitbox] = []

# The arena, in the room's coordinates.
var _left := 0.0
var _right := 0.0
var _floor := 0.0
var _top := 0.0
var _lid_y := 0.0

# Phase 2's living coils: x of each coil's inner face, how far they've risen (0 to 1), and
# the solid bodies Storm clings to.
var _walls: Node2D
var _wall_bodies: Array[StaticBody2D] = []
var _wall_x := [0.0, 0.0]
## Each coil's top and bottom (y). Formed by the centipede's own body during its entrance.
var _coil_top := [0.0, 0.0]
var _coil_bottom := [0.0, 0.0]
var _enraged := false
var _hatch_timer := 4.0
## Where the frozen gate stands (its left face), and pieces of coil falling as they crumble:
## {pos, vel, rot, spin, coil}.
var _gate_x := 0.0
var _falling: Array[Dictionary] = []
var _crumble := 0.0


func _ready() -> void:
	hp = max_hp
	z_index = -1  # behind the tiles, so whatever is in the earth is hidden by it
	if phase >= 2:
		_scale = 0.7
		_spacing = 14.0
		_seg_tex = SEG_TEX_ARMORED
		_arc_width = 150.0
		_arc_height = 80.0
	_measure_arena()
	var count := 22 if phase == 1 else 26
	_head = Vector2(position.x, _floor + DEPTH * 3)
	for i in count:
		_segs.append(_head)
	_head_box = _make_box(Vector2(22, 16) * _scale / 0.5, true)
	for i in range(1, count, 2):
		_body_boxes.append(_make_box(Vector2(14, 12) * _scale / 0.5, false))
	_set_boxes_active(false)
	if phase >= 2:
		_walls = Node2D.new()
		_walls.z_index = 1  # in front of the tiles: the coils stand in the room
		_walls.draw.connect(_draw_walls)
		add_child(_walls)


func _measure_arena() -> void:
	var room := get_parent()
	var cx := int(position.x / TILE)
	var cy := int(position.y / TILE) - 1
	var x := cx
	while x > 0 and not _solid(room, x - 1, cy):
		x -= 1
	_left = x * TILE
	x = cx
	while x < room.size_tiles.x - 1 and not _solid(room, x + 1, cy):
		x += 1
	_right = (x + 1) * TILE
	_floor = position.y
	var y := cy
	if phase == 1:
		# The pit is still solid earth (=) under the ring until it caves in: its top is the
		# ring's ground, where the earth begins.
		while y > 0 and room._cell(cx, y - 1) == "=":
			y -= 1
		_top = y * TILE
		_lid_y = _top
	else:
		while y > 0 and not _solid(room, cx, y - 1):
			y -= 1
		_top = y * TILE
		_lid_y = (y - 1) * TILE
	if phase >= 2:
		# The coils rise a little inside the cavern: one behind Storm, one before the gate.
		_wall_x = [6.0 * TILE + 32.0, 32.0 * TILE]
		_left = _wall_x[0]
		_right = _wall_x[1]
		_gate_x = room.size_px.x
		for gy in room.size_tiles.y:
			for gx in room.size_tiles.x:
				if room._cell(gx, gy) == "G":
					_gate_x = minf(_gate_x, gx * TILE)


## Rock for measuring the arena (the earth that caves in, =, is part of the pit).
func _solid(room: Node, x: int, y: int) -> bool:
	var c: String = room._cell(x, y)
	return c == "#" or c == "G"


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


# --- Hitboxes: the head takes hits; the body only hurts to touch (and can be pogoed on) ---

class Hitbox extends Area2D:
	var boss: Node
	var is_head := false

	func take_hit(damage: int, from_dir: Vector2) -> void:
		if is_head:
			boss.take_hit(damage, from_dir)


func _make_box(size: Vector2, head: bool) -> Hitbox:
	var box := Hitbox.new()
	box.boss = self
	box.is_head = head
	box.collision_layer = 0
	box.collision_mask = 0
	box.monitoring = false
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	box.add_child(col)
	box.top_level = true
	add_child(box)
	return box


func _set_boxes_active(on: bool) -> void:
	for box in [_head_box] + _body_boxes:
		box.collision_layer = LAYER_ENEMY if on else 0


## Only what's out in the open can hit or be hit; what's in the earth is safe.
func _in_open(at: Vector2) -> bool:
	return at.y < _floor + 2.0 and at.y > _top - 2.0 and at.x > _left - 2.0 and at.x < _right + 2.0


func shock_point() -> Vector2:
	return get_parent().to_global(_head)


func take_hit(damage: int, _from_dir: Vector2) -> void:
	if _state in [St.DORMANT, St.EMERGE, St.FLEE, St.DYING, St.LAST_RUMBLE, St.CHARGE_GATE, St.GONE]:
		return
	hp -= damage
	_flash = 0.1
	if phase >= 2 and not _enraged and hp <= max_hp / 2:
		_enraged = true
		_shake = 0.6
	if hp <= 0:
		hp = 0
		remove_from_group("shock_target")
		_set_boxes_active(false)
		if phase == 1:
			_flee()
		else:
			_enter(St.DYING, 1.4)


# --- Behaviour ---

func _physics_process(delta: float) -> void:
	_time += delta
	_flash -= delta
	_timer -= delta
	var player := _player()
	var p := player.position if player else Vector2(position.x, _floor)
	match _state:
		St.DORMANT:
			_update_dormant(p)
		St.EMERGE:
			_update_emerge(delta)
		St.COIL_UP:
			# Up from the floor to the ceiling behind Storm: its body becomes the first coil.
			_shake = maxf(_shake, 0.05)
			var arrived := _steer_to(Vector2(_left - 16.0, _top - DEPTH), 240.0, delta, 4.0)
			_coil_top[0] = clampf(_head.y, _top - TILE, _floor)
			if arrived or _timer <= 0.0:
				_coil_top[0] = _top - TILE
				# Out of sight above, it comes around under the floor before the frozen gate.
				_jump_head(Vector2(_right + 16.0, _floor + DEPTH))
				for i in 6:
					_spray(Vector2(_right + 16.0 + randf_range(-14, 14), _floor), COLOR_DIRT)
				_enter(St.COIL_DOWN, 3.0)
		St.COIL_DOWN:
			# Up out of the floor in front of the gate: the second coil seals the way on.
			_shake = maxf(_shake, 0.05)
			var arrived := _steer_to(Vector2(_right + 16.0, _top - DEPTH), 240.0, delta, 4.0)
			_coil_top[1] = clampf(_head.y, _top - TILE, _floor)
			if arrived or _timer <= 0.0:
				_coil_top[1] = _top - TILE
				_jump_head(Vector2(position.x, _floor + DEPTH))
				_spot = Vector2(position.x, _floor)
				_enter(St.EMERGE, 1.0)
		St.TUNNEL:
			# Underground, following Storm; the floor rumbles over it.
			var tx := clampf(p.x, _left + 24, _right - 24)
			_steer_to(Vector2(tx, _floor + DEPTH), 90.0 * _tempo(), delta, 2.0)
			_rumble(Vector2(_head.x, _floor), 0.16)
			if _timer <= 0.0:
				_spot = Vector2(_head.x, _floor)
				_enter(St.RUMBLE, _warn_time())
		St.RUMBLE:
			# Stopped: the ground swells right where it'll burst out.
			_rumble(_spot, 0.05)
			_shake = maxf(_shake, 0.05)
			if _timer <= 0.0:
				_start_breach(p)
		St.BREACH:
			_update_breach(delta)
		St.STUCK:
			_head += Vector2(randf_range(-0.5, 0.5), 0)
			if _timer <= 0.0:
				_enter(St.SUBMERGE, 1.2)
		St.SUBMERGE:
			if _steer_to(Vector2(_head.x, _floor + DEPTH), 110.0, delta, 3.0) or _timer <= 0.0:
				_next_attack(p)
		St.TO_WALL, St.TO_CEILING:
			# Hidden, along waypoints through the earth (and up inside a coil, in phase 2).
			if _path.is_empty():
				if _state == St.TO_WALL:
					_enter(St.WALL_RUMBLE, _warn_time())
				else:
					_spot = Vector2(_head.x, _top)
					_enter(St.DUST, _warn_time())
			elif _steer_to(_path[0], 260.0 * _tempo(), delta, 5.0):
				_path.pop_front()
		St.WALL_RUMBLE:
			_rumble(_spot, 0.05)
			if _timer <= 0.0:
				var cross := (_right - _left) * 2.0 / 3.0
				_path = [
					Vector2(_spot.x + _dir * 18.0, _floor - 8.0 * _scale / 0.5),
					Vector2(_spot.x + _dir * cross, _floor - 8.0 * _scale / 0.5),
				]
				_enter(St.LUNGE, 4.0)
		St.LUNGE:
			# Out of the wall low down and crawling across the floor, then stopping, winded.
			if fmod(_time, 0.1) < delta:
				_spray(Vector2(_head.x, _floor), COLOR_DIRT)
			if _path.is_empty() or _timer <= 0.0:
				_shake = 0.2
				_enter(St.STUCK, 1.8)
			elif _steer_to(_path[0], 170.0 * _tempo(), delta, 5.0):
				_path.pop_front()
		St.DUST:
			# Hanging in the ceiling over the spot; dust trickles down where it'll fall.
			if fmod(_time, 0.07) < delta:
				_spawn_projectile_dust(Vector2(_spot.x + randf_range(-8, 8), _top + 2))
			if _timer <= 0.0:
				_enter(St.DROP, 1.2)
		St.DROP:
			if _steer_to(Vector2(_spot.x, _floor - 2.0), 420.0 * _tempo(), delta, 4.0) or _timer <= 0.0:
				_shake = 0.3
				_spray(_head, COLOR_DIRT)
				_enter(St.STUCK, 1.8)
		St.FLEE:
			# Down into the earth and away, rumbling off toward the far wall.
			_hilt_t = minf(_hilt_t + delta / 1.2, 1.0)
			if (_path.is_empty() and _hilt_t >= 1.0) or _timer <= 0.0:
				_finish()
			elif not _path.is_empty() and _steer_to(_path[0], 200.0, delta, 6.0):
				_path.pop_front()
			if _head.y > _floor:
				_rumble(Vector2(_head.x, _floor), 0.08)
		St.DYING:
			# It pulls down into the earth and its coils crumble apart, piece by piece.
			_steer_to(Vector2(_head.x, _floor + DEPTH * 2.0), 160.0, delta, 2.0)
			_shake = maxf(_shake, 0.08)
			_crumble_coils(delta)
			if _coil_bottom[0] - _coil_top[0] < 1.0 and _coil_bottom[1] - _coil_top[1] < 1.0:
				_spot = Vector2(_gate_x - 36.0, _floor)
				_jump_head(Vector2(_spot.x, _floor + DEPTH))
				_enter(St.LAST_RUMBLE, 1.3)
		St.LAST_RUMBLE:
			# One last swell of earth, right before the frozen gate.
			_rumble(_spot, 0.04)
			_shake = maxf(_shake, 0.12)
			if _timer <= 0.0:
				for i in 6:
					_spray(_spot + Vector2(randf_range(-12, 12), 0), COLOR_DIRT)
				_path = [Vector2(_spot.x - 6.0, _floor - 54.0), Vector2(_gate_x + 10.0, _floor - 40.0)]
				_enter(St.CHARGE_GATE, 2.0)
		St.CHARGE_GATE:
			# Up out of the ground and headlong into the gate.
			if _path.is_empty() or _timer <= 0.0:
				_shake = 1.0
				get_parent().shatter_gate()
				for i in 10:
					_spray(Vector2(_gate_x + randf_range(0, 32), _floor - randf_range(0, 96)), Color(0.75, 0.9, 1.0))
				_flash = 0.15
				_enter(St.GONE, 2.2)
			elif _steer_to(_path[0], 380.0, delta, 8.0):
				_path.pop_front()
		St.GONE:
			# It falls in the wreck of the gate and sinks away into the earth.
			if _timer > 1.5:
				_steer_to(Vector2(_gate_x - 8.0, _floor - 6.0), 200.0, delta, 2.0)
			else:
				for i in _trail.size():
					_trail[i].y += 30.0 * delta
				_head.y += 30.0 * delta
			if _timer <= 0.0:
				_finish()
	if phase >= 2 and _state != St.DORMANT:
		_update_walls(delta)
		_update_falling(delta)
	_follow_trail()
	_place_boxes()
	_update_shake(delta)
	queue_redraw()


func _tempo() -> float:
	return 1.2 if _enraged else 1.0


## How long a rumble warns before the attack comes out.
func _warn_time() -> float:
	return 0.8 if _enraged else 1.0


func _enter(state: St, time := 0.0) -> void:
	_state = state
	_timer = time


func _update_dormant(p: Vector2) -> void:
	if phase == 1:
		# Pulling at the hilt in the ring wakes what it's stuck in; the ground gives way.
		_near_hilt = absf(p.x - position.x) < 20.0 and absf(p.y - _lid_y) < 8.0
		if _near_hilt and Input.is_action_just_pressed("interact"):
			get_parent().break_lid()
			_shake = 0.6
			_wake()
	elif p.x > 11.0 * TILE:
		_shake = 1.2
		_wake()


func _wake() -> void:
	engaged.emit()
	add_to_group("boss")
	add_to_group("shock_target")
	_head = Vector2(position.x, _floor + DEPTH * 3)
	_trail.clear()
	for k in 200:
		_trail.append(_head + Vector2(0, k * 2.0))
	# (Phase 1 gives Storm time to land: he falls in through the middle of the pit.)
	if phase >= 2:
		# It bursts up out of the floor where the first coil will stand, behind Storm.
		_coil_top = [_floor, _floor]
		_coil_bottom = [_floor, _floor]
		_head = Vector2(_left - 16.0, _floor + DEPTH)
		for i in 6:
			_spray(Vector2(_left - 16.0 + randf_range(-14, 14), _floor), COLOR_DIRT)
		_enter(St.COIL_UP, 3.0)
		return
	_enter(St.EMERGE, 2.0)


## Phase 1: Storm falls into the pit while it stirs below. Phase 2: the coils burst up out of
## the floor. Then it opens with a breach in the middle.
func _update_emerge(_delta: float) -> void:
	_rumble(Vector2(position.x + (100.0 if phase == 1 else 0.0), _floor), 0.1)
	if _timer <= 0.0:
		# The opening breach comes up off to one side, never under Storm's feet.
		_spot = Vector2(position.x + (100.0 if phase == 1 else 0.0), _floor)
		_head = Vector2(_spot.x, _floor + DEPTH)
		_attack = "breach"
		_move = 1
		var pl := _player()
		_start_breach(pl.position if pl else Vector2(position.x, _floor))


func _next_attack(p: Vector2) -> void:
	var pattern: Array = PATTERN_1 if phase == 1 else PATTERN_2
	_attack = pattern[_move % pattern.size()]
	_move += 1
	match _attack:
		"breach", "breach_stuck":
			_enter(St.TUNNEL, 1.3)
		"wall":
			# Through the earth to the wall farther from Storm, then up inside it to knee height.
			_dir = 1 if p.x > position.x else -1
			var inside := (_left - DEPTH) if _dir > 0 else (_right + DEPTH)
			var face := _left if _dir > 0 else _right
			_spot = Vector2(face, _floor - 8.0 * _scale / 0.5)
			_path = [Vector2(inside, _floor + DEPTH), Vector2(inside, _spot.y)]
			_enter(St.TO_WALL)
		"drop":
			# Out of sight in the ceiling over Storm (the coils already look like it's forever
			# climbing; no need to watch it go up).
			_jump_head(Vector2(clampf(p.x, _left + 24, _right - 24), _top - DEPTH))
			_path.clear()
			_enter(St.TO_CEILING)


# --- Breach: up out of the ground in an arc, and back down ---

func _start_breach(p: Vector2) -> void:
	_arc_stuck = _attack == "breach_stuck"
	# Arc toward Storm (toward the middle if he's right on the spot), shortened to fit if a
	# wall is close; only if there's no room at all that way does it turn around.
	var dx := p.x - _spot.x
	_dir = (1 if dx > 0.0 else -1) if absf(dx) > 6.0 else (1 if _spot.x < position.x else -1)
	var room := (_right - 16.0 - _spot.x) if _dir > 0 else (_spot.x - _left - 16.0)
	if room < 48.0:
		_dir = -_dir
		room = (_right - 16.0 - _spot.x) if _dir > 0 else (_spot.x - _left - 16.0)
	_arc_reach = clampf(room, 40.0, _arc_width * (0.7 if _arc_stuck else 1.0))
	_arc_from = Vector2(_spot.x, _floor + DEPTH)
	_head = _arc_from
	_arc_t = 0.0
	_shake = 0.3
	for i in 4:
		_spray(_spot, COLOR_DIRT)
	_enter(St.BREACH, 3.0)


func _update_breach(delta: float) -> void:
	var width := _arc_reach
	_arc_t = minf(_arc_t + delta / (1.2 / _tempo()), 1.0)
	var t := _arc_t
	var x := _arc_from.x + _dir * width * t
	var rise := (_arc_height + DEPTH) * 4.0 * t * (1.0 - t)
	var y := _arc_from.y - rise
	if _arc_stuck:
		# Instead of diving back under, it drives its head into the ground and sticks.
		y -= (DEPTH + 2.0) * t
	_head = Vector2(x, y)
	if _arc_t >= 1.0:
		if _arc_stuck:
			_shake = 0.3
			_spray(_head, COLOR_DIRT)
			_enter(St.STUCK, 2.2)
		else:
			_spray(Vector2(_head.x, _floor), COLOR_DIRT)
			_enter(St.SUBMERGE, 0.6)


# --- Movement helpers ---

## Moves the head (and the body behind it) somewhere out of sight at once: the whole body is
## laid in a straight line behind it, hidden in the rock above or the earth below.
func _jump_head(to: Vector2) -> void:
	_head = to
	var back := Vector2(0, -2) if to.y < _floor else Vector2(0, 2)
	_trail.clear()
	for k in int(_segs.size() * _spacing / 2.0) + 30:
		_trail.append(to + back * k)


## Moves the head toward a point, turning like a snake. True once it's there.
func _steer_to(to: Vector2, speed: float, delta: float, arrive := 4.0) -> bool:
	var want := _head.direction_to(to)
	var step := minf(speed * delta, _head.distance_to(to))
	_head += want * step
	return _head.distance_to(to) <= arrive


## Dirt kicked up where it's moving or about to come out.
func _rumble(at: Vector2, every: float) -> void:
	_rumble_puff -= get_physics_process_delta_time()
	if _rumble_puff <= 0.0:
		_rumble_puff = every
		_spray(at + Vector2(randf_range(-10, 10), 0), COLOR_DIRT)


func _spray(at: Vector2, color: Color) -> void:
	var room := get_parent()
	if room.has_method("_spawn_debris"):
		room._spawn_debris(at, color)


func _spawn_projectile_dust(at: Vector2) -> void:
	var room := get_parent()
	if room.has_method("_spawn_debris"):
		room._spawn_debris(at, COLOR_DIRT_LIGHT)


# --- Phase 1's end ---

## Beaten: it shrieks, the hilt tears loose and floats to the middle of the pit, and the
## centipede dives into the earth and flees. (The room puts the hilt pickup where it floats.)
func _flee() -> void:
	_shake = 0.7
	_hilt_from = _head
	_hilt_t = 0.0
	var away := _left - 40.0 if _head.x > position.x else _right + 40.0
	_path = [Vector2(_head.x, _floor + DEPTH), Vector2(away, _floor + DEPTH)]
	for i in 6:
		_spray(_head + Vector2(randf_range(-10, 10), 0), COLOR_DIRT)
	_enter(St.FLEE, 4.0)


func _finish() -> void:
	Game.defeated[boss_id] = true
	_set_boxes_active(false)
	defeated.emit()
	_restore_camera()
	queue_free()


# --- Phase 2's living coils ---

func _update_walls(delta: float) -> void:
	if _wall_bodies.is_empty():
		for i in 2:
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := RectangleShape2D.new()
			shape.size = Vector2(32, 1)
			var col := CollisionShape2D.new()
			col.shape = shape
			body.add_child(col)
			body.top_level = true
			add_child(body)
			_wall_bodies.append(body)
	# At half health the coils close in.
	var squeeze := 2.5 * TILE if _enraged else 0.0
	_left = move_toward(_left, _wall_x[0] + squeeze, 40.0 * delta)
	_right = move_toward(_right, _wall_x[1] - squeeze, 40.0 * delta)
	var room := get_parent()
	for i in 2:
		var face: float = _left if i == 0 else _right
		var center_x := face - 16.0 if i == 0 else face + 16.0
		var height: float = maxf(1.0, _coil_bottom[i] - _coil_top[i])
		var shape: RectangleShape2D = _wall_bodies[i].get_child(0).shape
		shape.size = Vector2(32, height)
		_wall_bodies[i].global_position = room.to_global(Vector2(center_x, _coil_top[i] + height / 2.0))
	if _enraged and _state not in [St.GONE, St.DYING, St.CHARGE_GATE]:
		_hatch_timer -= delta
		if _hatch_timer <= 0.0:
			_hatch_timer = 6.0
			if get_tree().get_nodes_in_group("hatchling").size() < 2:
				var crawler := Crawler.new()
				crawler.position = Vector2(randf_range(_left + 20, _right - 20), _top + 8)
				crawler.kind = "hatchling"
				crawler.add_to_group("hatchling")
				room.add_child(crawler)
	_walls.queue_redraw()


## Beaten, each coil breaks apart from the top down: its pieces tumble off and fall.
func _crumble_coils(delta: float) -> void:
	_crumble -= delta
	if _crumble > 0.0:
		return
	_crumble = 0.05
	for i in 2:
		if _coil_bottom[i] - _coil_top[i] < 1.0:
			continue
		var face: float = _left if i == 0 else _right
		var cx := face - 16.0 if i == 0 else face + 16.0
		var y: float = _coil_top[i] + _spacing * 0.5
		_coil_top[i] = minf(_coil_top[i] + _spacing, _coil_bottom[i])
		_falling.append({
			"pos": Vector2(cx + randf_range(-4, 4), y), "vel": Vector2(randf_range(-70, 70), randf_range(-90, -10)),
			"rot": PI / 2.0, "spin": randf_range(-6.0, 6.0), "coil": i,
		})
		_spray(Vector2(cx, y), COLOR_DIRT)


func _update_falling(delta: float) -> void:
	var landed := []
	for piece in _falling:
		piece.vel.y += 600.0 * delta
		piece.pos += piece.vel * delta
		piece.rot += piece.spin * delta
		if piece.pos.y > _floor + 10.0:
			landed.append(piece)
	for piece in landed:
		_spray(Vector2(piece.pos.x, _floor), COLOR_DIRT)
		_falling.erase(piece)


## The coils: segments stacked from the floor up, sliding as if it's circling Storm (up one
## side, down the other).
func _draw_walls() -> void:
	var scroll := fmod(_time * (46.0 if _enraged else 30.0), _spacing)
	for i in 2:
		if _coil_bottom[i] - _coil_top[i] < 2.0:
			continue
		var face: float = _left if i == 0 else _right
		var cx := (face - 16.0 if i == 0 else face + 16.0) - position.x
		var up := i == 0
		# Segments only slide once the coil is whole (while forming, it's the body following
		# the head).
		var slide := scroll if _state not in [St.COIL_UP, St.COIL_ACROSS, St.COIL_DOWN, St.DYING] else 0.0
		var y: float = _coil_bottom[i] + _spacing - (slide if up else _spacing - slide)
		while y > _coil_top[i] + _spacing * 0.3:
			_draw_segment_on(_walls, Vector2(cx, y - position.y), -PI / 2.0 if up else PI / 2.0, not up)
			y -= _spacing
	for piece in _falling:
		_draw_segment_on(_walls, piece.pos - position, piece.rot, piece.coil == 1)


# --- The body ---

## Each segment sits a fixed distance back along the head's path.
func _follow_trail() -> void:
	if _state == St.DORMANT:
		return
	if _trail.is_empty() or _trail[0].distance_to(_head) >= 2.0:
		var moved := _head - _trail[0] if not _trail.is_empty() else Vector2.ZERO
		if moved != Vector2.ZERO:
			_head_dir = _head_dir.slerp(moved.normalized(), 0.35).normalized()
		_trail.push_front(_head)
	var need := int(_segs.size() * _spacing / 2.0) + 30
	while _trail.size() > need:
		_trail.pop_back()
	var k := 0
	var walked := 0.0
	for i in _segs.size():
		var want := i * _spacing
		while k < _trail.size() - 1 and walked + _trail[k].distance_to(_trail[k + 1]) < want:
			walked += _trail[k].distance_to(_trail[k + 1])
			k += 1
		if k >= _trail.size() - 1:
			_segs[i] = _trail[-1]
		else:
			var span := _trail[k].distance_to(_trail[k + 1])
			_segs[i] = _trail[k].lerp(_trail[k + 1], (want - walked) / span if span > 0.0 else 0.0)


func _place_boxes() -> void:
	var room := get_parent()
	var alive := _state not in [St.DORMANT, St.FLEE, St.DYING, St.LAST_RUMBLE, St.CHARGE_GATE, St.GONE]
	_head_box.global_position = room.to_global(_head)
	_head_box.collision_layer = LAYER_ENEMY if alive and _in_open(_head) else 0
	for k in _body_boxes.size():
		var i := 1 + k * 2
		if i < _segs.size():
			_body_boxes[k].global_position = room.to_global(_segs[i])
			var harmful := alive and i <= HARMFUL_SEGMENTS and _in_open(_segs[i])
			_body_boxes[k].collision_layer = LAYER_ENEMY if harmful else 0


# --- Screen shake ---

func _update_shake(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if _cam_base == Vector2.ZERO:
		_cam_base = cam.offset
	_shake -= delta
	cam.offset = _cam_base + (Vector2(randf_range(-2, 2), randf_range(-2, 2)) if _shake > 0.0 else Vector2.ZERO)


func _restore_camera() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and _cam_base != Vector2.ZERO:
		cam.offset = _cam_base


func _exit_tree() -> void:
	_restore_camera()


# --- Art ---

func _draw() -> void:
	if _state == St.DORMANT:
		if phase == 1:
			_draw_hilt(Vector2(0, _lid_y - position.y), true, PI)
			if _near_hilt:
				var font := ThemeDB.fallback_font
				draw_string(font, Vector2(-14, _lid_y - position.y - 26), "W / E", HORIZONTAL_ALIGNMENT_CENTER,
					28, 8, Color(1, 0.95, 0.8, 0.85))
		return
	_draw_warning()
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	for i in range(_segs.size() - 1, 0, -1):
		var along := _segs[i].direction_to(_segs[i - 1])
		if along == Vector2.ZERO:
			continue
		_draw_segment_on(self, _segs[i] - position, along.angle(), along.x < 0.0, tint)
	_draw_head(_head - position, _head_dir, tint)
	if _hilt_t >= 0.0:
		# Torn loose, it arcs up and drifts to hover over the middle of the pit.
		var to := Vector2(position.x, _floor - TILE)
		var at := _hilt_from.lerp(to, ease(_hilt_t, -2.0)) - Vector2(0, sin(_hilt_t * PI) * 40.0)
		# (Ends upright and the same size as the pickup that replaces it.)
		_draw_hilt(at - position, false, _hilt_t * TAU * 2.0)


## The swell of earth where it's about to burst out: a mound on the floor, a bulge on a wall.
func _draw_warning() -> void:
	var grow := 0.0
	if _state in [St.RUMBLE, St.WALL_RUMBLE, St.DUST]:
		grow = clampf(1.0 - _timer / _warn_time(), 0.0, 1.0)
	elif _state == St.TUNNEL:
		grow = 0.25
	if grow <= 0.0:
		return
	var jitter := Vector2(randf_range(-0.7, 0.7), 0)
	var at := (_spot if _state != St.TUNNEL else Vector2(_head.x, _floor)) - position + jitter
	var w := 10.0 + 12.0 * grow
	var h := 2.0 + 5.0 * grow
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI * i / 8.0
		match _state:
			St.WALL_RUMBLE:
				pts.append(at + Vector2(sin(a) * h * _dir, -cos(a) * w * 0.6))
			St.DUST:
				pts.append(at + Vector2(-cos(a) * w, sin(a) * h))
			_:
				pts.append(at + Vector2(-cos(a) * w, -sin(a) * h))
	draw_colored_polygon(pts, COLOR_DIRT)
	draw_polyline(pts, COLOR_DIRT_LIGHT, 1.0)


func _draw_segment_on(canvas: CanvasItem, at: Vector2, angle: float, flip: bool, tint := Color.WHITE) -> void:
	canvas.draw_set_transform(at, angle, Vector2(_scale, -_scale if flip else _scale))
	var size := Vector2(_seg_tex.get_size())
	canvas.draw_texture(_seg_tex, -size / 2.0, tint)
	canvas.draw_set_transform(Vector2.ZERO)


func _draw_head(at: Vector2, dir: Vector2, tint: Color) -> void:
	var flip := dir.x < 0.0
	draw_set_transform(at, dir.angle(), Vector2(_scale, -_scale if flip else _scale))
	var size := Vector2(HEAD_TEX.get_size())
	draw_texture(HEAD_TEX, -size / 2.0, tint)
	draw_set_transform(Vector2.ZERO)


## The hilt, driven point-first into the tail (or, before the fight, into the ring's earth,
## only the pommel showing and catching the light).
func _draw_hilt(at: Vector2, glint: bool, angle: float) -> void:
	# The icon is 32x96, tip up, with the hilt in its bottom third; turned so the broken tip
	# points into whatever it's stuck in and the grip sticks out.
	var src := Rect2(0, 58, 32, 38)
	draw_set_transform(at + (Vector2(0, -8) if glint else Vector2.ZERO), angle, Vector2(0.4, 0.4))
	draw_texture_rect_region(HILT_TEX, Rect2(Vector2(-16, -19), src.size), src)
	draw_set_transform(Vector2.ZERO)
	if glint:
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		draw_circle(at + Vector2(0, -14), 3.0 + pulse * 2.0, Color(1.0, 0.85, 0.4, 0.25 + 0.2 * pulse))
		draw_line(at + Vector2(-4 - pulse * 3, -14), at + Vector2(4 + pulse * 3, -14), Color(1, 0.95, 0.7, 0.6), 1.0)
		draw_line(at + Vector2(0, -18 - pulse * 3), at + Vector2(0, -10 + pulse * 3), Color(1, 0.95, 0.7, 0.6), 1.0)
