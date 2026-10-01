extends Node2D
## The Frost Colossus, the Frozen village's boss: an ice golem, fought twice. Built from parts
## (art/bosses/colossus_*.png) that the code poses: a chest and head, arms, legs.
##
## Phase 1, the Frost arena: it's frozen into the ice wall at the end of the cavern with the
## ice piece driven into its chest; only its chest, head and arms are out. It can't move, so
## the fight is about its reach. In a fixed order:
## - Fist slam: it raises an arm; a shadow and falling frost mark where the fist will land.
##   The fist stays wedged in the floor for a moment: a step up to the glowing crack in its
##   chest, its weak point.
## - Icicle roar: icicles fall from the ceiling; shadows on the floor show where.
## - Frost breath: a freezing wave runs out along the floor; jump it.
## Beaten, cracks run through it, its arms break off and shatter, chunks fall away, and it
## slumps dead in the wall; the ice piece comes free of its chest.
##
## Phase 2, the Frost throne: broken out of the wall. It rises out of the floor body-first,
## then its legs burst out and it stands. Then, in a fixed order:
## - Charge: it crouches low and charges across the arena. Its belly clears the floor by less
##   than Storm's height: the way past is to slide between its legs. Hitting the far wall
##   stuns it to its knees, chest low: hit the crack.
## - Stomp: it lifts a foot and stamps; shockwaves run both ways along the floor.
## - Ice pillars: the floor swells, then pillars of ice burst up around Storm. Climb them to
##   reach its chest.
## Beaten, it shatters.
##
## The node's origin is the room's B marker, on the arena's floor.

signal defeated
## Sent when it wakes: the room bars its doors then.
signal engaged

const Projectile := preload("res://scripts/projectile.gd")
const TORSO := preload("res://art/bosses/colossus_torso.png")
const ARM := preload("res://art/bosses/colossus_arm.png")
const LEG := preload("res://art/bosses/colossus_leg.png")

const TILE := 16
const LAYER_WORLD := 1
const LAYER_ENEMY := 4
## The chest wound in the torso art (128x128), and each part's pivot in its own art.
const CRACK := Vector2(62, 72)
const ARM_PIVOT := Vector2(12, 28)
const ARM_REACH := 100.0
const LEG_PIVOT := Vector2(30, 4)
const LEG_LENGTH := 90.0
## Phase 1's arms are huge next to the rest of it; a fist slam can stretch them a little.
const ARM_SCALE_1 := 1.4
const COLOR_FROST := Color(0.75, 0.92, 1.0)
const COLOR_SHADOW := Color(0.02, 0.05, 0.1, 0.55)
const COLOR_EYES := Color(0.45, 0.95, 1.0)
const PATTERN_1 := ["slam", "roar", "slam", "breath"]
const PATTERN_2 := ["charge", "stomp", "pillars", "charge", "stomp"]

enum St {
	DORMANT, WAKE, IDLE, AIM, STRIKE, WEDGED, RETRACT, ROAR, BREATH,
	CROUCH, CHARGE, STUNNED, LIFT, PILLARS, SLUMP, SLUMPED, SHATTER,
}

## Set by the room before it's added (see Rooms.BOSSES).
var boss_id := ""
var kind := "colossus"
var phase := 1
var title := ""
var max_hp := 14
## Phase 1 already beaten: it stays slumped in the wall, still, as scenery.
var dead := false

var hp := 0

var _state := St.DORMANT
var _timer := 0.0
var _time := 0.0
var _flash := 0.0
var _shake := 0.0
var _cam_base := Vector2.ZERO
var _move := 0
var _attack := ""
var _floor := 0.0
var _left := 0.0
var _right := 0.0
## Phase 1: the face of the wall it's frozen into; the arm's angle and stretch.
var _face := 0.0
var _arm_angle := deg_to_rad(160.0)
var _arm_stretch := 1.0
var _arm_from := 0.0
var _arm_to := 0.0
var _stretch_from := 1.0
var _stretch_to := 1.0
var _slump := 0.0
var _target := Vector2.ZERO
## Icicles about to fall: {x, t} (t counts down; the shadow grows as it does).
var _icicles: Array[Dictionary] = []
## Phase 2: where it stands, which way it faces, its stride, how low it's crouched or knelt.
var _x := 0.0
var _dir := -1
var _stride := 0.0
var _crouch := 0.0
var _kneel := 0.0
var _lift := 0.0
## Phase 2's ice pillars: {x, rise (0..1), life, body}; and its shattered pieces.
var _pillars: Array[Dictionary] = []
var _pieces: Array[Dictionary] = []
## Phase 2's entrance: how far its body has risen out of the floor, and whether its legs
## have burst out yet.
var _rise := 0.0
var _legs_out := false
## Phase 2 turns only now and then (not every time Storm crosses under it).
var _turn_wait := 0.0
## Phase 1's death: which arms have broken off.
var _arms_off := [false, false]

var _chest: Hitbox
var _fist: Hitbox
var _charge_box: Hitbox
var _feet: Array[Hitbox] = []
var _fist_ledge: StaticBody2D


class Hitbox extends Area2D:
	var boss: Node
	## A weak point: struck, it hurts the boss; touched, it doesn't hurt Storm.
	var harmless := false

	func take_hit(damage: int, from_dir: Vector2) -> void:
		if harmless:
			boss.take_hit(damage, from_dir)


func _ready() -> void:
	hp = max_hp
	z_index = -1  # behind the tiles: in phase 1 its back half is hidden in the wall
	_floor = position.y
	_measure()
	_x = position.x
	_chest = _make_box(Vector2(28, 28), true)
	_fist = _make_box(Vector2(40, 30), false)
	_charge_box = _make_box(Vector2(84, 80), false)
	for i in 2:
		_feet.append(_make_box(Vector2(26, 16), false))
	_fist_ledge = StaticBody2D.new()
	_fist_ledge.collision_layer = 0
	_fist_ledge.collision_mask = 0
	_fist_ledge.top_level = true
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 12)
	var col := CollisionShape2D.new()
	col.shape = shape
	_fist_ledge.add_child(col)
	add_child(_fist_ledge)
	_set_box(_chest, false)
	_set_box(_fist, false)
	_set_box(_charge_box, false)
	for foot in _feet:
		_set_box(foot, false)
	if dead:
		_slump = 1.0
		_arms_off = [true, true]
		_state = St.SLUMPED


func _measure() -> void:
	var room := get_parent()
	var cx := int(position.x / TILE)
	var cy := int(position.y / TILE) - 1
	var x := cx
	while x < room.size_tiles.x - 1 and room._cell(x + 1, cy) != "#":
		x += 1
	_right = (x + 1) * TILE
	_face = _right
	x = cx
	while x > 0 and room._cell(x - 1, cy) != "#":
		x -= 1
	_left = x * TILE


func _make_box(size: Vector2, weak_point: bool) -> Hitbox:
	var box := Hitbox.new()
	box.boss = self
	box.harmless = weak_point
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


func _set_box(box: Area2D, on: bool, at := Vector2.ZERO) -> void:
	box.collision_layer = LAYER_ENEMY if on else 0
	if on:
		box.global_position = get_parent().to_global(at)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func shock_point() -> Vector2:
	return get_parent().to_global(_chest_point())


func take_hit(damage: int, _from_dir: Vector2) -> void:
	if _state in [St.DORMANT, St.WAKE, St.SLUMP, St.SLUMPED, St.SHATTER]:
		return
	hp -= damage
	_flash = 0.1
	if hp <= 0:
		hp = 0
		remove_from_group("shock_target")
		remove_from_group("boss")
		for box in [_chest, _fist, _charge_box] + _feet:
			_set_box(box, false)
		_fist_ledge.collision_layer = 0
		_enter(St.SLUMP if phase == 1 else St.SHATTER, 2.6 if phase == 1 else 1.8)
		if phase >= 2:
			_shatter()


# --- Geometry ---

func _torso_center() -> Vector2:
	if phase == 1:
		return Vector2(_face - 44.0, _floor - 92.0 + 26.0 * _slump)
	if not _legs_out:
		# Rising out of the floor, legs still buried.
		return Vector2(_x, lerpf(_floor + 80.0, _floor - 46.0, _rise))
	var hip_y := _floor - LEG_LENGTH + 46.0 * _crouch + 34.0 * _kneel
	return Vector2(_x, hip_y - 46.0)


func _chest_point() -> Vector2:
	var off := CRACK - Vector2(64, 64)
	if phase >= 2 and _dir > 0:
		off.x = -off.x
	return _torso_center() + off


func _shoulder() -> Vector2:
	return Vector2(_face - 70.0, _floor - 100.0 + 26.0 * _slump)


func _fist_point() -> Vector2:
	return _shoulder() + Vector2.from_angle(_arm_angle) * ARM_REACH * ARM_SCALE_1 * _arm_stretch


# --- Behaviour ---

func _physics_process(delta: float) -> void:
	_time += delta
	_flash -= delta
	_timer -= delta
	if _state == St.SLUMPED:
		queue_redraw()
		return
	var player := _player()
	var p := player.position if player else Vector2(position.x, _floor)
	_update_icicles(delta)
	if phase == 1:
		_phase_1(p, delta)
	else:
		_phase_2(p, delta)
	_update_shake(delta)
	queue_redraw()


func _enter(state: St, time := 0.0) -> void:
	_state = state
	_timer = time


func _wake() -> void:
	engaged.emit()
	add_to_group("boss")
	add_to_group("shock_target")
	_shake = 0.8
	_enter(St.WAKE, 1.4)


func _next_attack() -> void:
	var pattern: Array = PATTERN_1 if phase == 1 else PATTERN_2
	_attack = pattern[_move % pattern.size()]
	_move += 1


func _phase_1(p: Vector2, delta: float) -> void:
	var fist_on := false
	match _state:
		St.DORMANT:
			if p.x > _face - 13.0 * TILE:
				_wake()
		St.WAKE:
			# The frost on it cracks; it pulls its arms free of the wall.
			if fmod(_time, 0.1) < delta:
				_frost(_torso_center() + Vector2(randf_range(-40, 20), randf_range(-50, 40)))
			if _timer <= 0.0:
				_enter(St.IDLE, 1.0)
		St.IDLE:
			_arm_angle = lerp_angle(_arm_angle, deg_to_rad(160.0) + sin(_time * 1.5) * 0.05, 4.0 * delta)
			_arm_stretch = move_toward(_arm_stretch, 1.0, delta)
			if _timer <= 0.0:
				_next_attack()
				match _attack:
					"slam":
						_aim_slam(p)
					"roar":
						_roar(p)
					"breath":
						_enter(St.BREATH, 0.9)
		St.AIM:
			# Arm raised; the shadow of the fist grows where it'll land.
			_arm_angle = lerp_angle(_arm_angle, deg_to_rad(215.0), 6.0 * delta)
			if fmod(_time, 0.06) < delta:
				_frost(Vector2(_target.x + randf_range(-14, 14), _floor - 120.0))
			if _timer <= 0.0:
				_arm_from = _arm_angle
				_stretch_from = _arm_stretch
				var to := _target - _shoulder()
				_arm_to = to.angle()
				_stretch_to = clampf(to.length() / (ARM_REACH * ARM_SCALE_1), 0.7, 1.3)
				_enter(St.STRIKE, 0.18)
		St.STRIKE:
			var t := clampf(1.0 - _timer / 0.18, 0.0, 1.0)
			_arm_angle = lerp_angle(_arm_from, _arm_to, t * t)
			_arm_stretch = lerpf(_stretch_from, _stretch_to, t)
			fist_on = true
			if _timer <= 0.0:
				_shake = 0.35
				for i in 5:
					_frost(_fist_point() + Vector2(randf_range(-16, 16), 10))
				_enter(St.WEDGED, 2.2)
		St.WEDGED:
			# Stuck in the floor: a step up to its chest.
			if _timer <= 0.0:
				_enter(St.RETRACT, 0.6)
		St.RETRACT:
			_arm_angle = lerp_angle(_arm_angle, deg_to_rad(160.0), 5.0 * delta)
			_arm_stretch = move_toward(_arm_stretch, 1.0, 2.0 * delta)
			if _timer <= 0.0:
				_enter(St.IDLE, 0.9)
		St.ROAR:
			if _timer <= 0.0:
				_enter(St.IDLE, 0.6)
		St.BREATH:
			# Frost gathers at its mouth, then a freezing wave runs out along the floor.
			if fmod(_time, 0.05) < delta:
				_frost(_torso_center() + Vector2(-46, -40))
			if _timer <= 0.0:
				_spawn("frost_wave", Vector2(_face - 110.0, _floor), Vector2(-150.0, 0), 0.0, 3.5)
				_enter(St.IDLE, 1.2)
		St.SLUMP:
			# Cracks run through it; one arm then the other breaks off and shatters on the
			# floor; chunks fall away as it slumps dead into the wall.
			_slump = minf(_slump + delta / 2.2, 1.0)
			_shake = maxf(_shake, 0.06)
			_arm_angle = lerp_angle(_arm_angle, deg_to_rad(125.0), 2.0 * delta)
			_arm_stretch = move_toward(_arm_stretch, 1.0, delta)
			if not _arms_off[0] and _timer < 2.0:
				_arms_off[0] = true
				_break_arm(_shoulder(), _arm_angle, ARM_SCALE_1)
			if not _arms_off[1] and _timer < 1.3:
				_arms_off[1] = true
				_break_arm(_shoulder() + Vector2(34, -8), _arm_angle - 0.25, ARM_SCALE_1 * 0.9)
			if fmod(_time, 0.12) < delta:
				_chip(_torso_center() + Vector2(randf_range(-40, 10), randf_range(-40, 40)))
			_update_pieces(delta)
			if _timer <= 0.0:
				Game.defeated[boss_id] = true
				_restore_camera()
				defeated.emit()
				_enter(St.SLUMPED)
	_set_box(_chest, _state not in [St.DORMANT, St.WAKE, St.SLUMP], _chest_point())
	_set_box(_fist, fist_on, _fist_point())
	var wedged := _state == St.WEDGED
	_fist_ledge.collision_layer = LAYER_WORLD if wedged else 0
	if wedged:
		_fist_ledge.global_position = get_parent().to_global(_fist_point() + Vector2(0, -6))


func _aim_slam(p: Vector2) -> void:
	# Where the fist can land: a band of floor out in front of it.
	var near := _shoulder().x - 60.0
	var far := _shoulder().x - 160.0
	_target = Vector2(clampf(p.x, far, near), _floor - 22.0)
	_enter(St.AIM, 0.9)


func _roar(p: Vector2) -> void:
	_shake = 0.5
	for i in 6:
		var x := clampf(p.x + (i - 2.5) * 34.0 + randf_range(-8, 8), _left + 10, _face - 10)
		_icicles.append({"x": x, "t": 0.9 + i * 0.12})
	_enter(St.ROAR, 1.6)


func _update_icicles(delta: float) -> void:
	var fallen := []
	for ice in _icicles:
		ice.t -= delta
		if ice.t <= 0.0:
			_spawn("icicle", Vector2(ice.x, TILE * 1.5), Vector2.ZERO, 520.0, 2.5)
			fallen.append(ice)
	for ice in fallen:
		_icicles.erase(ice)


# --- Phase 2 ---

func _phase_2(p: Vector2, delta: float) -> void:
	var feet_on := true
	var charge_on := false
	match _state:
		St.DORMANT:
			feet_on = false
			if p.x > _left + 8.0 * TILE:
				_wake()
				_enter(St.WAKE, 2.8)
		St.WAKE:
			# Up out of the floor body-first, ice and earth bursting around it; then its legs
			# burst out and it stands.
			feet_on = false
			_dir = -1 if p.x < _x else 1
			_rise = minf(_rise + delta / 1.6, 1.0)
			if not _legs_out and fmod(_time, 0.05) < delta:
				_frost(Vector2(_x + randf_range(-50, 50), _floor - 2))
			if not _legs_out and _timer <= 1.0:
				_legs_out = true
				_kneel = 1.0
				_shake = 0.7
				for i in 10:
					_frost(Vector2(_x + randf_range(-40, 40), _floor - randf_range(0, 30)))
			if _legs_out:
				_kneel = move_toward(_kneel, 0.0, 1.6 * delta)
			if _timer <= 0.0:
				_enter(St.IDLE, 1.2)
		St.IDLE:
			# Plods toward Storm.
			_face_toward(p, delta)
			_kneel = move_toward(_kneel, 0.0, 2.0 * delta)
			_crouch = move_toward(_crouch, 0.0, 2.0 * delta)
			if absf(p.x - _x) > 50.0:
				_x = clampf(_x + _dir * 34.0 * delta, _left + 50, _right - 50)
				_stride += delta * 5.0
			if _timer <= 0.0:
				_next_attack()
				match _attack:
					"charge":
						_enter(St.CROUCH, 1.0)
					"stomp":
						_enter(St.LIFT, 0.7)
					"pillars":
						_raise_pillars(p)
		St.CROUCH:
			# Crouching low, scraping a foot: it's about to charge.
			_crouch = move_toward(_crouch, 1.0, 2.5 * delta)
			if _timer > 0.6:
				_face_toward(p, delta)
			if fmod(_time, 0.08) < delta:
				_frost(Vector2(_x - _dir * 30.0, _floor - 4))
			if _timer <= 0.0:
				_enter(St.CHARGE, 3.0)
		St.CHARGE:
			feet_on = false
			charge_on = true
			_x += _dir * 230.0 * delta
			_stride += delta * 14.0
			if fmod(_time, 0.05) < delta:
				_frost(Vector2(_x - _dir * 40.0, _floor - 4))
			var edge := _left + 50.0 if _dir < 0 else _right - 50.0
			if (_dir < 0 and _x <= edge) or (_dir > 0 and _x >= edge) or _timer <= 0.0:
				_x = clampf(_x, _left + 50, _right - 50)
				_shake = 0.5
				_enter(St.STUNNED, 1.8)
		St.STUNNED:
			# Knocked to its knees, chest low: the moment to strike.
			feet_on = false
			_crouch = move_toward(_crouch, 0.0, 3.0 * delta)
			_kneel = move_toward(_kneel, 1.0 if _timer > 0.3 else 0.0, 4.0 * delta)
			if _timer <= 0.0:
				_enter(St.IDLE, 1.0)
		St.LIFT:
			# A foot raised high, then stamped down: shockwaves both ways.
			_lift = move_toward(_lift, 1.0, 3.0 * delta)
			if _timer <= 0.0:
				_lift = 0.0
				_shake = 0.6
				for d in [-1, 1]:
					_spawn("frost_wave", Vector2(_x + d * 40.0, _floor), Vector2(d * 150.0, 0), 0.0, 3.0)
				_enter(St.STUNNED, 1.0)
		St.PILLARS:
			if _timer <= 0.0:
				_enter(St.IDLE, 1.2)
		St.SHATTER:
			feet_on = false
			_update_pieces(delta)
			if _timer <= 0.0:
				Game.defeated[boss_id] = true
				_restore_camera()
				defeated.emit()
				queue_free()
	_update_pillars(delta)
	var feet := _foot_points()
	for i in 2:
		_set_box(_feet[i], feet_on, feet[i] + Vector2(0, -8))
	# Charging, its body is low but clears the floor by less than Storm stands: slide under.
	_set_box(_charge_box, charge_on, Vector2(_x, _floor - 14.0 - 40.0))
	_set_box(_chest, _state not in [St.DORMANT, St.WAKE, St.SHATTER], _chest_point())


## Turns to face Storm, but only once he's clearly on its other side and not too often, so
## it doesn't spin back and forth when he's right under it.
func _face_toward(p: Vector2, delta: float) -> void:
	_turn_wait -= delta
	var want := _dir
	if p.x < _x - 36.0:
		want = -1
	elif p.x > _x + 36.0:
		want = 1
	if want != _dir and _turn_wait <= 0.0:
		_dir = want
		_turn_wait = 0.6


func _hip_points() -> Array:
	var c := _torso_center() + Vector2(0, 46)
	return [c + Vector2(_dir * 18.0, 0), c + Vector2(-_dir * 18.0, 0)]


## Each leg's swing (radians) for walking, charging (splayed low), kneeling or stomping.
func _leg_angles() -> Array:
	var swing := sin(_stride) * 0.35 * (1.0 - _kneel)
	var front := swing + _crouch * 0.7 * _dir - _lift * 0.9 * _dir
	var back := -swing - _crouch * 0.7 * _dir
	if _kneel > 0.0:
		front = lerpf(front, 0.9 * _dir, _kneel)
		back = lerpf(back, -1.2 * _dir, _kneel)
	return [front, back]


func _foot_points() -> Array:
	var hips := _hip_points()
	var angles := _leg_angles()
	var feet := []
	for i in 2:
		feet.append(hips[i] + Vector2(0, LEG_LENGTH).rotated(-angles[i]))
	return feet


func _raise_pillars(p: Vector2) -> void:
	_shake = 0.4
	for off in [-70.0, 0.0, 70.0]:
		var x := clampf(p.x + off, _left + 24, _right - 24)
		_pillars.append({"x": x, "rise": 0.0, "wait": 0.8, "life": 5.0, "body": null})
	_enter(St.PILLARS, 1.4)


func _update_pillars(delta: float) -> void:
	var gone := []
	for pillar in _pillars:
		if pillar.wait > 0.0:
			pillar.wait -= delta
			if fmod(_time, 0.06) < delta:
				_frost(Vector2(pillar.x + randf_range(-10, 10), _floor - 2))
			continue
		pillar.life -= delta
		pillar.rise = clampf(pillar.rise + delta / 0.25, 0.0, 1.0) if pillar.life > 0.5 else clampf(pillar.life / 0.5, 0.0, 1.0)
		var height: float = 84.0 * pillar.rise
		if pillar.body == null:
			var body := StaticBody2D.new()
			body.collision_layer = LAYER_WORLD
			body.collision_mask = 0
			body.top_level = true
			var shape := RectangleShape2D.new()
			shape.size = Vector2(22, 1)
			var col := CollisionShape2D.new()
			col.shape = shape
			body.add_child(col)
			add_child(body)
			pillar.body = body
		var shape: RectangleShape2D = pillar.body.get_child(0).shape
		shape.size = Vector2(22, maxf(1.0, height))
		pillar.body.global_position = get_parent().to_global(Vector2(pillar.x, _floor - height / 2.0))
		if pillar.life <= 0.0:
			pillar.body.queue_free()
			gone.append(pillar)
	for pillar in gone:
		_pillars.erase(pillar)


func _shatter() -> void:
	_shake = 1.0
	var c := _torso_center()
	for i in 26:
		_pieces.append({
			"pos": c + Vector2(randf_range(-50, 50), randf_range(-60, 90)),
			"vel": Vector2(randf_range(-160, 160), randf_range(-260, -40)),
			"size": randf_range(5, 14), "rot": randf() * TAU, "spin": randf_range(-8, 8),
		})
	for pillar in _pillars:
		pillar.life = minf(pillar.life, 0.5)


## An arm breaking off: chunks along its length that fall and scatter.
func _break_arm(shoulder: Vector2, angle: float, scale_: float) -> void:
	_shake = 0.5
	var along := Vector2.from_angle(angle)
	for i in 10:
		var at := shoulder + along * (i + 0.5) * ARM_REACH * scale_ / 10.0
		_pieces.append({
			"pos": at + Vector2(randf_range(-8, 8), randf_range(-8, 8)),
			"vel": Vector2(randf_range(-60, 60), randf_range(-120, 0)),
			"size": randf_range(8, 16), "rot": randf() * TAU, "spin": randf_range(-6, 6),
		})


## A chip of ice falling off it.
func _chip(at: Vector2) -> void:
	_pieces.append({
		"pos": at, "vel": Vector2(randf_range(-40, 40), randf_range(-60, 0)),
		"size": randf_range(4, 9), "rot": randf() * TAU, "spin": randf_range(-6, 6),
	})


func _update_pieces(delta: float) -> void:
	for piece in _pieces:
		piece.vel.y += 700.0 * delta
		piece.pos += piece.vel * delta
		piece.rot += piece.spin * delta
		if piece.pos.y > _floor - piece.size * 0.5:
			piece.pos.y = _floor - piece.size * 0.5
			piece.vel = Vector2(piece.vel.x * 0.5, -piece.vel.y * 0.25)
			piece.spin *= 0.5


# --- Effects ---

func _frost(at: Vector2) -> void:
	var room := get_parent()
	if room.has_method("_spawn_debris"):
		room._spawn_debris(at, COLOR_FROST)


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


## Where its reward appears (the room puts the pickup here): the ice piece comes free of its
## chest in phase 1.
func reward_point() -> Vector2:
	if phase >= 2:
		return Vector2(_x, _floor - TILE)  # shattered: it drops where it stood
	return _chest_point() + Vector2(-10, 4)


# --- Art ---

func _draw() -> void:
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	for ice in _icicles:
		var grow := clampf(1.0 - ice.t / 0.9, 0.2, 1.0)
		_draw_ellipse(Vector2(ice.x, _floor) - position, Vector2(4.0 + 6.0 * grow, 2.0), COLOR_SHADOW)
	if phase == 1:
		_draw_phase_1(tint)
	else:
		_draw_phase_2(tint)


func _draw_phase_1(tint: Color) -> void:
	if _state == St.AIM:
		var grow := clampf(1.0 - _timer / 0.9, 0.0, 1.0)
		_draw_ellipse(Vector2(_target.x, _floor) - position, Vector2(10.0 + 14.0 * grow, 3.0), COLOR_SHADOW)
	var dim := 0.55 if _state in [St.DORMANT, St.SLUMPED] else 1.0
	if _state == St.SLUMP:
		dim = lerpf(1.0, 0.55, _slump)
	var body_tint := Color(tint.r * dim, tint.g * dim, tint.b * dim)
	# The back arm, behind the body; then the chest and head; then the front arm.
	if not _arms_off[1]:
		_draw_arm(_shoulder() + Vector2(34, -8), _arm_angle - 0.25, ARM_SCALE_1 * 0.9, 1.0,
			body_tint.darkened(0.3), true)
	var c := _torso_center() - position
	draw_texture(TORSO, c - Vector2(64, 64), body_tint)
	if _state in [St.SLUMP, St.SLUMPED]:
		_draw_cracks(c, 1.0 if _state == St.SLUMPED else _slump)
	_draw_eyes(c)
	if not _arms_off[0]:
		_draw_arm(_shoulder(), _arm_angle, ARM_SCALE_1, _arm_stretch, body_tint, true)
	_draw_pieces()


func _draw_phase_2(tint: Color) -> void:
	if _state == St.DORMANT:
		return  # buried under the floor
	if _state == St.SHATTER:
		_draw_pieces()
		return
	for pillar in _pillars:
		if pillar.wait > 0.0:
			var grow := clampf(1.0 - pillar.wait / 0.8, 0.0, 1.0)
			_draw_ellipse(Vector2(pillar.x, _floor) - position, Vector2(6.0 + 6.0 * grow, 2.0 + 3.0 * grow), Color(0.6, 0.85, 1.0, 0.6))
		else:
			var h: float = 84.0 * pillar.rise
			if h < 8.0:
				continue
			var base := Vector2(pillar.x, _floor) - position
			draw_colored_polygon(PackedVector2Array([
				base + Vector2(-11, 0), base + Vector2(-9, -h + 6), base + Vector2(0, -h),
				base + Vector2(9, -h + 6), base + Vector2(11, 0),
			]), Color(0.6, 0.84, 0.98, 0.95))
			draw_line(base + Vector2(-5, -4), base + Vector2(-3, -h + 10), COLOR_FROST, 2.0)
	var flip := _dir > 0  # the art faces left
	var hips := _hip_points()
	var angles := _leg_angles()
	# Back leg and arm behind; body; front leg and arm in front. The arms hang down and a
	# little forward, knuckles toward where it faces.
	var swing := sin(_stride) * 0.15
	if _legs_out:
		_draw_leg(hips[1], angles[1], tint.darkened(0.3))
	var c := _torso_center() - position
	_draw_arm(_torso_center() + Vector2(_dir * -26.0, -34.0), PI / 2.0 - _dir * (0.2 + swing), 0.95, 1.0,
		tint.darkened(0.3), _dir < 0)
	draw_set_transform(c, 0.0, Vector2(-1 if flip else 1, 1))
	draw_texture(TORSO, -Vector2(64, 64), tint)
	draw_set_transform(Vector2.ZERO)
	_draw_eyes(c)
	if _legs_out:
		_draw_leg(hips[0], angles[0], tint)
	_draw_arm(_torso_center() + Vector2(_dir * 30.0, -30.0), PI / 2.0 - _dir * (0.3 - swing), 1.0, 1.0,
		tint, _dir < 0)


## An arm from its shoulder, pointing along `angle` (fist at the far end). The art points
## right (fist on the right); `flip_y` mirrors it so the knuckles face the way it faces.
func _draw_arm(shoulder: Vector2, angle: float, scale_: float, stretch: float, tint: Color, flip_y: bool) -> void:
	draw_set_transform(shoulder - position, angle, Vector2(scale_ * stretch, -scale_ if flip_y else scale_))
	draw_texture(ARM, -ARM_PIVOT, tint)
	draw_set_transform(Vector2.ZERO)


func _draw_leg(hip: Vector2, angle: float, tint: Color) -> void:
	draw_set_transform(hip - position, -angle, Vector2.ONE)
	draw_texture(LEG, -LEG_PIVOT, tint)
	draw_set_transform(Vector2.ZERO)


## Its eyes: dark while it sleeps or after it falls, glowing otherwise.
func _draw_eyes(c: Vector2) -> void:
	if _state in [St.DORMANT, St.SLUMPED] or (_state == St.SLUMP and _slump > 0.6):
		return
	var glow := 0.6 + 0.4 * sin(_time * 4.0)
	draw_circle(c + Vector2(-34, -44), 5.0, Color(COLOR_EYES, 0.25 * glow))


func _draw_pieces() -> void:
	for piece in _pieces:
		draw_set_transform(piece.pos - position, piece.rot)
		draw_rect(Rect2(-piece.size / 2.0, -piece.size / 2.0, piece.size, piece.size * 0.7), Color(0.62, 0.82, 0.95))
		draw_rect(Rect2(-piece.size / 2.0, -piece.size / 2.0, piece.size, 2), COLOR_FROST)
	draw_set_transform(Vector2.ZERO)


## Dark cracks spreading over its chest as it dies.
func _draw_cracks(c: Vector2, amount: float) -> void:
	var color := Color(0.05, 0.12, 0.2, 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 6:
		var start := c + Vector2(rng.randf_range(-40, 10), rng.randf_range(-30, 40))
		var pts := PackedVector2Array([start])
		var at := start
		for k in int(5 * amount) + 1:
			at += Vector2(rng.randf_range(-10, 10), rng.randf_range(-12, 12))
			pts.append(at)
		if pts.size() > 1:
			draw_polyline(pts, color, 1.5)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
