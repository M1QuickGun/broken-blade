extends Node2D
## The Guardian Centipede, the Foothills' boss, fought twice.
##
## Phase 1, the ring: it lies under the stone ring, pinned to the bottom of a pit by the hilt
## driven through its tail. When Storm steps onto the ring the lid of earth gives way and he
## drops into the pit with it. Tethered to the pin, it rears and lunges, sweeps across the
## floor at knee height, and slams the walls to bring clods down. Beaten, it goes limp and the
## hilt can be pulled free (the wall jump); then it sinks into the earth, seemingly dead.
##
## Phase 2, the gate cavern: it bursts through the ceiling, bigger and armored, and its body
## pours down into two living walls that trap Storm between them (walls he can cling to). Its
## head strikes down from the ceiling, bursts out of the coils at floor height, and spits
## clods. At half health the coils close in and hatchlings drop. Its death throes smash the
## frozen gate.
##
## The node's origin is the room's B marker: the pin in phase 1, the arena's middle in phase 2.
## The body is a chain of segments hanging off the head, solved each frame between the head
## and an anchor (the pin, or wherever the neck enters the rock), with a little gravity.

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

enum St {
	DORMANT, EMERGE, IDLE, REAR, LUNGE, STUCK, RETRACT, DIVE, WARN, SWEEP, SLAM,
	HIDE, DROP, DOWNED, SINKING, DYING, CHARGE_GATE, GONE,
}

## Set by the room before it's added (see Rooms.BOSSES).
var boss_id := ""
var kind := "centipede"
var phase := 1
var title := ""
var max_hp := 14

var hp := 0

var _state := St.DORMANT
var _timer := 0.0
var _time := 0.0
var _flash := 0.0
## Art scale (the risen centipede is bigger) and the spacing of its segments.
var _scale := 0.5
var _spacing := 10.0
var _segs: Array[Vector2] = []
var _head := Vector2.ZERO
var _head_dir := Vector2.RIGHT
var _anchor := Vector2.ZERO
var _target := Vector2.ZERO
var _speed := 0.0
var _side := 1
var _shake := 0.0
var _cam_base := Vector2.ZERO
var _head_box: Hitbox
var _body_boxes: Array[Hitbox] = []

# The arena, in the room's coordinates.
var _left := 0.0
var _right := 0.0
var _floor := 0.0
var _top := 0.0
var _lid_y := 0.0

# Phase 2's living walls: x of each wall's inner face, their height (0 to 1 while they pour
# down), and the solid bodies Storm clings to.
var _seg_tex: Texture2D = SEG_TEX
var _walls: Node2D
var _wall_bodies: Array[StaticBody2D] = []
var _wall_x := [0.0, 0.0]
var _wall_drop := 0.0
var _enraged := false
var _hatch_timer := 4.0


func _ready() -> void:
	hp = max_hp
	z_index = -1  # behind the tiles, so burrowing into the earth hides it
	if phase >= 2:
		_scale = 0.7
		_spacing = 14.0
		_seg_tex = SEG_TEX_ARMORED
	var count := 22 if phase == 1 else 30
	_measure_arena()
	_head = position
	for i in count:
		_segs.append(position + Vector2(0, 40))
	_head_box = _make_box(Vector2(22, 16) * _scale / 0.5, true)
	for i in range(1, count, 2):
		_body_boxes.append(_make_box(Vector2(14, 12) * _scale / 0.5, false))
	_set_boxes_active(false)
	if phase >= 2:
		_walls = Node2D.new()
		_walls.z_index = 1
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
	while y > 0 and not _solid(room, cx, y - 1):
		y -= 1
	_top = y * TILE
	_lid_y = (y - 1) * TILE
	if phase >= 2:
		# The coils fall a little inside the cavern: one behind Storm, one before the gate.
		_wall_x = [6.0 * TILE + 32.0, 32.0 * TILE]
		_left = _wall_x[0]
		_right = _wall_x[1]


func _solid(room: Node, x: int, y: int) -> bool:
	var c: String = room._cell(x, y)
	return c == "#" or c == "=" or c == "G"


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
	box.collision_layer = LAYER_ENEMY
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


func shock_point() -> Vector2:
	return get_parent().to_global(_head)


func take_hit(damage: int, _from_dir: Vector2) -> void:
	if _state in [St.DORMANT, St.EMERGE, St.DOWNED, St.SINKING, St.DYING, St.CHARGE_GATE, St.GONE]:
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
			_enter(St.DOWNED, 1.2)
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
		St.IDLE:
			_hover(p, delta)
			if _timer <= 0.0:
				_choose_attack(p)
		St.REAR:
			# Rear up high and shake: the lunge is coming.
			_steer_to(Vector2(clampf(p.x, _left + 30, _right - 30) - _side * 40.0, _floor - 90.0 * _scale / 0.5), 260.0, delta)
			_head += Vector2(randf_range(-1.5, 1.5), 0)
			if _timer <= 0.0:
				_target = Vector2(clampf(p.x, _left + 12, _right - 12), _floor - 8)
				_enter(St.LUNGE, 1.0)
		St.LUNGE, St.DROP:
			if _steer_to(_target, (430.0 if phase == 1 else 520.0) * _tempo(), delta, 14.0) or _timer <= 0.0:
				_shake = 0.25
				_spray(_head, Color("3b352b"))
				_enter(St.STUCK, 1.1 if phase == 1 else 0.9)
		St.STUCK:
			_head += Vector2(randf_range(-0.6, 0.6), 0)
			if _timer <= 0.0:
				_enter(St.RETRACT, 0.7)
		St.RETRACT:
			_hover(p, delta)
			if _timer <= 0.0:
				_enter(St.IDLE)
		St.DIVE, St.HIDE:
			# Into the earth (phase 1) or up into the ceiling (phase 2), out of sight.
			if _steer_to(_target, 320.0, delta, 8.0) or _timer <= 0.0:
				_begin_warning(p)
		St.WARN:
			if fmod(_time, 0.08) < delta:
				_spray(_warn_point(), Color("3b352b"))
			if _timer <= 0.0:
				_set_boxes_active(true)
				if _side == 0:
					_target = Vector2(_head.x, _floor - 10)
					_enter(St.DROP, 1.2)
				else:
					_target = Vector2(_right + 30 if _side < 0 else _left - 30, _floor - 12 * _scale / 0.5)
					_enter(St.SWEEP, 2.0)
		St.SWEEP:
			if _steer_to(_target, 330.0 * _tempo(), delta, 10.0) or _timer <= 0.0:
				_back_to_hover()
		St.SLAM:
			if _steer_to(_target, 380.0, delta, 10.0) or _timer <= 0.0:
				_shake = 0.35
				_spray(_head, Color("3b352b"))
				_rain_clods(p)
				_enter(St.RETRACT, 0.8)
		St.DOWNED:
			_update_downed(delta)
		St.SINKING:
			for i in _segs.size():
				_segs[i].y += 18.0 * delta
			_head.y += 18.0 * delta
			_anchor.y += 18.0 * delta
			if _timer <= 0.0:
				_finish()
		St.DYING:
			_head += Vector2(randf_range(-3, 3), randf_range(-3, 3))
			_shake = maxf(_shake, 0.1)
			if _timer <= 0.0:
				_target = Vector2(_right + 40, _floor - 30)
				_enter(St.CHARGE_GATE, 1.5)
		St.CHARGE_GATE:
			if _steer_to(_target, 420.0, delta, 12.0) or _timer <= 0.0:
				_shake = 0.8
				get_parent().shatter_gate()
				_enter(St.GONE, 1.2)
		St.GONE:
			_wall_drop = clampf(_timer / 1.2, 0.0, 1.0)
			_head.y += 60.0 * delta
			if _timer <= 0.0:
				_finish()
	if phase >= 2 and _state != St.DORMANT:
		_update_walls(delta)
	_solve_body(delta)
	_place_boxes()
	_update_shake(delta)
	queue_redraw()


func _tempo() -> float:
	return 1.25 if _enraged else 1.0


func _enter(state: St, time := -1.0) -> void:
	_state = state
	match state:
		St.IDLE:
			_timer = ((0.9 if phase == 1 else 0.7) / _tempo()) if time < 0.0 else time
		St.REAR:
			_timer = 0.55 / _tempo()
		_:
			_timer = time


func _update_dormant(p: Vector2) -> void:
	if phase == 1:
		# Stepping onto the ring breaks the lid.
		_anchor = position
		if p.x > _left + 8 and p.x < _right - 8 and p.y <= _lid_y + 4:
			get_parent().break_lid()
			_shake = 0.5
			_wake()
	elif p.x > 11.0 * TILE:
		_shake = 1.0
		_wake()


func _wake() -> void:
	engaged.emit()
	add_to_group("boss")
	add_to_group("shock_target")
	if phase == 1:
		# It bursts up out of the pit floor beside the pin.
		_head = Vector2(position.x + 30, _floor + 30)
		_anchor = position
	else:
		_head = Vector2(position.x, -60)
		_anchor = Vector2(position.x, -120)
	for i in _segs.size():
		_segs[i] = _anchor
	_target = Vector2(position.x + (20 if phase == 1 else 0), _floor - 70 * _scale / 0.5)
	_enter(St.EMERGE, 1.4)


func _update_emerge(delta: float) -> void:
	if phase >= 2:
		_wall_drop = clampf(1.0 - (_timer - 0.4), 0.0, 1.0)
	if _timer < 1.0:
		_set_boxes_active(true)
		_steer_to(_target, 240.0, delta, 6.0)
	if _timer <= 0.0:
		_enter(St.IDLE)


func _choose_attack(p: Vector2) -> void:
	_side = 1 if p.x < _head.x else -1
	var roll := randf()
	if phase == 1:
		if roll < 0.45:
			_enter(St.REAR)
		elif roll < 0.8:
			# Down into the earth, then out of the wall on the far side from Storm.
			_side = 1 if p.x > position.x else -1
			_target = Vector2(position.x, _floor + 40)
			_enter(St.DIVE, 0.9)
		else:
			_target = Vector2(_left - 10 if p.x > position.x else _right + 10, _floor - 70)
			_enter(St.SLAM, 1.0)
	else:
		if roll < 0.4:
			_side = 0  # from the ceiling, straight down on Storm
			_target = Vector2(_head.x, -40)
			_enter(St.HIDE, 0.7)
		elif roll < 0.75:
			_side = 1 if p.x > position.x else -1  # out of the coil on the far side from Storm
			_target = Vector2(_head.x, -40)
			_enter(St.HIDE, 0.7)
		else:
			_spit(p)
			_enter(St.RETRACT, 0.9)


func _begin_warning(p: Vector2) -> void:
	_set_boxes_active(false)  # hidden in the rock while it waits
	if _side == 0:
		# Hanging hidden in the ceiling over Storm; dust trickles down where it'll strike.
		_head = Vector2(clampf(p.x, _left + 16, _right - 16), -30)
		_anchor = Vector2(_head.x, -140)
	else:
		# Waiting inside the rock (or the coil) at knee height.
		var x := _left - 24 if _side > 0 else _right + 24
		_head = Vector2(x, _floor - 12 * _scale / 0.5)
		# Phase 1 stays tethered to the pin; phase 2's neck runs up inside its coil.
		_anchor = position if phase == 1 else Vector2(x - _side * 30, -100)
	for i in _segs.size():
		_segs[i] = _anchor
	_enter(St.WARN, 0.7 / _tempo())


func _warn_point() -> Vector2:
	if _side == 0:
		return Vector2(_head.x + randf_range(-10, 10), _top + 4)
	return Vector2(_left if _side > 0 else _right, _floor - randf_range(4, 26))


func _back_to_hover() -> void:
	if phase == 1:
		_anchor = position
	else:
		_anchor = Vector2(clampf(_head.x, _left + 40, _right - 40), -140)
	_enter(St.RETRACT, 0.8)


## Weave about above Storm, keeping some distance.
func _hover(p: Vector2, delta: float) -> void:
	var off := 70.0 * _side
	var hx := clampf(p.x + off + sin(_time * 1.7) * 20.0, _left + 24, _right - 24)
	var hy := _floor - (62.0 + sin(_time * 2.3) * 10.0) * _scale / 0.5
	_steer_to(Vector2(hx, hy), 160.0, delta)
	if phase >= 2 and _state == St.RETRACT:
		_anchor = _anchor.move_toward(Vector2(_head.x, -140), 200.0 * delta)


## Moves the head toward a point, turning like a snake. True once it's there.
func _steer_to(to: Vector2, speed: float, delta: float, arrive := 4.0) -> bool:
	var want := _head.direction_to(to)
	if want != Vector2.ZERO:
		_head_dir = _head_dir.slerp(want, clampf(8.0 * delta, 0.0, 1.0)).normalized()
	var step := minf(speed * delta, _head.distance_to(to))
	_head += (want * 0.6 + _head_dir * 0.4).normalized() * step if want != Vector2.ZERO else Vector2.ZERO
	return _head.distance_to(to) <= arrive


func _rain_clods(p: Vector2) -> void:
	for i in (5 if phase == 1 else 7):
		var x := clampf(p.x + randf_range(-110, 110), _left + 8, _right - 8)
		_spawn_projectile("clod", Vector2(x, _top + 4), Vector2.ZERO, 420.0, 3.0, i * 0.12)


func _spit(p: Vector2) -> void:
	for i in 3:
		var aim := _head.direction_to(p).rotated((i - 1) * 0.25)
		_spawn_projectile("clod", _head, aim * 190.0 + Vector2(0, -60), 380.0, 3.0, i * 0.08)


func _spawn_projectile(p_kind: String, pos: Vector2, vel: Vector2, grav: float, p_life: float, delay := 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree():
			return
	var proj := Projectile.new()
	proj.kind = p_kind
	proj.velocity = vel
	proj.fall_accel = grav
	proj.life = p_life
	proj.position = pos
	get_parent().add_child(proj)


func _spray(at: Vector2, color: Color) -> void:
	var room := get_parent()
	if room.has_method("_spawn_debris"):
		room._spawn_debris(at, color)


# --- Phase 1's end: limp, the hilt pulled free, then sinking away ---

func _update_downed(delta: float) -> void:
	_steer_to(Vector2(_head.x, _floor - 8), 80.0, delta)
	if _timer > 0.0:
		_head += Vector2(randf_range(-2, 2), 0)
		return
	if not Game.has_ability("wall_jump"):
		if get_tree().get_nodes_in_group("hilt_pickup").is_empty():
			var shard := Shard.new()
			shard.ability = "wall_jump"
			shard.position = position + Vector2(0, -10)
			shard.add_to_group("hilt_pickup")
			get_parent().add_child(shard)
		return
	# The hilt is out: it shudders and sinks into the earth.
	_shake = 0.6
	_set_boxes_active(false)
	_enter(St.SINKING, 1.8)


func _finish() -> void:
	Game.defeated[boss_id] = true
	_set_boxes_active(false)
	defeated.emit()
	_restore_camera()
	queue_free()


# --- Phase 2's living walls ---

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
	var height := (_floor - _top + TILE) * _wall_drop
	var room := get_parent()
	for i in 2:
		var face: float = _left if i == 0 else _right
		var center_x := face - 16.0 if i == 0 else face + 16.0
		var shape: RectangleShape2D = _wall_bodies[i].get_child(0).shape
		shape.size = Vector2(32, maxf(1.0, height))
		_wall_bodies[i].global_position = room.to_global(Vector2(center_x, _top - TILE + height / 2.0))
	if _enraged and _state != St.GONE and _state != St.DYING and _state != St.CHARGE_GATE:
		_hatch_timer -= delta
		if _hatch_timer <= 0.0:
			_hatch_timer = 5.5
			if get_tree().get_nodes_in_group("hatchling").size() < 2:
				var crawler := Crawler.new()
				crawler.position = Vector2(randf_range(_left + 20, _right - 20), _top + 8)
				crawler.add_to_group("hatchling")
				room.add_child(crawler)
	_walls.queue_redraw()


func _draw_walls() -> void:
	if _wall_drop <= 0.0:
		return
	var height := (_floor - _top + TILE) * _wall_drop
	var scroll := fmod(_time * (50.0 if _enraged else 32.0), _spacing)
	for i in 2:
		var face: float = _left if i == 0 else _right
		var cx := (face - 16.0 if i == 0 else face + 16.0) - position.x
		var dir := 1.0 if i == 0 else -1.0  # coiling down one side and up the other
		var y := _top - TILE - _spacing + (scroll if i == 0 else _spacing - scroll)
		while y < _top - TILE + height:
			_draw_segment_on(_walls, Vector2(cx, y - position.y), PI / 2.0 * dir, i == 1)
			y += _spacing


# --- The body ---

func _solve_body(delta: float) -> void:
	if _state == St.DORMANT:
		return
	var n := _segs.size()
	var reach := _spacing * (n - 1) * 0.98
	if _head.distance_to(_anchor) > reach:
		_head = _anchor + _anchor.direction_to(_head) * reach
	# A little weight: loose coils settle toward the floor.
	var rest := _floor - 6.0 * _scale / 0.5
	for i in range(1, n - 1):
		if _segs[i].y < rest:  # (buried coils stay buried)
			_segs[i].y = minf(_segs[i].y + 70.0 * delta, rest)
	for iteration in 2:
		_segs[n - 1] = _anchor
		for i in range(n - 2, -1, -1):
			_segs[i] = _segs[i + 1] + _segs[i + 1].direction_to(_segs[i]) * _spacing
		_segs[0] = _head
		for i in range(1, n):
			_segs[i] = _segs[i - 1] + _segs[i - 1].direction_to(_segs[i]) * _spacing
	var ahead := _segs[1].direction_to(_head)
	if ahead != Vector2.ZERO:
		_head_dir = _head_dir.slerp(ahead, 0.3).normalized()


func _place_boxes() -> void:
	var room := get_parent()
	_head_box.global_position = room.to_global(_head)
	for k in _body_boxes.size():
		var i := 1 + k * 2
		if i < _segs.size():
			_body_boxes[k].global_position = room.to_global(_segs[i])


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
			_draw_hilt(Vector2(0, _lid_y - position.y), true)
		return
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	if _state == St.SINKING:
		tint = Color(1, 1, 1, clampf(_timer / 1.8, 0.0, 1.0))
	for i in range(_segs.size() - 1, 0, -1):
		var along := _segs[i].direction_to(_segs[i - 1])
		_draw_segment_on(self, _segs[i] - position, along.angle(), along.x < 0.0, tint)
	if phase == 1 and _state != St.SINKING and not Game.has_ability("wall_jump"):
		_draw_hilt(_anchor - position, false)
	var head_tint := tint
	if _state in [St.REAR, St.WARN] and fmod(_time, 0.2) < 0.1:
		head_tint = Color(1.4, 1.1, 0.8, tint.a)
	_draw_head(_head - position, _head_dir, head_tint)


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
func _draw_hilt(at: Vector2, glint: bool) -> void:
	# The icon is 32x96, tip up, with the hilt in its bottom third; flipped so the grip points up.
	var src := Rect2(0, 58, 32, 38)
	draw_set_transform(at + Vector2(0, -8), PI, Vector2(0.4, 0.4))
	draw_texture_rect_region(HILT_TEX, Rect2(Vector2(-16, -19), src.size), src)
	draw_set_transform(Vector2.ZERO)
	if glint:
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		draw_circle(at + Vector2(0, -14), 3.0 + pulse * 2.0, Color(1.0, 0.85, 0.4, 0.25 + 0.2 * pulse))
		draw_line(at + Vector2(-4 - pulse * 3, -14), at + Vector2(4 + pulse * 3, -14), Color(1, 0.95, 0.7, 0.6), 1.0)
		draw_line(at + Vector2(0, -18 - pulse * 3), at + Vector2(0, -10 + pulse * 3), Color(1, 0.95, 0.7, 0.6), 1.0)
