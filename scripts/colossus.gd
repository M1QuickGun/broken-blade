extends Node2D
## The Frost Colossus, the Frozen village's boss: an ice golem, fought twice. Built from parts
## (art/bosses/colossus_*.png) that the code poses: a chest and head, arms, legs.
##
## Phase 1, the Frost arena: it's frozen into the ice wall at the end of the cavern with the
## ice piece driven into its chest; only its chest, head and arms are out. It can't move, so
## the fight is about its reach. In a fixed order:
## - Double slam: it raises its near arm; a shadow and falling frost mark where the fist will
##   land. Then the far fist comes down where Storm has moved to, and that one stays wedged in
##   the floor for a moment, its arm a stair of footholds up to the glowing crack in its
##   chest, its weak point. A fist planted in the floor can be struck as well.
## - Icicle roar: icicles fall from the ceiling; shadows on the floor show where. They stick
##   in the floor as spikes of ice in the way, until its next slam or sweep shatters them.
## - Floor sweep: frost gathers along its forearm far out on the floor, then the fist rakes
##   along the floor toward the wall at knee height: jump it.
## - Frost breath: a freezing wave runs out along the floor; jump it.
## And if Storm crowds it (up on the ice it's frozen into), frost gathers at its base and ice
## spikes burst up there: back off. Three hits on its chest at once and the crack flares and
## bursts out a spray of ice shards: get out after two.
## At half health it roars and tears its arm further out of the wall: from then on it reaches
## further and attacks faster.
## Beaten, the ice piece bursts out of its chest and floats free, cracks run through it, its
## arms break off and shatter, chunks fall away, and it slumps dead in the wall with an empty
## hole where the piece was.
##
## Phase 2, the Frost throne: broken out of the wall, the hole the piece left still in its
## chest. It rises out of the floor body-first,
## then its legs burst out and it stands. Then, in a fixed order:
## - Charge: it crouches low and charges across the arena. Its belly clears the floor by less
##   than Storm's height: the way past is to slide between its legs, and sliding under it
##   trips it: it crashes face down, chest on the floor, for a few moments. Hitting the far
##   wall instead stuns it to its knees, chest low enough to reach with a jump.
## - Reach: it drops to one knee and slams its fist down in front of it; the arm stays
##   planted, a stair of icy footholds up to its chest (which is within a jump anyway).
## While it's down (stunned, tripped, or planted on its arm) a blow anywhere on its upper
## body finds the crack.
## - Stomp: it lifts a foot and stamps; shockwaves run both ways along the floor.
## - Ice pillars: the floor swells, then pillars of ice burst up around Storm. Climb them to
##   reach its chest.
## Beaten, it shatters.
##
## The node's origin is the room's B marker, on the arena's floor.

signal defeated
## Sent when it wakes: the room bars its doors then.
signal engaged

const Effects := preload("res://scripts/effects.gd")
const Projectile := preload("res://scripts/projectile.gd")
const Shard := preload("res://scripts/shard.gd")
const TORSO := preload("res://art/bosses/colossus_torso.png")
## Its chest once the ice piece is out of it: an empty, cracked hole where the shard was.
const TORSO_HOLLOW := preload("res://art/bosses/colossus_torso_hollow.png")
## How far its chest sits above its hips (phase 2); its waist hangs between the two.
const HIP_DROP := 80.0
const COLOR_PIECE := Color("bfe9ff")
## Phase 2's ice pillars: tall enough to climb and get over it.
const PILLAR_HEIGHT := 128.0
const ARM := preload("res://art/bosses/colossus_arm.png")
## Its near arm, drawn with the back of the hand toward the viewer (the far arm, ARM, shows
## the other side of its fist).
const ARM_LEFT := preload("res://art/bosses/colossus_arm_left.png")
## The near arm's art is drawn smaller in its frame: its shoulder joint, and how much it's
## scaled up to match the far arm's length.
const ARM_LEFT_PIVOT := Vector2(24, 28)
const ARM_LEFT_SCALE := 128.0 / 94.0
const LEG := preload("res://art/bosses/colossus_leg.png")
## Phase 2's waist and hips (96x64, facing right), joining the chest to the legs.
const PELVIS := preload("res://art/bosses/colossus_pelvis.png")

const TILE := 16
const LAYER_WORLD := 1
const LAYER_ENEMY := 4
## The chest wound in the torso art (128x128), and each part's pivot in its own art.
const CRACK := Vector2(74, 78)
## Where its arms join the body in the torso art (which faces right): the near shoulder is the
## big rounded stump, the far one is tucked behind its head; and its eyes.
const SHOULDER_FRONT := Vector2(28, 52)
const SHOULDER_BACK := Vector2(102, 64)
const EYES := Vector2(100, 38)
const ARM_PIVOT := Vector2(12, 28)
const ARM_REACH := 100.0
const LEG_PIVOT := Vector2(30, 4)
const LEG_LENGTH := 90.0
## Phase 1's arms are huge next to the rest of it; a fist slam can stretch them a little.
const ARM_SCALE_1 := 1.4
const COLOR_FROST := Color(0.75, 0.92, 1.0)
const COLOR_SHADOW := Color(0.02, 0.05, 0.1, 0.55)
const COLOR_EYES := Color(0.45, 0.95, 1.0)
const PATTERN_1 := ["slam", "roar", "sweep", "slam", "breath", "sweep"]
const PATTERN_2 := ["charge", "reach", "stomp", "pillars", "charge", "reach"]
## How far down its hips sink when it kneels, and further when it's tripped flat.
const KNEEL_DROP := 80.0
const TOPPLE_DROP := 40.0
## Phase 2's arm, drawn bigger than walking so it can reach the floor, and its footholds.
const ARM_SCALE_2 := 1.25
const STEP_SIZE := Vector2(20, 6)
## Chest hits in one opening before it bursts ice out of the crack.
const GREED_HITS := 3
## Icicles stuck in the floor, at most.
const MAX_SPIKES := 8

enum St {
	DORMANT, WAKE, IDLE, AIM, STRIKE, WEDGED, RETRACT, ROAR, BREATH,
	CROUCH, CHARGE, STUNNED, LIFT, PILLARS, SLUMP, SLUMPED, SHATTER, BURST_WARN, BURST,
	AIM_2, STRIKE_2, SWEEP_CHARGE, SWEEP, GREED_WARN, ENRAGE, TOPPLE,
	REACH_AIM, REACH_STRIKE, REACH_WEDGED, REACH_RETRACT, DYING,
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
## Phase 1's end: the ice piece flying out of its chest to where it'll wait (0 to 1, or -1
## before it's out).
var _piece_t := -1.0
var _piece_from := Vector2.ZERO

var _chest: Hitbox
var _fist: Hitbox
var _charge_box: Hitbox
var _burst_box: Hitbox
var _feet: Array[Hitbox] = []
## Phase 2: its body and legs hurt to touch (so Storm can't pass through it).
var _body_box: Hitbox
var _leg_boxes: Array[Hitbox] = []
var _fist_ledge: StaticBody2D
var _fist_2: Hitbox
var _knuckles: Hitbox
var _knuckles_2: Hitbox
## Phase 1: its far arm's own angle and stretch (it slams second); below half health it
## reaches further and moves faster (its waits and wind-ups scaled by _pace).
var _back_angle := deg_to_rad(160.0) - 0.25
var _back_stretch := 1.0
var _back_from := 0.0
var _back_to := 0.0
var _back_stretch_from := 1.0
var _back_stretch_to := 1.0
var _target_2 := Vector2.ZERO
var _enraged := false
var _pace := 1.0
## Chest hits since its last attack began.
var _greed := 0
## The floor sweep: where the fist starts and ends along the floor.
var _sweep_from := 0.0
var _sweep_to := 0.0
## Icicles that fell and stuck: {x, y (the ground it stands on), body}; and ones still
## falling, to stick when they land: {x, y, t}.
var _spikes: Array[Dictionary] = []
var _landing: Array[Dictionary] = []
## Phase 2: how far it's tripped flat; which side of it Storm was when its charge began; the
## footholds along its planted arm.
var _topple := 0.0
var _charge_side := 0
var _steps: Array[StaticBody2D] = []
## Phase 2's end: its legs, then its arms, burst before its body does.
var _legs_gone := false
var _arms_gone := false
## How long phase 2's death takes, and when its legs and arms burst (time left).
const DYING_TIME := 3.6
const LEGS_BURST_AT := 2.4
const ARMS_BURST_AT := 1.4


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
	_chest = _make_box(Vector2(40, 40), true)
	_fist = _make_box(Vector2(40, 30), false)
	_fist_2 = _make_box(Vector2(40, 30), false)
	# A fist planted in the floor is there to be struck too.
	_knuckles = _make_box(Vector2(36, 28), true)
	_knuckles_2 = _make_box(Vector2(36, 28), true)
	for i in 4:
		var step := StaticBody2D.new()
		step.collision_layer = 0
		step.collision_mask = 0
		step.top_level = true
		var step_shape := RectangleShape2D.new()
		step_shape.size = STEP_SIZE
		var step_col := CollisionShape2D.new()
		step_col.shape = step_shape
		step_col.one_way_collision = true
		step.add_child(step_col)
		add_child(step)
		_steps.append(step)
	_charge_box = _make_box(Vector2(84, 80), false)
	_burst_box = _make_box(Vector2(130, 70), false)
	for i in 2:
		_feet.append(_make_box(Vector2(26, 16), false))
		_leg_boxes.append(_make_box(Vector2(18, 66), false))
	# Its waist and hips (not its chest, so the crack can be reached without touching it).
	_body_box = _make_box(Vector2(56, 56), false)
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
	_set_box(_fist_2, false)
	_set_box(_knuckles, false)
	_set_box(_knuckles_2, false)
	_set_box(_charge_box, false)
	_set_box(_burst_box, false)
	_set_box(_body_box, false)
	for box in _leg_boxes:
		_set_box(box, false)
	for foot in _feet:
		_set_box(foot, false)
	if dead:
		_piece_t = 1.0
		_slump = 1.0
		_arms_off = [true, true]
		_state = St.SLUMPED


func _measure() -> void:
	var room := get_parent()
	var cx := int(position.x / TILE)
	var cy := int(position.y / TILE) - 1
	# (The wall it's frozen into is found well above the floor, past its ice pedestal.)
	var wall_row := cy - 5 if phase == 1 else cy
	var x := cx
	while x < room.size_tiles.x - 1 and room._cell(x + 1, wall_row) != "#":
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
	Sfx.play("hit_boss", -3.0)
	Effects.sparks(get_parent(), _chest_point(), Color(0.75, 0.95, 1.0), 14)
	if phase == 1 and hp > 0:
		_greed += 1
		if not _enraged and hp <= max_hp / 2:
			_enraged = true
			_pace = 0.75
			_greed = 0
			_enter(St.ENRAGE, 1.3)
		elif _greed >= GREED_HITS and _state not in [St.GREED_WARN, St.ENRAGE]:
			_greed = 0
			_enter(St.GREED_WARN, 0.45)
	if hp <= 0:
		Effects.slow_motion(get_tree())
		hp = 0
		remove_from_group("shock_target")
		remove_from_group("boss")
		for box in [_chest, _fist, _fist_2, _knuckles, _knuckles_2, _charge_box, _body_box] + _feet + _leg_boxes:
			_set_box(box, false)
		_fist_ledge.collision_layer = 0
		_set_steps(false)
		_icicles.clear()
		_landing.clear()
		_shatter_spikes()
		_enter(St.SLUMP if phase == 1 else St.DYING, 2.6 if phase == 1 else DYING_TIME)


# --- Geometry ---

func _torso_center() -> Vector2:
	if phase == 1:
		return Vector2(_face - 44.0, _floor - 92.0 + 26.0 * _slump)
	if not _legs_out:
		# Rising out of the floor, legs still buried.
		return Vector2(_x, lerpf(_floor + 80.0, _floor - 46.0, _rise))
	var hip_y := _floor - LEG_LENGTH + 46.0 * _crouch + KNEEL_DROP * _kneel + TOPPLE_DROP * _topple
	return Vector2(_x, hip_y - HIP_DROP)


## Which way it faces: -1 left, 1 right. Frozen in the right-hand wall it faces left.
func _facing() -> int:
	return -1 if phase == 1 else _dir


func _chest_point() -> Vector2:
	return _on_torso(CRACK)


## A point in the torso art, placed in the world for the way it faces.
func _on_torso(art: Vector2) -> Vector2:
	var off := art - Vector2(64, 64)
	off.x *= _facing()
	return _torso_center() + off


func _shoulder() -> Vector2:
	return _on_torso(SHOULDER_FRONT)


func _back_shoulder() -> Vector2:
	return _on_torso(SHOULDER_BACK)


func _fist_point() -> Vector2:
	var scale_ := ARM_SCALE_1 if phase == 1 else ARM_SCALE_2
	return _shoulder() + Vector2.from_angle(_arm_angle) * ARM_REACH * scale_ * _arm_stretch


func _back_fist_point() -> Vector2:
	return _back_shoulder() + Vector2.from_angle(_back_angle) * ARM_REACH * ARM_SCALE_1 * 0.9 * _back_stretch


## How far its arms may stretch to reach (further once it's torn an arm free).
func _max_stretch() -> float:
	return 1.5 if _enraged else 1.3


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
	if state in [St.CROUCH, St.SWEEP_CHARGE, St.BURST_WARN, St.GREED_WARN]:
		Sfx.play("warn", -6.0, 0.0)  # its biggest blows ring a warning first
	_state = state
	_timer = time
	match state:
		St.WAKE, St.ROAR, St.SLUMP:
			Sfx.play("roar", -1.0, 0.04)
		St.WEDGED, St.STUNNED:
			Sfx.play("slam", -2.0)
		St.BREATH:
			Sfx.play("spin", -2.0, 0.0)
		St.BURST, St.SHATTER:
			Sfx.play("shatter", -2.0)
		St.PILLARS:
			Sfx.play("burst", -3.0)
		St.CROUCH:
			Sfx.play("rumble", -4.0)


func _wake() -> void:
	engaged.emit()
	add_to_group("boss")
	add_to_group("shock_target")
	_shake = 0.8
	_enter(St.WAKE, 1.4)


func _next_attack() -> void:
	_greed = 0
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
			_rest_back_arm(delta)
			if _timer <= 0.0 and p.x > _face - 120.0:
				_enter(St.BURST_WARN, 0.75 * _pace)  # too close: it drives him off
			elif _timer <= 0.0:
				_next_attack()
				match _attack:
					"slam":
						_aim_slam(p)
					"roar":
						_roar(p)
					"sweep":
						_sweep_from = _shoulder().x - (190.0 if _enraged else 165.0)
						_sweep_to = _face - 92.0
						_enter(St.SWEEP_CHARGE, 0.8 * _pace)
					"breath":
						_enter(St.BREATH, 0.9 * _pace)
		St.AIM:
			# Near arm raised; the shadow of the fist grows where it'll land.
			_arm_angle = lerp_angle(_arm_angle, deg_to_rad(215.0), 6.0 * delta)
			_rest_back_arm(delta)
			if fmod(_time, 0.06) < delta:
				_frost(Vector2(_target.x + randf_range(-14, 14), _floor - 120.0))
			if _timer <= 0.0:
				_arm_from = _arm_angle
				_stretch_from = _arm_stretch
				var to := _target - _shoulder()
				_arm_to = to.angle()
				_stretch_to = clampf(to.length() / (ARM_REACH * ARM_SCALE_1), 0.7, _max_stretch())
				_enter(St.STRIKE, 0.18)
		St.STRIKE:
			var t := clampf(1.0 - _timer / 0.18, 0.0, 1.0)
			_arm_angle = lerp_angle(_arm_from, _arm_to, t * t)
			_arm_stretch = lerpf(_stretch_from, _stretch_to, t)
			fist_on = true
			if _timer <= 0.0:
				_land_fist(_fist_point())
				# Then the far fist, aimed at wherever he's gone.
				_target_2 = Vector2(_slam_x(p), _floor - 22.0)
				_enter(St.AIM_2, 0.6 * _pace)
		St.AIM_2:
			# The near fist stays down; the far arm rises over it.
			_back_angle = lerp_angle(_back_angle, deg_to_rad(205.0), 8.0 * delta)
			_target_2.x = lerpf(_target_2.x, _slam_x(p), 3.0 * delta)
			if fmod(_time, 0.06) < delta:
				_frost(Vector2(_target_2.x + randf_range(-14, 14), _floor - 120.0))
			if _timer <= 0.0:
				_back_from = _back_angle
				_back_stretch_from = _back_stretch
				var to := _target_2 - _back_shoulder()
				_back_to = to.angle()
				_back_stretch_to = clampf(to.length() / (ARM_REACH * ARM_SCALE_1 * 0.9), 0.7, _max_stretch() + 0.15)
				_enter(St.STRIKE_2, 0.18)
		St.STRIKE_2:
			var t := clampf(1.0 - _timer / 0.18, 0.0, 1.0)
			_back_angle = lerp_angle(_back_from, _back_to, t * t)
			_back_stretch = lerpf(_back_stretch_from, _back_stretch_to, t)
			_arm_angle = lerp_angle(_arm_angle, deg_to_rad(160.0), 6.0 * delta)
			_arm_stretch = move_toward(_arm_stretch, 1.0, 3.0 * delta)
			if _timer <= 0.0:
				_land_fist(_back_fist_point())
				_enter(St.WEDGED, 2.2)
		St.WEDGED:
			# The far fist stuck in the floor: a step up to its chest.
			_arm_angle = lerp_angle(_arm_angle, deg_to_rad(160.0), 4.0 * delta)
			_arm_stretch = move_toward(_arm_stretch, 1.0, 2.0 * delta)
			if _timer <= 0.0:
				_enter(St.RETRACT, 0.6)
		St.RETRACT:
			_arm_angle = lerp_angle(_arm_angle, deg_to_rad(160.0), 5.0 * delta)
			_arm_stretch = move_toward(_arm_stretch, 1.0, 2.0 * delta)
			_rest_back_arm(delta, 5.0)
			if _timer <= 0.0:
				_enter(St.IDLE, 0.9 * _pace)
		St.SWEEP_CHARGE:
			# The fist laid out far along the floor, frost gathering along the forearm.
			_rest_back_arm(delta)
			_aim_arm_at(Vector2(_sweep_from, _floor - 14.0), 6.0 * delta)
			if fmod(_time, 0.05) < delta:
				_frost(_shoulder().lerp(_fist_point(), randf()) + Vector2(randf_range(-6, 6), -8))
			if _timer <= 0.0:
				Sfx.play("spin", -4.0, 0.0)
				_enter(St.SWEEP, 0.45)
		St.SWEEP:
			# Raking along the floor toward the wall at knee height.
			var t := clampf(1.0 - _timer / 0.45, 0.0, 1.0)
			_aim_arm_at(Vector2(lerpf(_sweep_from, _sweep_to, t), _floor - 14.0), 1.0)
			fist_on = true
			if fmod(_time, 0.03) < delta:
				_frost(_fist_point() + Vector2(0, 10))
			_shatter_spikes(_fist_point().x, 24.0)
			if _timer <= 0.0:
				_enter(St.RETRACT, 0.6)
		St.GREED_WARN:
			# Struck once too often: the crack flares...
			if fmod(_time, 0.04) < delta:
				_frost(_chest_point() + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
			if _timer <= 0.0:
				# ...and bursts out a spray of ice shards.
				_shake = 0.3
				Sfx.play("shatter", -4.0)
				for i in 6:
					var angle := deg_to_rad(lerpf(-70.0, 25.0, i / 5.0))
					_spawn("icicle", _chest_point() + Vector2(-12, 0),
						Vector2(-cos(angle), sin(angle)) * randf_range(190, 240), 300.0, 2.0)
				_enter(St.RETRACT, 0.6)
		St.ENRAGE:
			# Half beaten: it roars and wrenches its arm further out of the wall.
			_rest_back_arm(delta)
			_arm_angle = lerp_angle(_arm_angle, deg_to_rad(200.0), 3.0 * delta)
			_shake = maxf(_shake, 0.05)
			if fmod(_time, 0.05) < delta:
				_frost(_shoulder() + Vector2(randf_range(-20, 20), randf_range(-20, 20)))
			if _timer <= 0.0:
				_enter(St.IDLE, 0.4)
		St.ROAR:
			_rest_back_arm(delta)
			if _timer <= 0.0:
				_enter(St.IDLE, 0.6 * _pace)
		St.BURST_WARN:
			# Frost gathers on the ice at its base...
			if fmod(_time, 0.04) < delta:
				_frost(Vector2(_face - randf_range(10, 120), _floor - randf_range(0, 50)))
			if _timer <= 0.0:
				_shake = 0.3
				_enter(St.BURST, 0.5)
		St.BURST:
			# ...then spikes of ice burst up all around it.
			if _timer <= 0.0:
				_enter(St.IDLE, 1.0)
		St.BREATH:
			# Frost gathers at its mouth, then a freezing wave runs out along the floor.
			if fmod(_time, 0.05) < delta:
				_frost(_torso_center() + Vector2(-46, -40))
			if _timer <= 0.0:
				_spawn("frost_wave", Vector2(_face - 110.0, _floor), Vector2(-150.0, 0), 0.0, 3.5)
				_enter(St.IDLE, 1.2 * _pace)
		St.SLUMP:
			# Cracks run through it; one arm then the other breaks off and shatters on the
			# floor; chunks fall away as it slumps dead into the wall.
			_slump = minf(_slump + delta / 2.2, 1.0)
			_shake = maxf(_shake, 0.06)
			if _piece_t < 0.0:
				# The ice piece bursts out of its chest.
				_piece_t = 0.0
				_piece_from = _chest_point()
				_shake = 0.5
				for i in 8:
					_frost(_piece_from + Vector2(randf_range(-8, 8), randf_range(-8, 8)))
				Sfx.play("shatter", -2.0)
			_piece_t = minf(_piece_t + delta / 1.4, 1.0)
			_arm_angle = lerp_angle(_arm_angle, deg_to_rad(125.0), 2.0 * delta)
			_arm_stretch = move_toward(_arm_stretch, 1.0, delta)
			_back_angle = lerp_angle(_back_angle, deg_to_rad(125.0) - 0.25, 2.0 * delta)
			_back_stretch = move_toward(_back_stretch, 1.0, delta)
			if not _arms_off[0] and _timer < 2.0:
				_arms_off[0] = true
				_break_arm(_shoulder(), _arm_angle, ARM_SCALE_1)
			if not _arms_off[1] and _timer < 1.3:
				_arms_off[1] = true
				_break_arm(_back_shoulder(), _back_angle, ARM_SCALE_1 * 0.9)
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
	_set_box(_fist_2, _state == St.STRIKE_2, _back_fist_point())
	_set_box(_knuckles, _state in [St.AIM_2, St.STRIKE_2], _fist_point())
	_set_box(_knuckles_2, _state == St.WEDGED, _back_fist_point())
	if _state == St.WEDGED:
		_set_steps(true, _back_fist_point(), _back_shoulder() + Vector2(6, 0), 3)
	elif _state not in [St.SLUMP, St.SLUMPED]:
		_set_steps(false)
	_set_box(_burst_box, _state == St.BURST, Vector2(_face - 65.0, _floor - 35.0))
	var wedged := _state == St.WEDGED
	_fist_ledge.collision_layer = LAYER_WORLD if wedged else 0
	if wedged:
		_fist_ledge.global_position = get_parent().to_global(_back_fist_point() + Vector2(0, -6))
	_update_spikes(delta)


func _aim_slam(p: Vector2) -> void:
	_target = Vector2(_slam_x(p), _floor - 22.0)
	_enter(St.AIM, 0.9 * _pace)


## Where a fist can land nearest Storm: a band of floor out in front of it (wider once it's
## torn its arm free).
func _slam_x(p: Vector2) -> float:
	var near := _shoulder().x - 60.0
	var far := _shoulder().x - (210.0 if _enraged else 160.0)
	return clampf(p.x, far, near)


## A fist hitting the floor: a jolt, frost, and the icicles standing in the floor shatter.
func _land_fist(at: Vector2) -> void:
	_shake = 0.35
	Sfx.play("slam", -2.0)
	for i in 5:
		_frost(at + Vector2(randf_range(-16, 16), 10))
	_shatter_spikes()


## Points the near arm (fist end) at a spot, stretching to reach it.
func _aim_arm_at(at: Vector2, weight: float) -> void:
	var to := at - _shoulder()
	var w := clampf(weight, 0.0, 1.0)
	_arm_angle = lerp_angle(_arm_angle, to.angle(), w)
	_arm_stretch = lerpf(_arm_stretch, clampf(to.length() / (ARM_REACH * ARM_SCALE_1), 0.7, _max_stretch()), w)


## The far arm easing back to rest beside it.
func _rest_back_arm(delta: float, rate := 3.0) -> void:
	_back_angle = lerp_angle(_back_angle, deg_to_rad(160.0) - 0.25 + sin(_time * 1.5 + 1.0) * 0.05, rate * delta)
	_back_stretch = move_toward(_back_stretch, 1.0, rate * 0.5 * delta)


func _roar(p: Vector2) -> void:
	_shake = 0.5
	for i in 6:
		var x := clampf(p.x + (i - 2.5) * 34.0 + randf_range(-8, 8), _left + 10, _face - 10)
		_icicles.append({"x": x, "t": (0.9 + i * 0.12) * _pace})
	_enter(St.ROAR, 1.6 * _pace)


func _update_icicles(delta: float) -> void:
	var fallen := []
	for ice in _icicles:
		ice.t -= delta
		if ice.t <= 0.0:
			_spawn("icicle", Vector2(ice.x, TILE * 1.5), Vector2.ZERO, 520.0, 2.5)
			fallen.append(ice)
			if phase == 1:
				# It'll stick where it lands.
				var ground := _ground_under(ice.x)
				_landing.append({"x": ice.x, "y": ground, "t": sqrt(2.0 * (ground - TILE * 1.5) / 520.0)})
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
				# The block of ice it rose on bursts apart as its legs come out.
				var top := _torso_center().y + 40.0
				for i in 16:
					_pieces.append({
						"pos": Vector2(_x + randf_range(-36, 36), randf_range(top, _floor)),
						"vel": Vector2(randf_range(-140, 140), randf_range(-220, -40)),
						"size": randf_range(6, 14), "rot": randf() * TAU, "spin": randf_range(-8, 8),
					})
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
					"reach":
						_face_toward(p, 1.0)
						_arm_angle = PI / 2.0 - _dir * 0.3  # from where it hangs at its side
						_arm_stretch = 1.0
						_target = Vector2(_x + _dir * clampf(absf(p.x - _x), 60.0, 120.0), _floor - 18.0)
						_enter(St.REACH_AIM, 0.9)
		St.CROUCH:
			# Crouching low, scraping a foot: it's about to charge.
			_crouch = move_toward(_crouch, 1.0, 2.5 * delta)
			if _timer > 0.6:
				_face_toward(p, delta)
			if fmod(_time, 0.08) < delta:
				_frost(Vector2(_x - _dir * 30.0, _floor - 4))
			if _timer <= 0.0:
				_charge_side = 1 if p.x > _x else -1
				_enter(St.CHARGE, 3.0)
		St.CHARGE:
			feet_on = false
			charge_on = true
			if _slid_under(p):
				# It trips over him and crashes down on its face.
				_shake = 0.8
				Sfx.play("slam", 0.0)
				for i in 10:
					_frost(Vector2(_x + randf_range(-60, 60), _floor - randf_range(0, 20)))
				_enter(St.TOPPLE, 3.2)
			_x += _dir * 230.0 * delta
			_stride += delta * 14.0
			if fmod(_time, 0.05) < delta:
				_frost(Vector2(_x - _dir * 40.0, _floor - 4))
			var edge := _left + 50.0 if _dir < 0 else _right - 50.0
			if (_dir < 0 and _x <= edge) or (_dir > 0 and _x >= edge) or _timer <= 0.0:
				_x = clampf(_x, _left + 50, _right - 50)
				_shake = 0.5
				_enter(St.STUNNED, 2.6)
		St.TOPPLE:
			# Face down on the floor, chest within reach; then it heaves itself back up.
			feet_on = false
			_crouch = move_toward(_crouch, 0.0, 4.0 * delta)
			var down := _timer > 0.6
			_kneel = move_toward(_kneel, 1.0 if down else 0.0, (6.0 if down else 2.0) * delta)
			_topple = move_toward(_topple, 1.0 if down else 0.0, (6.0 if down else 2.0) * delta)
			if _timer <= 0.0:
				_topple = 0.0
				_enter(St.IDLE, 0.8)
		St.REACH_AIM:
			# It drops to one knee and raises its fist; the shadow shows where it'll land.
			_crouch = move_toward(_crouch, 1.0, 2.5 * delta)
			_kneel = move_toward(_kneel, 0.5, 1.5 * delta)
			_arm_angle = lerp_angle(_arm_angle, -PI / 2.0 - _dir * 0.3, 5.0 * delta)
			_arm_stretch = move_toward(_arm_stretch, 1.0, 2.0 * delta)
			if fmod(_time, 0.06) < delta:
				_frost(Vector2(_target.x + randf_range(-14, 14), _floor - 100.0))
			if _timer <= 0.0:
				_arm_from = _arm_angle
				_stretch_from = _arm_stretch
				var to := _target - _shoulder()
				_arm_to = to.angle()
				_stretch_to = clampf(to.length() / (ARM_REACH * ARM_SCALE_2), 0.7, 1.4)
				_enter(St.REACH_STRIKE, 0.2)
		St.REACH_STRIKE:
			var t := clampf(1.0 - _timer / 0.2, 0.0, 1.0)
			_arm_angle = lerp_angle(_arm_from, _arm_to, t * t)
			_arm_stretch = lerpf(_stretch_from, _stretch_to, t)
			if _timer <= 0.0:
				_land_fist(_fist_point())
				_enter(St.REACH_WEDGED, 2.8)
		St.REACH_WEDGED:
			# Its arm stays planted: footholds up it to its chest.
			feet_on = false
			if _timer <= 0.0:
				_enter(St.REACH_RETRACT, 0.6)
		St.REACH_RETRACT:
			_crouch = move_toward(_crouch, 0.0, 2.0 * delta)
			_kneel = move_toward(_kneel, 0.0, 2.0 * delta)
			if _timer <= 0.0:
				_enter(St.IDLE, 1.0)
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
		St.DYING:
			# Beaten: it drops to its knees, cracks spreading from the hole in its chest, light
			# pouring out of them, chunks breaking away. Then it comes apart a part at a time:
			# its legs burst and its body drops to the ground, then its arms, then its body.
			feet_on = false
			_crouch = move_toward(_crouch, 0.0, 3.0 * delta)
			_lift = 0.0
			_topple = move_toward(_topple, 1.0 if _legs_gone else 0.0, 4.0 * delta)
			_kneel = move_toward(_kneel, 1.0, 1.5 * delta)
			_shake = maxf(_shake, 0.08 + 0.2 * (1.0 - _timer / DYING_TIME))
			if not _legs_gone and _timer <= LEGS_BURST_AT:
				_legs_gone = true
				_burst_legs()
			if not _arms_gone and _timer <= ARMS_BURST_AT:
				_arms_gone = true
				_shake = 0.5
				Sfx.play("shatter", -2.0, 0.1)
				var swing := sin(_stride) * 0.15
				_break_arm(_back_shoulder(), PI / 2.0 - _dir * (0.2 + swing), 0.95)
				_break_arm(_shoulder(), PI / 2.0 - _dir * (0.3 - swing), 1.0)
			if fmod(_time, 0.14) < delta:
				_chip(_torso_center() + Vector2(randf_range(-40, 40), randf_range(-40, 50)))
				_frost(_chest_point() + Vector2(randf_range(-20, 20), randf_range(-20, 20)))
			if fmod(_time, 0.5) < delta:
				Sfx.play("shatter", -12.0, 0.2)
			_update_pieces(delta)
			if _timer <= 0.0:
				Sfx.play("shatter", 0.0, 0.0)
				Effects.slow_motion(get_tree(), 0.3, 0.6)
				for i in 16:
					_frost(_torso_center() + Vector2(randf_range(-60, 60), randf_range(-60, 80)))
				_enter(St.SHATTER, 1.8)
				_shatter()
		St.SHATTER:
			feet_on = false
			_update_pieces(delta)
			if _timer <= 0.0:
				Game.defeated[boss_id] = true
				_restore_camera()
				defeated.emit()
				queue_free()
	_update_pillars(delta)
	if _state != St.SHATTER:
		_update_pieces(delta)
	var feet := _foot_points()
	var hips := _hip_points()
	for i in 2:
		_set_box(_feet[i], feet_on, feet[i] + Vector2(0, -8))
		# Along each leg, and its body (chest and waist). Off while it charges, so the gap
		# between its legs, under its low belly, is clear to slide through.
		var leg_mid: Vector2 = hips[i].lerp(feet[i], 0.45)
		_set_box(_leg_boxes[i], feet_on and _legs_out, leg_mid)
	# (Down on its knees, on its face or planted on its arm, it's there to be climbed on.)
	var standing := _legs_out and _state not in [St.DORMANT, St.WAKE, St.SHATTER, St.CHARGE, St.TOPPLE,
		St.REACH_WEDGED, St.STUNNED]
	_set_box(_body_box, standing, _torso_center() + Vector2(0, HIP_DROP - 20.0))
	_set_box(_fist, _state == St.REACH_STRIKE, _fist_point())
	_set_steps(_state == St.REACH_WEDGED, _fist_point(), _shoulder())
	_set_box(_knuckles, _state == St.REACH_WEDGED, _fist_point())
	# Charging, its body is low but clears the floor by less than Storm stands: slide under.
	_set_box(_charge_box, charge_on, Vector2(_x, _floor - 14.0 - 40.0))
	# Down, its whole upper body is open to a blow; standing, only the crack.
	var down := _state in [St.STUNNED, St.TOPPLE, St.REACH_WEDGED]
	var chest_shape: RectangleShape2D = _chest.get_child(0).shape
	chest_shape.size = Vector2(84, 80) if down else Vector2(40, 40)
	_set_box(_chest, _state not in [St.DORMANT, St.WAKE, St.SHATTER],
		_torso_center() + Vector2(0, 12) if down else _chest_point())


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
	var c := _torso_center() + Vector2(0, HIP_DROP)
	return [c + Vector2(_dir * 18.0, 0), c + Vector2(-_dir * 18.0, 0)]


## Each leg's swing (radians) for walking, charging (splayed low), kneeling or stomping.
func _leg_angles() -> Array:
	var swing := sin(_stride) * 0.35 * (1.0 - _kneel)
	var front := swing + _crouch * 0.7 * _dir - _lift * 0.9 * _dir
	var back := -swing - _crouch * 0.7 * _dir
	if _kneel > 0.0:
		front = lerpf(front, 1.25 * _dir, _kneel)
		back = lerpf(back, -1.45 * _dir, _kneel)
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
		var height: float = PILLAR_HEIGHT * pillar.rise
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


## Whether Storm has just slid under its charge, from the side he started on to the other.
func _slid_under(p: Vector2) -> bool:
	var player := _player()
	if player == null or not player.has_method("_is_small"):
		return false
	var side := 1 if p.x > _x else -1
	return side != _charge_side and absf(p.x - _x) < 60.0 and player.is_on_floor() and player._is_small()


## Its legs bursting into chunks of ice, hip to foot.
func _burst_legs() -> void:
	_shake = 0.5
	Sfx.play("shatter", -2.0, 0.1)
	var hips := _hip_points()
	var feet := _foot_points()
	for i in 2:
		for k in 9:
			var at: Vector2 = hips[i].lerp(feet[i], (k + 0.5) / 9.0)
			_pieces.append({
				"pos": at + Vector2(randf_range(-8, 8), randf_range(-6, 6)),
				"vel": Vector2(randf_range(-110, 110), randf_range(-200, -40)),
				"size": randf_range(7, 14), "rot": randf() * TAU, "spin": randf_range(-8, 8),
			})
		for k in 4:
			_frost(hips[i].lerp(feet[i], randf()))


## Footholds along a planted arm, from its fist up toward its shoulder (`count` of them, the
## rest off).
func _set_steps(on: bool, fist := Vector2.ZERO, shoulder := Vector2.ZERO, count := 4) -> void:
	for i in _steps.size():
		var step := _steps[i]
		var used := on and i < count
		step.collision_layer = LAYER_WORLD if used else 0
		if used:
			var f := 0.18 + i * (0.8 / count)
			step.global_position = get_parent().to_global(fist.lerp(shoulder, f) + Vector2(0, -6))


## The top of the ground under x (the floor, or the ice it rests on).
func _ground_under(x: float) -> float:
	var room := get_parent()
	var cx := int(x / TILE)
	for cy in range(1, room.size_tiles.y):
		if room._cell(cx, cy) == "#":
			return cy * TILE
	return _floor


## Fallen icicles sticking where they landed, as spikes of ice in the way.
func _update_spikes(delta: float) -> void:
	var stuck := []
	for ice in _landing:
		ice.t -= delta
		if ice.t > 0.0:
			continue
		stuck.append(ice)
		var player := _player()
		# Not on top of Storm (it broke on him instead).
		if player and absf(player.position.x - ice.x) < 12.0 and absf(player.position.y - ice.y) < 30.0:
			continue
		var body := StaticBody2D.new()
		body.collision_layer = LAYER_WORLD
		body.collision_mask = 0
		body.top_level = true
		var shape := RectangleShape2D.new()
		shape.size = Vector2(8, 16)
		var col := CollisionShape2D.new()
		col.shape = shape
		body.add_child(col)
		add_child(body)
		body.global_position = get_parent().to_global(Vector2(ice.x, ice.y - 8.0))
		_spikes.append({"x": ice.x, "y": ice.y, "body": body})
		if _spikes.size() > MAX_SPIKES:
			_break_spike(_spikes.pop_front())
	for ice in stuck:
		_landing.erase(ice)


## Shatters the stuck icicles: all of them, or just those within `reach` of x.
func _shatter_spikes(x := 0.0, reach := -1.0) -> void:
	var gone := []
	for spike in _spikes:
		if reach < 0.0 or absf(spike.x - x) < reach:
			gone.append(spike)
	for spike in gone:
		_spikes.erase(spike)
		_break_spike(spike)


func _break_spike(spike: Dictionary) -> void:
	for i in 3:
		_frost(Vector2(spike.x + randf_range(-4, 4), spike.y - randf_range(2, 14)))
	if is_instance_valid(spike.body):
		spike.body.queue_free()


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
	if not Game.screen_shake:
		_shake = 0.0
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
	return _piece_rest()


## Where the ice piece floats down to wait when phase 1 ends: out in front of it, in reach.
func _piece_rest() -> Vector2:
	return Vector2((_left + _face) / 2.0, _floor - 48.0)


# --- Art ---

func _draw() -> void:
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	for ice in _icicles:
		var grow := clampf(1.0 - ice.t / 0.9, 0.2, 1.0)
		_draw_ellipse(Vector2(ice.x, _floor) - position, Vector2(4.0 + 6.0 * grow, 2.0), COLOR_SHADOW)
	# The footholds first, so its arm is drawn over them.
	_draw_steps()
	if phase == 1:
		_draw_phase_1(tint)
	else:
		_draw_phase_2(tint)


func _draw_phase_1(tint: Color) -> void:
	if _state == St.AIM:
		var grow := clampf(1.0 - _timer / (0.9 * _pace), 0.0, 1.0)
		_draw_ellipse(Vector2(_target.x, _floor) - position, Vector2(10.0 + 14.0 * grow, 3.0), COLOR_SHADOW)
	if _state == St.AIM_2:
		var grow := clampf(1.0 - _timer / (0.6 * _pace), 0.0, 1.0)
		_draw_ellipse(Vector2(_target_2.x, _floor) - position, Vector2(10.0 + 14.0 * grow, 3.0), COLOR_SHADOW)
	for spike in _spikes:
		var base := Vector2(spike.x, spike.y) - position
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-4, 0), base + Vector2(0, -16), base + Vector2(4, 0),
		]), Color(0.72, 0.88, 1.0, 0.95))
		draw_line(base + Vector2(-1, -2), base + Vector2(0, -12), COLOR_FROST, 1.0)
	var dim := 0.55 if _state in [St.DORMANT, St.SLUMPED] else 1.0
	if _state == St.SLUMP:
		dim = lerpf(1.0, 0.55, _slump)
	var body_tint := Color(tint.r * dim, tint.g * dim, tint.b * dim)
	# The back arm, behind the body; then the chest and head; then the front arm.
	if not _arms_off[1]:
		_draw_arm(_back_shoulder(), _back_angle, ARM_SCALE_1 * 0.9, _back_stretch,
			body_tint.darkened(0.3), true, ARM)
	var c := _torso_center() - position
	draw_set_transform(c, 0.0, Vector2(-1, 1))  # the art faces right; it faces left, out of the wall
	draw_texture(TORSO_HOLLOW if _piece_t >= 0.0 else TORSO, -Vector2(64, 64), body_tint)
	draw_set_transform(Vector2.ZERO)
	if _state in [St.SLUMP, St.SLUMPED]:
		_draw_cracks(c, 1.0 if _state == St.SLUMPED else _slump)
	_draw_eyes(c)
	if _state == St.GREED_WARN:
		# The crack flaring before it bursts.
		var glare := clampf(1.0 - _timer / 0.45, 0.0, 1.0)
		draw_circle(_chest_point() - position, 8.0 + 10.0 * glare, Color(COLOR_FROST, 0.35 + 0.4 * glare))
	if not _arms_off[0]:
		_draw_arm(_shoulder(), _arm_angle, ARM_SCALE_1, _arm_stretch, body_tint, true, ARM_LEFT)
	if _piece_t >= 0.0 and _piece_t < 1.0:
		# Floating up and out into the middle of the cavern, turning upright as it settles.
		var at := _piece_from.lerp(_piece_rest(), ease(_piece_t, -1.8)) - Vector2(0, sin(_piece_t * PI) * 40.0) - position
		Shard.draw_piece(self, "dash", at, (1.0 - ease(_piece_t, 0.5)) * TAU * 1.5)
	if _state == St.BURST:
		var up := clampf(1.0 - (_timer - 0.35) / 0.15, 0.0, 1.0)
		for i in 9:
			var x := _face - 12.0 - i * 13.0 - position.x
			var ground := _floor - (48.0 if x + position.x > 15.0 * TILE else 0.0) - position.y
			var h := (22.0 + (i % 3) * 10.0) * up
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - 5, ground), Vector2(x, ground - h), Vector2(x + 5, ground),
			]), Color(0.7, 0.9, 1.0, 0.95))
	_draw_pieces()


func _draw_phase_2(tint: Color) -> void:
	if _state == St.DORMANT:
		return  # buried under the floor
	if _state == St.SHATTER:
		_draw_pieces()
		return
	if not _legs_out:
		# Rising out of the floor on a block of ice and frozen earth.
		var top := _torso_center().y + 40.0 - position.y
		var bx := _x - position.x
		var fy := _floor - position.y
		if top < fy - 12.0:
			draw_colored_polygon(PackedVector2Array([
				Vector2(bx - 38, fy), Vector2(bx - 34, top + 4), Vector2(bx - 16, top),
				Vector2(bx + 18, top + 2), Vector2(bx + 36, top + 6), Vector2(bx + 40, fy),
			]), Color(0.42, 0.6, 0.74))
			draw_line(Vector2(bx - 30, fy - 4), Vector2(bx - 24, top + 8), COLOR_FROST, 2.0)
			draw_line(Vector2(bx + 10, top + 4), Vector2(bx + 22, fy - 6), Color(0.25, 0.38, 0.5), 1.5)
	elif not _legs_gone:
		# Its weight on the floor: a shadow under each foot.
		for foot in _foot_points():
			_draw_ellipse(Vector2(foot.x, _floor) - position, Vector2(18, 3), COLOR_SHADOW)
	for pillar in _pillars:
		if pillar.wait > 0.0:
			var grow := clampf(1.0 - pillar.wait / 0.8, 0.0, 1.0)
			_draw_ellipse(Vector2(pillar.x, _floor) - position, Vector2(6.0 + 6.0 * grow, 2.0 + 3.0 * grow), Color(0.6, 0.85, 1.0, 0.6))
		else:
			var h: float = PILLAR_HEIGHT * pillar.rise
			if h < 8.0:
				continue
			var base := Vector2(pillar.x, _floor) - position
			draw_colored_polygon(PackedVector2Array([
				base + Vector2(-11, 0), base + Vector2(-9, -h + 6), base + Vector2(0, -h),
				base + Vector2(9, -h + 6), base + Vector2(11, 0),
			]), Color(0.6, 0.84, 0.98, 0.95))
			draw_line(base + Vector2(-5, -4), base + Vector2(-3, -h + 10), COLOR_FROST, 2.0)
	var flip := _dir < 0  # the art faces right
	var hips := _hip_points()
	var angles := _leg_angles()
	# Both legs go behind the body, so its waist covers their tops and they join it: the far
	# leg (on the side it faces) first and darker, then the near leg (on the same side as its
	# near arm, the big shoulder stump). Then the far arm, the body, and the near arm in front.
	# The arms hang down and a little forward, knuckles toward where it faces.
	var swing := sin(_stride) * 0.15
	if _legs_out and not _legs_gone:
		_draw_leg(hips[0], angles[0], tint.darkened(0.3))
		_draw_leg(hips[1], angles[1], tint)
	var c := _torso_center() - position
	if not _arms_gone:
		_draw_arm(_back_shoulder(), PI / 2.0 - _dir * (0.2 + swing), 0.95, 1.0,
			tint.darkened(0.3), _dir < 0, ARM)
	draw_set_transform(c, 0.0, Vector2(-1 if flip else 1, 1))
	draw_texture(TORSO_HOLLOW, -Vector2(64, 64), tint)
	draw_set_transform(Vector2.ZERO)
	_draw_eyes(c)
	if _state == St.DYING:
		# Cracks spreading over it, the light inside pouring out of them.
		var amount := clampf(1.0 - _timer / DYING_TIME, 0.0, 1.0)
		_draw_cracks(c, amount)
		_draw_cracks(c + Vector2(0, 40), amount * 0.8)
		var glow := _chest_point() - position
		draw_circle(glow, 10.0 + 30.0 * amount, Color(COLOR_FROST, 0.15 + 0.3 * amount))
		draw_circle(glow, 5.0 + 8.0 * amount, Color(1, 1, 1, 0.4 + 0.5 * amount))
	if _legs_out:
		# The waist, worn over the bottom of the chest like a belt, the legs hanging from it.
		draw_set_transform(c + Vector2(0, HIP_DROP - 14.0), 0.0, Vector2(-1 if flip else 1, 1))
		draw_texture(PELVIS, -Vector2(48, 30), tint)
		draw_set_transform(Vector2.ZERO)
	var rest := PI / 2.0 - _dir * (0.3 - swing)
	if _state in [St.REACH_AIM, St.REACH_STRIKE, St.REACH_WEDGED]:
		if _state == St.REACH_AIM:
			var grow := clampf(1.0 - _timer / 0.9, 0.0, 1.0)
			_draw_ellipse(Vector2(_target.x, _floor) - position, Vector2(10.0 + 14.0 * grow, 3.0), COLOR_SHADOW)
		_draw_arm(_shoulder(), _arm_angle, ARM_SCALE_2, _arm_stretch, tint, _dir < 0, ARM_LEFT)
	elif _state == St.REACH_RETRACT:
		var t := clampf(1.0 - _timer / 0.6, 0.0, 1.0)
		_draw_arm(_shoulder(), lerp_angle(_arm_angle, rest, t), lerpf(ARM_SCALE_2, 1.0, t),
			lerpf(_arm_stretch, 1.0, t), tint, _dir < 0, ARM_LEFT)
	elif not _arms_gone:
		_draw_arm(_shoulder(), rest, 1.0, 1.0, tint, _dir < 0, ARM_LEFT)
	_draw_pieces()


## An arm from its shoulder, pointing along `angle` (fist at the far end). The art points
## right (fist on the right); `flip_y` mirrors it so the knuckles face the way it faces.
func _draw_arm(shoulder: Vector2, angle: float, scale_: float, stretch: float, tint: Color, flip_y: bool,
		art: Texture2D = ARM) -> void:
	draw_set_transform(shoulder - position, angle, Vector2(scale_ * stretch, -scale_ if flip_y else scale_))
	if art == ARM_LEFT:
		draw_set_transform(shoulder - position, angle,
			Vector2(scale_ * stretch, -scale_ if flip_y else scale_) * ARM_LEFT_SCALE)
		draw_texture(art, -ARM_LEFT_PIVOT, tint)
	else:
		draw_texture(art, -ARM_PIVOT, tint)
	draw_set_transform(Vector2.ZERO)


func _draw_leg(hip: Vector2, angle: float, tint: Color, art: Texture2D = LEG) -> void:
	# The art's toes point right: mirrored when it faces left.
	draw_set_transform(hip - position, -angle, Vector2(1 if _dir > 0 else -1, 1))
	draw_texture(art, -LEG_PIVOT, tint)
	draw_set_transform(Vector2.ZERO)


## Its eyes: dark while it sleeps or after it falls, glowing otherwise.
func _draw_eyes(c: Vector2) -> void:
	if _state in [St.DORMANT, St.SLUMPED] or (_state == St.SLUMP and _slump > 0.6):
		return
	var glow := 0.6 + 0.4 * sin(_time * 4.0)
	draw_circle(_on_torso(EYES) - position, 5.0, Color(COLOR_EYES, 0.25 * glow))


## The footholds on a planted arm: ledges of ice frozen onto it.
func _draw_steps() -> void:
	for step in _steps:
		if step.collision_layer == 0:
			continue
		var at: Vector2 = get_parent().to_local(step.global_position) - position
		var half := STEP_SIZE / 2.0
		draw_rect(Rect2(at - half, STEP_SIZE + Vector2(0, 2)), Color(0.42, 0.62, 0.78))
		draw_rect(Rect2(at - half, Vector2(STEP_SIZE.x, 2)), COLOR_FROST)


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
