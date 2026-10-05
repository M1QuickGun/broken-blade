extends Node2D
## The Ashen Drake, the Fire slopes' boss: a dragon of charred scales and embers, fought twice.
## Built from parts cut from one drawing (art/bosses/drake_*.png, all on the same 256x144
## canvas, facing right) that the code poses: body and folded wings, neck and head, lower
## jaw, tail, hind legs and front legs.
##
## Phase 1, the Forge: the fire piece is driven through its wing and pins it, so it can't
## fly. It sleeps in the ashes at the forge's west end until Storm comes in, then stalks him
## along the floor and, in a fixed order:
## - Lunge: it crouches, head drawn back, then lunges forward and snaps. Its head stays low
##   afterwards, panting smoke: the opening to hit it.
## - Breath: its throat glows as it rears its head, then a jet of fire sweeps from high on
##   the far wall down to the floor just ahead of it. The safe place is close in, right
##   under its chin (or behind it).
## - Stomp: it rears up and slams its forefeet down; embers rain from the forge's roof,
##   their glow on the floor showing where.
## And if Storm gets behind it, it raises its tail and lashes it down: a wave of fire runs
## out along the floor behind it to jump.
## Its body hurts to touch; its head doesn't, and both can be struck.
## Beaten, it collapses and the fire piece tears out of its wing and floats down. Then it
## heaves itself up, roars, and bolts out of the forge to the west, free.
##
## The node's origin is the room's B marker, on the arena's floor.

signal defeated
## Sent when it wakes: the room bars its doors then.
signal engaged

const Effects := preload("res://scripts/effects.gd")
const Projectile := preload("res://scripts/projectile.gd")

const BODY := preload("res://art/bosses/drake_body.png")
const HEAD := preload("res://art/bosses/drake_head.png")
const JAW := preload("res://art/bosses/drake_jaw.png")
const TAIL := preload("res://art/bosses/drake_tail.png")
const HIND := preload("res://art/bosses/drake_hind.png")
const FRONT := preload("res://art/bosses/drake_front.png")

const TILE := 16
const LAYER_ENEMY := 4
## Art pixels to world units.
const SCALE := 0.8
## Points on the shared art canvas: where it stands (between its feet, on the ground), and
## each part's pivot.
const ART_ORIGIN := Vector2(160, 131)
const HIND_FOOT := Vector2(128, 131)
const BODY_PIVOT := Vector2(150, 95)
const HEAD_PIVOT := Vector2(182, 94)
const JAW_PIVOT := Vector2(228, 63)
const TAIL_PIVOT := Vector2(108, 94)
const HIND_PIVOT := Vector2(126, 104)
const FRONT_PIVOT := Vector2(186, 104)
const MOUTH := Vector2(250, 66)
const SNOUT_TIP := Vector2(252, 62)
const JAW_TIP := Vector2(244, 72)
const EYE := Vector2(236, 53)
const TAIL_TIP := Vector2(2, 104)
## Which way its head points with the neck at rest (from the neck's base to its mouth).
const HEAD_REST := -0.39
## Where the fire piece is driven through its folded wing, and which way it points.
const PIN := Vector2(146, 70)
const LEG_LENGTH := 27.0 * SCALE
## How far its body sinks as it crouches (its legs bend under it).
const CROUCH_DROP := 12.0

const WALK_SPEED := 34.0
const LUNGE_DIST := 96.0
## The breath jet's width, and where its sweep starts (up the far wall) and ends (on the
## floor this far ahead of it).
const JET_WIDTH := 14.0
const JET_START_HEIGHT := 90.0
const JET_END := 130.0
const PATTERN_1 := ["lunge", "breath", "lunge", "stomp"]

const COLOR_FIRE := Color(1.0, 0.5, 0.15)
const COLOR_FIRE_HOT := Color(1.0, 0.85, 0.45)
const COLOR_SMOKE := Color(0.2, 0.18, 0.17)
const COLOR_MOUTH := Color(0.35, 0.06, 0.02)
const COLOR_EYES := Color(1.0, 0.6, 0.2)
const COLOR_SHADOW := Color(0.05, 0.02, 0.0, 0.5)
const COLOR_PIECE := Color(1.0, 0.62, 0.25)

enum St {
	DORMANT, WAKE, IDLE, TURN, LUNGE_WINDUP, LUNGE, PANT, BREATH_WINDUP, BREATH,
	REAR, SLAM, TAIL_RAISE, TAIL_LASH, SLUMP, FLEE,
}

## Set by the room before it's added (see Rooms.BOSSES).
var boss_id := ""
var kind := "drake"
var phase := 1
var title := ""
var max_hp := 16

var hp := 0

var _state := St.DORMANT
var _timer := 0.0
var _time := 0.0
var _flash := 0.0
var _shake := 0.0
var _cam_base := Vector2.ZERO
var _move := 0
var _floor := 0.0
var _left := 0.0
var _right := 0.0
## Where it stands, which way it faces, and its pose: the neck's angle (negative raises the
## head), how far the jaw hangs open, the tail's angle (positive raises it), how far it's
## crouched, how far it's reared back (radians, about its hind feet), and its stride.
var _x := 0.0
var _dir := 1
var _neck := 0.0
var _jaw := 0.0
var _tail := 0.0
var _crouch := 0.0
var _tilt := 0.0
var _stride := 0.0
var _alpha := 1.0
## How long Storm has been behind it (it turns only after a moment).
var _behind := 0.0
var _lunge_from := 0.0
var _lunge_to := 0.0
## The breath's sweep (0 = high on the far wall, 1 = on the floor just ahead), and where it
## lands right now.
var _sweep := 0.0
var _jet_end := Vector2.ZERO
## Embers about to fall from the roof: {x, t}.
var _embers: Array[Dictionary] = []
## The fire piece flying out of its wing (0 to 1, or -1 while it's still in), from where to
## where.
var _piece_t := -1.0
var _piece_from := Vector2.ZERO
var _piece_rest := Vector2.ZERO
## Smoke puffs drifting off it: {pos, vel, life, size}.
var _smoke := []
## Its fight is over and the room has its reward: the piece is no longer drawn here.
var _done := false

var _head_box: Hitbox
var _body_box: Hitbox
var _legs_box: Hitbox
var _tail_box: Hitbox
var _jet_box: Hitbox


## One of its hurtful or strikable parts. `weak`: struck, it hurts the drake. `harmless`:
## touched, it doesn't hurt Storm.
class Hitbox extends Area2D:
	var boss: Node
	var weak := false
	var harmless := false

	func take_hit(damage: int, from_dir: Vector2) -> void:
		if weak:
			boss.take_hit(damage, from_dir)


func _ready() -> void:
	hp = max_hp
	z_index = -1
	_floor = position.y
	_x = position.x
	_measure()
	_head_box = _make_box(Vector2(30, 24), true, true)
	_body_box = _make_box(Vector2(84, 34), true, false)
	_legs_box = _make_box(Vector2(80, 18), false, false)
	_tail_box = _make_box(Vector2(70, 16), false, false)
	_jet_box = _make_box(Vector2(10, JET_WIDTH), false, false)
	for box in [_head_box, _body_box, _legs_box, _tail_box, _jet_box]:
		_set_box(box, false)
	# Asleep: crouched in the ashes, head down.
	_crouch = 1.0
	_neck = 0.35


func _measure() -> void:
	var room := get_parent()
	var cx := int(position.x / TILE)
	var cy := int(position.y / TILE) - 1
	var x := cx
	while x < room.size_tiles.x - 1 and room._cell(x + 1, cy) != "#":
		x += 1
	_right = (x + 1) * TILE
	x = cx
	while x > 0 and room._cell(x - 1, cy) != "#":
		x -= 1
	_left = x * TILE


func _make_box(size: Vector2, weak: bool, harmless: bool) -> Hitbox:
	var box := Hitbox.new()
	box.boss = self
	box.weak = weak
	box.harmless = harmless
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


func _set_box(box: Area2D, on: bool, at := Vector2.ZERO, angle := 0.0) -> void:
	box.collision_layer = LAYER_ENEMY if on else 0
	if on:
		box.global_position = get_parent().to_global(at)
		box.global_rotation = angle


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


## The shockline pulls Storm to its head.
func shock_point() -> Vector2:
	return get_parent().to_global(_head_point())


func take_hit(damage: int, _from_dir: Vector2) -> void:
	if _state in [St.DORMANT, St.WAKE, St.SLUMP, St.FLEE]:
		return
	hp -= damage
	_flash = 0.1
	Sfx.play("hit_boss", -3.0)
	Effects.sparks(get_parent(), _head_point() if _near_head() else _body_point(), COLOR_FIRE, 14)
	if hp <= 0:
		hp = 0
		Effects.slow_motion(get_tree())
		remove_from_group("shock_target")
		remove_from_group("boss")
		_embers.clear()
		_enter(St.SLUMP, 2.6)


## Whether Storm is nearer its head than its body (for where the sparks fly).
func _near_head() -> bool:
	var player := _player()
	return player != null and player.position.distance_to(_head_point()) < player.position.distance_to(_body_point())


# --- Geometry ---

## A point on the art canvas placed in the room, for where it stands, which way it faces,
## how low it's crouched and how far it's reared.
func _w(art: Vector2) -> Vector2:
	var off := (art - ART_ORIGIN) * SCALE
	off.x *= _dir
	var foot := (HIND_FOOT - ART_ORIGIN) * SCALE
	foot.x *= _dir
	off = foot + (off - foot).rotated(_tilt * _dir)
	return Vector2(_x, _floor + CROUCH_DROP * _crouch) + off


## A point on a part that turns about `pivot` by `angle` (as if facing right), in the room.
func _on_part(pivot: Vector2, angle: float, art: Vector2) -> Vector2:
	var off := (art - pivot) * SCALE
	off.x *= _dir
	return _w(pivot) + off.rotated((angle + _tilt) * _dir)


func _head_point() -> Vector2:
	return _on_part(HEAD_PIVOT, _neck, Vector2(232, 58))


func _mouth() -> Vector2:
	return _on_part(HEAD_PIVOT, _neck, MOUTH)


func _body_point() -> Vector2:
	return _w(Vector2(150, 92))


func _tail_tip() -> Vector2:
	return _on_part(TAIL_PIVOT, _tail_angle(), TAIL_TIP)


## The tail's angle, held up off the floor when it rears back.
func _tail_angle() -> float:
	return _tail - _tilt * 1.1


func _pin_point() -> Vector2:
	return _w(PIN)


# --- Behaviour ---

func _physics_process(delta: float) -> void:
	_time += delta
	_flash -= delta
	_timer -= delta
	var player := _player()
	var p := player.position if player else Vector2(_x, _floor)
	_update_embers(delta)
	_update_smoke(delta)
	_phase_1(p, delta)
	_update_boxes()
	_update_shake(delta)
	queue_redraw()


func _enter(state: St, time := 0.0) -> void:
	_state = state
	_timer = time
	match state:
		St.WAKE, St.SLUMP:
			Sfx.play("roar", -1.0, 0.04)
		St.FLEE:
			Sfx.play("roar", 0.0, 0.04)
		St.LUNGE:
			Sfx.play("swing", -2.0)
		St.BREATH:
			Sfx.play("fire_breath", -2.0, 0.03)
		St.SLAM:
			Sfx.play("slam", -2.0)
		St.TAIL_LASH:
			Sfx.play("burst", -4.0)
		St.LUNGE_WINDUP, St.REAR:
			Sfx.play("rumble", -6.0)


func _wake() -> void:
	engaged.emit()
	add_to_group("boss")
	add_to_group("shock_target")
	_shake = 0.8
	_enter(St.WAKE, 2.0)


func _next_attack() -> String:
	var attack: String = PATTERN_1[_move % PATTERN_1.size()]
	_move += 1
	return attack


## Which side of it Storm is on: 1 ahead, -1 behind.
func _side(p: Vector2) -> int:
	return 1 if (p.x - _x) * _dir >= 0.0 else -1


func _phase_1(p: Vector2, delta: float) -> void:
	var settle := 4.0 * delta
	match _state:
		St.DORMANT:
			# Asleep, smoke curling from its nostrils.
			if fmod(_time, 0.9) < delta:
				_puff(_mouth(), Vector2(_dir * 6.0, -10.0), 4.0)
			if absf(p.x - _x) < 18.0 * TILE:
				_wake()
		St.WAKE:
			# It heaves itself up and roars, head high.
			_crouch = move_toward(_crouch, 0.0, delta / 1.2)
			_neck = lerp_angle(_neck, -0.45, 3.0 * delta)
			_jaw = lerpf(_jaw, 0.5 if _timer < 1.2 else 0.0, 6.0 * delta)
			if _timer <= 0.0:
				_enter(St.IDLE, 1.0)
		St.IDLE:
			_relax(settle)
			if _side(p) < 0:
				_behind += delta
			else:
				_behind = 0.0
			var gap := absf(p.x - _x)
			if _side(p) < 0 and gap < 120.0 and _timer <= 0.0:
				_enter(St.TAIL_RAISE, 0.55)
			elif _behind > 0.7:
				_enter(St.TURN, 0.3)
			elif _timer <= 0.0:
				match _next_attack():
					"lunge":
						_enter(St.LUNGE_WINDUP, 0.6)
					"breath":
						_enter(St.BREATH_WINDUP, 0.9)
					"stomp":
						_enter(St.REAR, 0.7)
			elif gap > 110.0 and _side(p) > 0:
				_walk(WALK_SPEED * _dir, delta)
		St.TURN:
			_crouch = 0.3 * sin(clampf(1.0 - _timer / 0.3, 0.0, 1.0) * PI)
			if _timer <= 0.15 and _side(p) < 0:
				_dir = -_dir
			if _timer <= 0.0:
				_behind = 0.0
				_enter(St.IDLE, 0.5)
		St.LUNGE_WINDUP:
			# Crouched, head drawn back, shaking.
			_crouch = move_toward(_crouch, 0.7, 3.0 * delta)
			_neck = lerp_angle(_neck, -0.3, 6.0 * delta)
			_jaw = lerpf(_jaw, 0.3, 6.0 * delta)
			if _timer <= 0.0:
				_lunge_from = _x
				_lunge_to = clampf(_x + _dir * LUNGE_DIST, _left + 90.0, _right - 90.0)
				_enter(St.LUNGE, 0.3)
		St.LUNGE:
			var t := clampf(1.0 - _timer / 0.3, 0.0, 1.0)
			_x = lerpf(_lunge_from, _lunge_to, ease(t, 0.5))
			_crouch = move_toward(_crouch, 0.2, 6.0 * delta)
			_neck = lerp_angle(_neck, 0.45, 10.0 * delta)
			_jaw = 0.6 if t < 0.7 else 0.0
			_stride += delta * 14.0
			if _timer <= 0.0:
				_shake = 0.25
				_enter(St.PANT, 1.4)
		St.PANT:
			# Head low by the floor, panting smoke: hit it.
			_neck = lerp_angle(_neck, 0.55, 5.0 * delta)
			_jaw = 0.25 + 0.15 * sin(_time * 9.0)
			_crouch = move_toward(_crouch, 0.4, 2.0 * delta)
			if fmod(_time, 0.25) < delta:
				_puff(_mouth(), Vector2(_dir * 10.0, -14.0), 3.0)
			if _timer <= 0.0:
				_enter(St.IDLE, 0.8)
		St.BREATH_WINDUP:
			# It rears its head and its throat glows.
			_crouch = move_toward(_crouch, 0.0, 2.0 * delta)
			_neck = lerp_angle(_neck, -0.6, 5.0 * delta)
			_jaw = lerpf(_jaw, 0.35, 4.0 * delta)
			if fmod(_time, 0.12) < delta:
				_puff(_mouth(), Vector2(_dir * 8.0, -16.0), 3.0)
			if _timer <= 0.0:
				_sweep = 0.0
				_enter(St.BREATH, 1.5)
		St.BREATH:
			_sweep = clampf(1.0 - _timer / 1.5, 0.0, 1.0)
			_jaw = 0.7 + 0.08 * sin(_time * 30.0)
			# The head follows the jet down from the far wall to the floor ahead of it.
			_jet_end = _breath_target()
			var to := _jet_end - _w(HEAD_PIVOT)
			var aim := atan2(to.y, to.x * _dir)  # as if it faced right
			_neck = lerp_angle(_neck, clampf(aim - HEAD_REST, -0.8, 0.8), 10.0 * delta)
			if fmod(_time, 0.05) < delta:
				Effects.sparks(get_parent(), _jet_end, COLOR_FIRE, 3, 80.0)
			if _timer <= 0.0:
				_enter(St.IDLE, 1.0)
		St.REAR:
			# Up on its hind legs, forefeet clawing the air.
			_tilt = lerp_angle(_tilt, -0.4, 5.0 * delta)
			_neck = lerp_angle(_neck, -0.4, 5.0 * delta)
			_jaw = lerpf(_jaw, 0.4, 5.0 * delta)
			if _timer <= 0.0:
				_enter(St.SLAM, 0.22)
		St.SLAM:
			_tilt = lerp_angle(_tilt, 0.0, 16.0 * delta)
			if _timer <= 0.0:
				_tilt = 0.0
				_shake = 0.5
				for i in 6:
					_debris(_w(Vector2(200, 131)) + Vector2(randf_range(-20, 20), -2))
				_rain_embers(p)
				_enter(St.IDLE, 1.6)
		St.TAIL_RAISE:
			# The tail lifts and rattles behind it.
			_relax(settle)
			_tail = lerp_angle(_tail, 0.7, 8.0 * delta) + sin(_time * 40.0) * 0.03
			if _timer <= 0.0:
				_enter(St.TAIL_LASH, 0.18)
		St.TAIL_LASH:
			_tail = lerp_angle(_tail, -0.12, 20.0 * delta)
			if _timer <= 0.0:
				_shake = 0.3
				var tip := _tail_tip()
				_spawn("fire_wave", Vector2(tip.x, _floor), Vector2(-_dir * 150.0, 0), 0.0, 3.0)
				_debris(Vector2(tip.x, _floor - 2))
				_enter(St.IDLE, 0.9)
		St.SLUMP:
			# It collapses; the fire piece tears out of its wing and floats down.
			_crouch = move_toward(_crouch, 1.0, delta / 0.8)
			_neck = lerp_angle(_neck, 0.5, 2.0 * delta)
			_tilt = lerp_angle(_tilt, 0.0, 4.0 * delta)
			_tail = lerp_angle(_tail, 0.0, 4.0 * delta)
			_jaw = lerpf(_jaw, 0.2, 3.0 * delta)
			if _piece_t < 0.0 and _timer < 1.8:
				_piece_t = 0.0
				_piece_from = _pin_point()
				_piece_rest = Vector2(clampf(_x - _dir * 30.0, _left + 40.0, _right - 40.0), _floor - TILE)
				_shake = 0.5
				Sfx.play("burst", -2.0)
				for i in 8:
					Effects.sparks(get_parent(), _piece_from, COLOR_FIRE, 4, 120.0)
			if _piece_t >= 0.0:
				_piece_t = minf(_piece_t + delta / 1.2, 1.0)
			if _timer <= 0.0:
				_enter(St.FLEE, 6.0)
		St.FLEE:
			# Free of the piece, it heaves up, roars, and bolts west out of the forge.
			_crouch = move_toward(_crouch, 0.0, 2.0 * delta)
			_neck = lerp_angle(_neck, -0.4, 4.0 * delta)
			_jaw = lerpf(_jaw, 0.5 if _timer > 5.2 else 0.0, 6.0 * delta)
			if _timer < 5.0:
				_dir = -1
				_walk(-300.0, delta, false)
				if fmod(_time, 0.08) < delta:
					_puff(_w(Vector2(120, 120)), Vector2(40, -20), 5.0)
			if _x < _left + 60.0:
				_alpha = move_toward(_alpha, 0.0, 4.0 * delta)
			if _alpha <= 0.0 or _timer <= 0.0:
				_alpha = 0.0
				_done = true
				Game.defeated[boss_id] = true
				_restore_camera()
				defeated.emit()
				set_physics_process(false)


## Easing back to standing at rest, breathing.
func _relax(settle: float) -> void:
	_crouch = move_toward(_crouch, 0.0, settle * 0.5)
	_tilt = lerp_angle(_tilt, 0.0, settle)
	_neck = lerp_angle(_neck, -0.05 + sin(_time * 1.6) * 0.04, settle)
	_jaw = lerpf(_jaw, 0.0, settle)
	_tail = lerp_angle(_tail, sin(_time * 1.1) * 0.06, settle)


func _walk(speed: float, delta: float, keep_in := true) -> void:
	_x += speed * delta
	if keep_in:
		_x = clampf(_x, _left + 90.0, _right - 90.0)
	_stride += delta * absf(speed) / 6.0


## Where the breath lands as it sweeps: from up the far wall down to the floor ahead of it.
func _breath_target() -> Vector2:
	var wall := _right if _dir > 0 else _left
	var far := Vector2(wall, _floor - JET_START_HEIGHT)
	var corner := Vector2(wall, _floor)
	var near := Vector2(_x + _dir * JET_END, _floor)
	# Down the wall in the first part of the sweep, then in along the floor.
	var down := absf(wall - near.x) / (absf(wall - near.x) + JET_START_HEIGHT)
	var t := 1.0 - down
	if _sweep < t:
		return far.lerp(corner, _sweep / t)
	return corner.lerp(near, (_sweep - t) / (1.0 - t))


func _rain_embers(p: Vector2) -> void:
	for i in 7:
		var x := clampf(p.x + (i - 3) * 44.0 + randf_range(-10, 10), _left + 12.0, _right - 12.0)
		_embers.append({"x": x, "t": 0.7 + absf(i - 3) * 0.14})


func _update_embers(delta: float) -> void:
	var fallen := []
	for ember in _embers:
		ember.t -= delta
		if ember.t <= 0.0:
			_spawn("ember", Vector2(ember.x, TILE * 1.5), Vector2.ZERO, 480.0, 2.5)
			fallen.append(ember)
	for ember in fallen:
		_embers.erase(ember)


func _update_boxes() -> void:
	var alive := _state not in [St.DORMANT, St.SLUMP, St.FLEE]
	var head_angle := (_neck + _tilt) * _dir
	_set_box(_head_box, alive, _head_point(), head_angle)
	_set_box(_body_box, alive, _body_point(), _tilt * _dir)
	_set_box(_legs_box, alive, _w(Vector2(160, 118)), _tilt * _dir)
	var tail_mid := _on_part(TAIL_PIVOT, _tail_angle(), Vector2(50, 98))
	var tail_angle := (_tail_angle() + _tilt) * _dir + (PI if _dir < 0 else 0.0)
	_set_box(_tail_box, _state == St.TAIL_LASH, tail_mid, tail_angle)
	var jet_on := _state == St.BREATH
	if jet_on:
		var from := _mouth()
		var shape: RectangleShape2D = _jet_box.get_child(0).shape
		shape.size = Vector2(from.distance_to(_jet_end), JET_WIDTH)
		_set_box(_jet_box, true, (from + _jet_end) / 2.0, (_jet_end - from).angle())
	else:
		_set_box(_jet_box, false)


# --- Effects ---

func _puff(at: Vector2, vel: Vector2, size: float) -> void:
	_smoke.append({"pos": at, "vel": vel + Vector2(randf_range(-4, 4), randf_range(-4, 4)),
		"life": 1.2, "size": size})


func _update_smoke(delta: float) -> void:
	for s in _smoke:
		s.pos += s.vel * delta
		s.life -= delta
		s.size += delta * 4.0
	_smoke = _smoke.filter(func(s: Dictionary) -> bool: return s.life > 0.0)
	if _done:
		queue_redraw()


func _debris(at: Vector2) -> void:
	var room := get_parent()
	if room.has_method("_spawn_debris"):
		room._spawn_debris(at, Color(0.35, 0.3, 0.28))


func _spawn(p_kind: String, pos: Vector2, vel: Vector2, grav: float, p_life: float) -> void:
	var proj := Projectile.new()
	proj.kind = p_kind
	proj.velocity = vel
	proj.fall_accel = grav
	proj.life = p_life
	proj.position = pos
	get_parent().add_child(proj)


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


## Where its reward appears: the fire piece, where it floated down.
func reward_point() -> Vector2:
	return _piece_rest


# --- Art ---

func _draw() -> void:
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	if _state == St.DORMANT:
		tint = Color(0.7, 0.66, 0.64)
	tint.a = _alpha
	for ember in _embers:
		# A glow on the floor where each ember will land, brightening as it nears.
		var grow := clampf(1.0 - ember.t / 0.9, 0.2, 1.0)
		_draw_ellipse(Vector2(ember.x, _floor) - position, Vector2(4.0 + 6.0 * grow, 2.0), Color(COLOR_FIRE, 0.25 + 0.3 * grow))
	if _alpha > 0.0:
		_draw_ellipse(Vector2(_x, _floor) - position, Vector2(70, 4), Color(COLOR_SHADOW, COLOR_SHADOW.a * _alpha))
		_draw_drake(tint)
	if _piece_t < 0.0:
		_draw_piece_pinned()
	elif not _done:
		_draw_piece_free()
	for s in _smoke:
		draw_circle(s.pos - position, s.size, Color(COLOR_SMOKE, 0.5 * clampf(s.life, 0.0, 1.0)))
	if _state == St.BREATH:
		_draw_jet()


func _draw_drake(tint: Color) -> void:
	var swing := sin(_stride) * 0.22
	var squash := clampf((LEG_LENGTH - CROUCH_DROP * _crouch) / LEG_LENGTH, 0.35, 1.0)
	var lift := 0.0
	if _state == St.REAR or _state == St.SLAM:
		lift = -_tilt * 0.6  # forelegs reach forward as it rears
	_draw_part(TAIL, TAIL_PIVOT, _tail_angle(), tint)
	_draw_part(HIND, HIND_PIVOT, swing, tint, squash)
	_draw_part(FRONT, FRONT_PIVOT, -swing - lift, tint, 1.0 if lift > 0.0 else squash)
	# The inside of its mouth shows as the jaw drops.
	if _jaw > 0.05:
		var glow := COLOR_MOUTH
		if _state in [St.BREATH_WINDUP, St.BREATH]:
			glow = COLOR_FIRE
		draw_colored_polygon(PackedVector2Array([
			_on_part(HEAD_PIVOT, _neck, JAW_PIVOT) - position,
			_on_part(HEAD_PIVOT, _neck, SNOUT_TIP) - position,
			_jaw_point(JAW_TIP) - position,
		]), Color(glow, tint.a))
	var jaw_pivot := _on_part(HEAD_PIVOT, _neck, JAW_PIVOT)
	draw_set_transform(jaw_pivot - position, (_neck + _jaw + _tilt) * _dir, Vector2(SCALE * _dir, SCALE))
	draw_texture(JAW, -JAW_PIVOT, tint)
	_draw_part(HEAD, HEAD_PIVOT, _neck, tint)
	_draw_part(BODY, BODY_PIVOT, 0.0, tint)
	draw_set_transform(Vector2.ZERO)
	# Its eyes: dark while it sleeps, glowing otherwise; its throat lit before the breath.
	if _state != St.DORMANT:
		var eye := _on_part(HEAD_PIVOT, _neck, EYE) - position
		draw_circle(eye, 3.5, Color(COLOR_EYES, (0.3 + 0.15 * sin(_time * 5.0)) * tint.a))
	if _state == St.BREATH_WINDUP:
		var grow := clampf(1.0 - _timer / 0.9, 0.0, 1.0)
		var throat := _on_part(HEAD_PIVOT, _neck, Vector2(200, 78)) - position
		draw_circle(throat, 6.0 + 8.0 * grow, Color(COLOR_FIRE, 0.25 * grow))
		draw_circle(_mouth() - position, 3.0 + 4.0 * grow, Color(COLOR_FIRE_HOT, 0.5 * grow))


func _jaw_point(art: Vector2) -> Vector2:
	var pivot := _on_part(HEAD_PIVOT, _neck, JAW_PIVOT)
	var off := (art - JAW_PIVOT) * SCALE
	off.x *= _dir
	return pivot + off.rotated((_neck + _jaw + _tilt) * _dir)


## One part, turned about its pivot by `angle` (as if facing right); `squash` shortens it
## from the pivot down (legs bending under it).
func _draw_part(tex: Texture2D, pivot: Vector2, angle: float, tint: Color, squash := 1.0) -> void:
	draw_set_transform(_w(pivot) - position, (angle + _tilt) * _dir, Vector2(SCALE * _dir, SCALE * squash))
	draw_texture(tex, -pivot, tint)
	draw_set_transform(Vector2.ZERO)


## The fire piece driven down through its wing, glowing.
func _draw_piece_pinned() -> void:
	var at := _pin_point() - position
	var angle := (deg_to_rad(110.0) + _tilt) * _dir
	var pulse := 0.6 + 0.4 * sin(_time * 3.0)
	draw_circle(at, 9.0, Color(COLOR_PIECE, 0.18 * pulse * _alpha))
	draw_set_transform(at, angle if _dir > 0 else PI - angle)
	_draw_blade(Color(COLOR_PIECE, _alpha))
	draw_set_transform(Vector2.ZERO)


## Torn free: arcing out and spinning, then settling where it waits.
func _draw_piece_free() -> void:
	var t := _piece_t
	var at := _piece_from.lerp(_piece_rest, ease(t, -1.8)) - Vector2(0, sin(t * PI) * 50.0) - position
	draw_circle(at, 10.0, Color(COLOR_PIECE, 0.3))
	draw_set_transform(at, t * TAU * 3.0)
	_draw_blade(COLOR_PIECE)
	draw_set_transform(Vector2.ZERO)


## A length of broken blade: point one way, jagged break the other.
func _draw_blade(color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(14, 0), Vector2(4, -3), Vector2(-10, -3), Vector2(-8, 0), Vector2(-11, 2), Vector2(4, 3),
	]), color)
	draw_line(Vector2(-8, 0), Vector2(12, 0), Color(1, 0.95, 0.8, color.a), 1.0)


## The jet of fire from its mouth to where it lands: flickering blobs swelling outward.
func _draw_jet() -> void:
	var from := _mouth() - position
	var to := _jet_end - position
	var length := from.distance_to(to)
	var steps := int(length / 6.0)
	for i in steps:
		var t := float(i) / maxf(1.0, steps - 1)
		var at := from.lerp(to, t) + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		var r := lerpf(3.0, JET_WIDTH * 0.6, t) * randf_range(0.8, 1.2)
		draw_circle(at, r + 2.0, Color(COLOR_FIRE, 0.35))
		draw_circle(at, r, Color(COLOR_FIRE_HOT if randf() < 0.4 else COLOR_FIRE, 0.85))
	# A splash of fire where it lands.
	for i in 5:
		draw_circle(to + Vector2(randf_range(-10, 10), randf_range(-8, 2)), randf_range(3, 7), Color(COLOR_FIRE, 0.7))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
