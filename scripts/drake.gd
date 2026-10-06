extends Node2D
## The Ashen Drake, the Fire slopes' boss: a dragon of charred scales and embers, fought twice.
## Built from parts cut from one drawing (art/bosses/drake_*.png, all on the same 256x144
## canvas, facing right) that the code poses: body (with its wings folded, or bare once they
## spread), neck and head, lower jaw, tail, hind legs, front legs; and a spread wing
## (drake_wing.png, its own canvas) drawn on each side.
##
## Phase 1, the Forge: the fire piece is driven through its folded wing and pins it, so it
## can't fly. It sleeps in the ashes at the forge's west end until Storm comes in, then
## stalks him along the floor and, in a fixed order:
## - Lunge: it crouches, head drawn back, then lunges forward and snaps. Its head stays low
##   afterwards, panting smoke: the opening to hit it.
## - Breath: it lowers its head and its throat glows, then a jet of fire roars straight out
##   at chest height all the way to the far wall. Slide under it, or under the drake itself
##   (its body doesn't hurt while it breathes) and come out behind it.
## - Stomp: it rears up and slams its forefeet down; embers rain from the forge's roof,
##   their glow on the floor showing where.
## And if Storm gets behind it, it raises its tail and lashes it down: a wave of fire runs
## out along the floor behind it to jump.
## Its body hurts to touch; its head doesn't, and both can be struck.
## Beaten, it collapses and the fire piece tears out of its wing and floats down. Then it
## heaves itself up, spreads its wings for the first time, and bursts up through the forge's
## roof, free.
##
## Phase 2, the Drake's roost (open to the sky): it drops out of the smoke when Storm comes,
## and fights on the wing. In a fixed order:
## - Dive: it rears back in the air and roars, then dives at where Storm stood, skims the
##   floor with its claws and climbs away. Step aside, then spin into its back as it skims.
## - Air breath: it hangs high on one side and sweeps a jet of fire along the floor away from
##   itself; the floor burns behind it for a moment. The rocks shelter from the jet.
## - Slam: it climbs above Storm, its shadow following him, then drops onto him; fire runs
##   out both ways along the floor. It stays down, panting, for a while: the big opening.
## - Gust: it hangs facing him and beats its wings three times, each beat pushing him away
##   and throwing embers.
## Below half health its slams shake embers down too. Below a third it heats up: its scales
## glow, its wings catch fire, and it fights faster. Beaten, it makes one last attack: it
## climbs high over the roost, white-hot, wings ablaze, and a ring of fire on the floor
## follows Storm; then it locks on and dives at the ring and blows itself apart. Be out of
## the ring. It's left as ash, with a mask shard in it.
##
## The node's origin is the room's B marker, on the arena's floor.

signal defeated
## Sent when it wakes: the room bars its doors then.
signal engaged

const Effects := preload("res://scripts/effects.gd")
const Projectile := preload("res://scripts/projectile.gd")
const Shard := preload("res://scripts/shard.gd")

const BODY := preload("res://art/bosses/drake_body.png")
## The body with the fire piece still driven through its folded wing.
const BODY_PINNED := preload("res://art/bosses/drake_body_pinned.png")
## The body with its wings spread out of the way (drawn on their own instead).
const BODY_BARE := preload("res://art/bosses/drake_body_bare.png")
const HEAD := preload("res://art/bosses/drake_head.png")
const JAW := preload("res://art/bosses/drake_jaw.png")
const TAIL := preload("res://art/bosses/drake_tail.png")
const HIND := preload("res://art/bosses/drake_hind.png")
const FRONT := preload("res://art/bosses/drake_front.png")
## A spread wing (128x96), its root at WING_ROOT, reaching up and back.
const WING := preload("res://art/bosses/drake_wing.png")

const TILE := 16
const LAYER_WORLD := 1
const LAYER_ENEMY := 4
## Art pixels to world units, and how much bigger than that the wing art is drawn.
const SCALE := 1.05
const WING_SCALE := 1.6
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
const SHOULDER := Vector2(164, 80)
const WING_ROOT := Vector2(108, 72)
const MOUTH := Vector2(250, 66)
const SNOUT_TIP := Vector2(252, 62)
const JAW_TIP := Vector2(244, 72)
const EYE := Vector2(236, 53)
const TAIL_TIP := Vector2(2, 104)
## Which way its head points with the neck at rest (from the neck's base to its mouth).
const HEAD_REST := -0.39
## Where the fire piece is driven through its folded wing.
const PIN := Vector2(146, 70)
const LEG_LENGTH := 27.0 * SCALE
## How far its body sinks as it crouches (its legs bend under it).
const CROUCH_DROP := 16.0
## Its legs tucked back in flight.
const LEGS_TUCKED := 0.7

const WALK_SPEED := 40.0
const LUNGE_DIST := 120.0
## How close to the walls it keeps (its tail and head reach well past its feet).
const WALL_MARGIN := 120.0
## The breath jet's width, and how high phase 1's jet runs where it meets the far wall: its
## underside clears a sliding Storm, not a standing one.
const JET_WIDTH := 16.0
const JET_HEIGHT := 28.0
const PATTERN_1 := ["lunge", "breath", "lunge", "stomp"]

## Phase 2: how high it hangs, how fast it flies about and dives, and where its sweep ends.
const HOVER_ALT := 130.0
const FLY_SPEED := 150.0
const DIVE_SPEED := 380.0
const SLAM_ALT := 200.0
const AIR_JET_REACH := 380.0
const GUST_WIND := 150.0
## Heated (below this share of its health): how much faster it fights.
const HOT_AT := 0.4
const HOT_PACE := 0.75
## The last attack: how high it climbs, how fast it dives, and the blast's reach.
const FINAL_ALT := 210.0
const FINAL_DIVE_SPEED := 520.0
const BLAST_RADIUS := 110.0
## The tip of its spread wing (the leading point) and the back of its trailing edge, in the
## wing art, for where the flames burn when it's heated.
const WING_TIP := Vector2(17, 30)
const WING_TRAIL := Vector2(40, 72)
const PATTERN_2 := ["dive", "breath", "dive", "slam", "gust", "slam"]

const COLOR_FIRE := Color(1.0, 0.5, 0.15)
const COLOR_FIRE_HOT := Color(1.0, 0.85, 0.45)
const COLOR_SMOKE := Color(0.2, 0.18, 0.17)
const COLOR_ASH := Color(0.35, 0.32, 0.3)
const COLOR_MOUTH := Color(0.35, 0.06, 0.02)
const COLOR_EYES := Color(1.0, 0.6, 0.2)
const COLOR_SHADOW := Color(0.05, 0.02, 0.0, 0.5)
const COLOR_PIECE := Color(1.0, 0.62, 0.25)

enum St {
	DORMANT, WAKE, IDLE, TURN, LUNGE_WINDUP, LUNGE, PANT, BREATH_WINDUP, BREATH,
	REAR, SLAM, TAIL_RAISE, TAIL_LASH, SLUMP, RISE, SPREAD, ESCAPE,
	ARRIVE, HOVER, DIVE_WINDUP, DIVE, SKIM, CLIMB, AIR_BREATH_WINDUP, AIR_BREATH, GUST,
	SLAM_RISE, SLAM_FALL, GROUNDED, TAKEOFF, FINAL_RISE, FINAL_AIM, FINAL_DIVE, EXPLODE,
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
## Where it stands (or flies: its feet's height above the floor), which way it faces, and its
## pose: the neck's angle (negative raises the head), how far the jaw hangs open, the tail's
## angle (positive raises it), how far it's crouched, how far it's pitched (radians about its
## hind feet: negative rears back, positive noses down), its stride, its legs' tuck.
var _x := 0.0
var _alt := 0.0
var _dir := 1
var _neck := 0.0
var _jaw := 0.0
var _tail := 0.0
var _crouch := 0.0
var _tilt := 0.0
var _stride := 0.0
var _tuck := 0.0
var _alpha := 1.0
## Its wings: how far spread (0 folded on its back, 1 wide), the beat's phase and the wing's
## angle (positive raised, negative swept down), and how fast they're beating.
var _wings := 0.0
var _beat := 0.0
var _flap := 0.0
var _beat_rate := 7.0
## How long Storm has been behind it (it turns only after a moment).
var _behind := 0.0
var _lunge_from := 0.0
var _lunge_to := 0.0
## The breath's sweep (0 to 1), and where the jet lands right now.
var _sweep := 0.0
var _jet_end := Vector2.ZERO
var _jet_on := false
## Phase 2: its dive (from, toward), where it means to be, the last floor point set alight.
var _dive_from := Vector2.ZERO
var _dive_to := Vector2.ZERO
var _goal := Vector2.ZERO
var _last_flame_x := INF
var _gusts := 0
var _fall_speed := 0.0
## Heated: below a third of its health. _heat is how hot it glows (0 to 1), _wing_fire how
## far its wings burn; the last attack's target on the floor and the blast's growth.
var _hot := false
var _heat := 0.0
var _wing_fire := 0.0
var _blast_at := Vector2.ZERO
var _blast := 0.0
var _blast_box: Hitbox
## The roof it breaks out through at the end of phase 1 (the middle of the "=" cells), and
## whether it has broken it yet.
var _hole_x := 0.0
var _roof_broken := false
## Embers about to fall from above: {x, t}.
var _embers: Array[Dictionary] = []
## The fire piece flying out of its wing (0 to 1, or -1 while it's still in), from where to
## where.
var _piece_t := -1.0
var _piece_from := Vector2.ZERO
var _piece_rest := Vector2.ZERO
## Smoke puffs drifting off it: {pos, vel, life, size}.
var _smoke := []
## Its fight is over and the room has its reward: nothing more is drawn here.
var _done := false

var _head_box: Hitbox
var _body_box: Hitbox
var _legs_box: Hitbox
var _tail_box: Hitbox
var _jet_box: Hitbox


## One of its hurtful or strikable parts. `weak`: struck, it hurts the drake. `harmless`:
## touched, it doesn't hurt Storm. `slide_through`: Storm's slide passes under it instead of
## striking it and bouncing off. `slide_safe`: it doesn't hurt him while he slides.
class Hitbox extends Area2D:
	var boss: Node
	var weak := false
	var harmless := false
	var slide_through := false
	var slide_safe := false

	func take_hit(damage: int, from_dir: Vector2) -> void:
		if weak:
			boss.take_hit(damage, from_dir)


func _ready() -> void:
	hp = max_hp
	z_index = -1
	_floor = position.y
	_x = position.x
	_measure()
	_head_box = _make_box(Vector2(38, 30), true, true)
	_body_box = _make_box(Vector2(110, 40), true, false)
	_legs_box = _make_box(Vector2(104, 22), false, false)
	_tail_box = _make_box(Vector2(92, 20), false, false)
	_jet_box = _make_box(Vector2(10, JET_WIDTH), false, false)
	_blast_box = _make_box(Vector2(1, 1), false, false)
	var blast_shape := CircleShape2D.new()
	blast_shape.radius = BLAST_RADIUS
	(_blast_box.get_child(0) as CollisionShape2D).shape = blast_shape
	_jet_box.slide_through = true
	# Storm can always slide under its belly and legs and out the other side.
	for box in [_head_box, _body_box, _legs_box]:
		box.slide_through = true
		box.slide_safe = true
	for box in [_head_box, _body_box, _legs_box, _tail_box, _jet_box, _blast_box]:
		_set_box(box, false)
	if phase == 1:
		# Asleep: crouched in the ashes, head down.
		_crouch = 1.0
		_neck = 0.35
	else:
		# Somewhere up in the smoke, out of sight.
		_alt = 420.0
		_wings = 1.0
		_tuck = LEGS_TUCKED
		_alpha = 0.0


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
	var cells := 0
	for i in room.size_tiles.x:
		if room._cell(i, 0) == "=":
			_hole_x += (i + 0.5) * TILE
			cells += 1
	_hole_x = _hole_x / cells if cells > 0 else position.x


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
	if not _fighting():
		return
	hp -= damage
	_flash = 0.1
	Sfx.play("hit_boss", -3.0)
	Effects.sparks(get_parent(), _head_point() if _near_head() else _body_point(), COLOR_FIRE, 14)
	if phase == 2 and not _hot and hp > 0 and hp <= int(max_hp * HOT_AT):
		# Heating up: it roars, its scales glowing and its wings catching.
		_hot = true
		_shake = 0.8
		Sfx.play("roar", 0.0, 0.0)
		Sfx.play("fire_breath", -2.0, 0.0)
		Sfx.play("burst", -2.0, 0.0)
		# It bursts into flame: a ring of fire off its body, its wings catching at once.
		for i in 30:
			var at := _body_point() + Vector2.from_angle(TAU * i / 30.0) * randf_range(30, 70)
			Effects.sparks(get_parent(), at, COLOR_FIRE if i % 2 else COLOR_FIRE_HOT, 2, 140.0)
			_puff(at, (at - _body_point()).normalized() * 30.0, 6.0)
	if hp <= 0:
		hp = 0
		Effects.slow_motion(get_tree())
		remove_from_group("shock_target")
		remove_from_group("boss")
		_embers.clear()
		_jet_on = false
		_set_wind(0.0)
		if phase == 1:
			_enter(St.SLUMP, 2.6)
		else:
			_hot = true
			_enter(St.FINAL_RISE, 2.0)


## Whether it's awake and can be hurt.
func _fighting() -> bool:
	return _state not in [St.DORMANT, St.WAKE, St.ARRIVE, St.SLUMP, St.RISE, St.SPREAD, St.ESCAPE,
		St.FINAL_RISE, St.FINAL_AIM, St.FINAL_DIVE, St.EXPLODE]


## Whether Storm is nearer its head than its body (for where the sparks fly).
func _near_head() -> bool:
	var player := _player()
	return player != null and player.position.distance_to(_head_point()) < player.position.distance_to(_body_point())


# --- Geometry ---

## A point on the art canvas placed in the room, for where it stands or flies, which way it
## faces, how low it's crouched and how far it's pitched.
func _w(art: Vector2) -> Vector2:
	var off := (art - ART_ORIGIN) * SCALE
	off.x *= _dir
	var foot := (HIND_FOOT - ART_ORIGIN) * SCALE
	foot.x *= _dir
	off = foot + (off - foot).rotated(_tilt * _dir)
	return Vector2(_x, _floor - _alt + CROUCH_DROP * _crouch) + off


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
	return _tail - minf(_tilt, 0.0) * 1.1


func _pin_point() -> Vector2:
	return _w(PIN)


## Where its body's middle is relative to its feet (for aiming dives).
func _body_offset() -> Vector2:
	var off := (Vector2(150, 92) - ART_ORIGIN) * SCALE
	off.x *= _dir
	return off


# --- Behaviour ---

func _physics_process(delta: float) -> void:
	_time += delta
	_flash -= delta
	_timer -= delta
	var player := _player()
	var p := player.position if player else Vector2(_x, _floor)
	_update_embers(delta)
	_update_smoke(delta)
	_update_wings(delta)
	if _hot:
		var final := _state in [St.FINAL_RISE, St.FINAL_AIM, St.FINAL_DIVE]
		_heat = move_toward(_heat, 1.0 if final else 0.75, delta * 1.2)
		_wing_fire = move_toward(_wing_fire, 1.0, delta * 1.5)
		if fmod(_time, 0.08) < delta and _alpha > 0.0:
			_puff(_w(SHOULDER) + Vector2(randf_range(-40, 40), randf_range(-50, 0)), Vector2(randf_range(-10, 10), -24.0), 4.0)
	if phase == 1:
		_phase_1(p, delta)
	else:
		_phase_2(p, delta)
	_update_jet()
	_update_boxes()
	_update_shake(delta)
	queue_redraw()


func _enter(state: St, time := 0.0) -> void:
	_state = state
	if _hot and state not in [St.FINAL_RISE, St.FINAL_AIM, St.FINAL_DIVE, St.EXPLODE]:
		time *= HOT_PACE
	_timer = time
	match state:
		St.WAKE, St.SLUMP, St.SPREAD, St.ARRIVE:
			Sfx.play("roar", -1.0, 0.04)
		St.DIVE_WINDUP, St.SLAM_RISE:
			Sfx.play("roar", -4.0, 0.1)
		St.LUNGE:
			Sfx.play("swing", -2.0)
		St.BREATH, St.AIR_BREATH:
			Sfx.play("fire_breath", -2.0, 0.03)
		St.SLAM, St.GROUNDED:
			Sfx.play("slam", -2.0)
		St.TAIL_LASH:
			Sfx.play("burst", -4.0)
		St.LUNGE_WINDUP, St.REAR:
			Sfx.play("rumble", -6.0)
		St.DIVE:
			Sfx.play("screech", -8.0, 0.0)
		St.FINAL_RISE:
			Sfx.play("roar", 0.0, 0.0)
		St.FINAL_DIVE:
			Sfx.play("screech", -2.0, 0.0)
			Sfx.play("fire_breath", -2.0, 0.0)


func _wake() -> void:
	engaged.emit()
	add_to_group("boss")
	add_to_group("shock_target")
	_shake = 0.8
	if phase == 1:
		_enter(St.WAKE, 2.0)
	else:
		_enter(St.ARRIVE, 2.4)


func _next_attack() -> String:
	var pattern: Array = PATTERN_1 if phase == 1 else PATTERN_2
	var attack: String = pattern[_move % pattern.size()]
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
			if _side(p) < 0 and gap < 150.0 and _timer <= 0.0:
				_enter(St.TAIL_RAISE, 0.55)
			elif _behind > 0.7:
				_enter(St.TURN, 0.3)
			elif _timer <= 0.0:
				match _next_attack():
					"lunge":
						_enter(St.LUNGE_WINDUP, 0.6)
					"breath":
						_enter(St.BREATH_WINDUP, 1.1)
					"stomp":
						_enter(St.REAR, 0.7)
			elif gap > 140.0 and _side(p) > 0:
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
				_lunge_to = clampf(_x + _dir * LUNGE_DIST, _left + WALL_MARGIN, _right - WALL_MARGIN)
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
			# It crouches, head low and level, and its throat glows.
			_crouch = move_toward(_crouch, 1.0, 2.0 * delta)
			_aim_head(_breath_target(), 6.0 * delta)
			_jaw = lerpf(_jaw, 0.35, 4.0 * delta)
			if fmod(_time, 0.12) < delta:
				_puff(_mouth(), Vector2(_dir * 8.0, -16.0), 3.0)
			if _timer <= 0.0:
				_jet_on = true
				_enter(St.BREATH, 1.3)
		St.BREATH:
			_jaw = 0.7 + 0.08 * sin(_time * 30.0)
			_aim_head(_breath_target(), 10.0 * delta)
			if _timer <= 0.0:
				_jet_on = false
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
				_piece_rest = Vector2((_left + _right) / 2.0, _floor - 48.0)
				_shake = 0.5
				Sfx.play("burst", -2.0)
				for i in 8:
					Effects.sparks(get_parent(), _piece_from, COLOR_FIRE, 4, 120.0)
			if _piece_t >= 0.0:
				_piece_t = minf(_piece_t + delta / 1.2, 1.0)
			if _timer <= 0.0:
				_enter(St.RISE, 6.0)
		St.RISE:
			# Free of the piece, it heaves itself up and walks under the roof it'll break.
			_crouch = move_toward(_crouch, 0.0, 2.0 * delta)
			_neck = lerp_angle(_neck, -0.3, 4.0 * delta)
			_jaw = lerpf(_jaw, 0.0, 4.0 * delta)
			var to := _hole_x - _x
			if absf(to) > 6.0 and _timer > 0.0:
				_dir = 1 if to > 0.0 else -1
				_walk(signf(to) * 90.0, delta, false)
			elif _crouch <= 0.0:
				_enter(St.SPREAD, 1.3)
		St.SPREAD:
			# Its wings unfold for the first time, and it roars up at the roof.
			_wings = move_toward(_wings, 1.0, delta / 0.8)
			_neck = lerp_angle(_neck, -0.8, 3.0 * delta)
			_jaw = lerpf(_jaw, 0.6, 4.0 * delta)
			_tilt = lerp_angle(_tilt, -0.25, 3.0 * delta)
			_beat_rate = 3.0
			if _timer <= 0.0:
				_beat_rate = 9.0
				_enter(St.ESCAPE, 5.0)
		St.ESCAPE:
			# Up, wings beating hard; it bursts through the roof and is gone.
			_alt += (60.0 + (5.0 - _timer) * 120.0) * delta
			_tuck = move_toward(_tuck, LEGS_TUCKED, 2.0 * delta)
			_jaw = lerpf(_jaw, 0.0, 4.0 * delta)
			_neck = lerp_angle(_neck, -0.6, 3.0 * delta)
			if not _roof_broken and _on_part(HEAD_PIVOT, _neck, Vector2(220, 36)).y < TILE * 1.5:
				_roof_broken = true
				_shake = 1.0
				var room := get_parent()
				if room.has_method("break_lid"):
					room.break_lid(COLOR_ASH)
			if _w(TAIL_TIP).y < -2.0 * TILE * 6.0 or _timer <= 0.0:
				_finish()


## Phase 2: on the wing in its roost.
func _phase_2(p: Vector2, delta: float) -> void:
	match _state:
		St.DORMANT:
			if p.x < _right - 8.0 * TILE:
				_x = clampf(p.x - 140.0, _left + WALL_MARGIN, _right - WALL_MARGIN)
				_dir = 1 if p.x > _x else -1
				_wake()
		St.ARRIVE:
			# Down out of the smoke, roaring.
			_alpha = move_toward(_alpha, 1.0, delta * 2.0)
			_alt = lerpf(_alt, HOVER_ALT, 2.0 * delta)
			_neck = lerp_angle(_neck, -0.5, 3.0 * delta)
			_jaw = lerpf(_jaw, 0.6 if _timer < 1.6 else 0.0, 5.0 * delta)
			if _timer <= 0.0:
				_enter(St.HOVER, 0.8)
		St.HOVER:
			# Hanging off to one side of Storm, bobbing on its wingbeats.
			_face(p)
			var side := -1 if p.x > (_left + _right) / 2.0 else 1
			_goal = Vector2(p.x + side * 170.0, HOVER_ALT + sin(_time * 1.3) * 10.0)
			_fly_to(_goal, FLY_SPEED, delta)
			_air_pose(delta)
			if _timer <= 0.0:
				match _next_attack():
					"dive":
						_enter(St.DIVE_WINDUP, 0.75)
					"breath":
						var far_side := 1 if p.x < (_left + _right) / 2.0 else -1
						_goal = Vector2((_right - WALL_MARGIN) if far_side > 0 else (_left + WALL_MARGIN), HOVER_ALT + 10.0)
						_enter(St.AIR_BREATH_WINDUP, 1.4)
					"slam":
						_enter(St.SLAM_RISE, 1.1)
					"gust":
						_gusts = 0
						_enter(St.GUST, 2.4)
		St.DIVE_WINDUP:
			# It rears back in the air and roars, then locks on.
			_face(p)
			_alt += 30.0 * delta
			_tilt = lerp_angle(_tilt, -0.3, 5.0 * delta)
			_neck = lerp_angle(_neck, -0.4, 5.0 * delta)
			_jaw = lerpf(_jaw, 0.6, 5.0 * delta)
			_beat_rate = 12.0
			if _timer <= 0.0:
				_dive_from = Vector2(_x, _alt)
				# Aim its body's middle at him (low enough to rake the floor).
				_dive_to = Vector2(p.x - _body_offset().x, 0.0)
				_enter(St.DIVE, 0.0)
		St.DIVE:
			_jaw = lerpf(_jaw, 0.0, 5.0 * delta)
			_beat_rate = 2.0
			var to := _dive_to - Vector2(_x, _alt)
			var step := DIVE_SPEED * delta
			_tilt = lerp_angle(_tilt, 0.35, 8.0 * delta)
			_tuck = move_toward(_tuck, -0.3, 4.0 * delta)  # claws out
			if to.length() <= step:
				_x = _dive_to.x
				_alt = _dive_to.y
				_enter(St.SKIM, 0.4)
			else:
				var v := to.normalized() * step
				_x += v.x
				_alt += v.y
		St.SKIM:
			# Claws raking the floor, carrying on the way it dived: the moment to spin into it.
			_x = clampf(_x + _dir * 260.0 * delta, _left + 60.0, _right - 60.0)
			_tilt = lerp_angle(_tilt, 0.0, 8.0 * delta)
			if fmod(_time, 0.05) < delta:
				Effects.sparks(get_parent(), Vector2(_w(Vector2(190, 131)).x, _floor - 2), COLOR_FIRE, 3, 90.0)
			if _timer <= 0.0:
				_enter(St.CLIMB, 1.0)
		St.CLIMB:
			_x = clampf(_x + _dir * 140.0 * delta, _left + WALL_MARGIN * 0.5, _right - WALL_MARGIN * 0.5)
			_alt = lerpf(_alt, HOVER_ALT, 2.5 * delta)
			_tilt = lerp_angle(_tilt, -0.25, 5.0 * delta)
			_tuck = move_toward(_tuck, LEGS_TUCKED, 3.0 * delta)
			_beat_rate = 10.0
			if _timer <= 0.0:
				_enter(St.HOVER, 0.9)
		St.AIR_BREATH_WINDUP:
			# Off to the far side and up, throat glowing.
			_fly_to(_goal, FLY_SPEED * 1.4, delta)
			_dir = 1 if _x < (_left + _right) / 2.0 else -1
			_air_pose(delta, false)
			_neck = lerp_angle(_neck, 0.2, 4.0 * delta)
			_jaw = lerpf(_jaw, 0.35, 4.0 * delta)
			if fmod(_time, 0.12) < delta:
				_puff(_mouth(), Vector2(_dir * 8.0, -16.0), 3.0)
			if _timer <= 0.0:
				_sweep = 0.0
				_jet_on = true
				_last_flame_x = INF
				_enter(St.AIR_BREATH, 1.7)
		St.AIR_BREATH:
			# The jet sweeps along the floor away from it; the floor burns where it passed.
			_sweep = clampf(1.0 - _timer / 1.7, 0.0, 1.0)
			_alt = lerpf(_alt, HOVER_ALT + 10.0, 2.0 * delta)
			_jaw = 0.7 + 0.08 * sin(_time * 30.0)
			_air_pose(delta, false)
			var target := Vector2(_x + _dir * lerpf(30.0, AIR_JET_REACH, _sweep), _floor)
			_aim_head(target, 10.0 * delta)
			if _jet_end.y >= _floor - 2.0 and absf(_jet_end.x - _last_flame_x) > 20.0:
				_last_flame_x = _jet_end.x
				_spawn("flame", Vector2(_jet_end.x, _floor), Vector2.ZERO, 0.0, 1.6 + (1.0 - _sweep) * 0.6)
			if _timer <= 0.0:
				_jet_on = false
				_enter(St.HOVER, 1.0)
		St.GUST:
			# Facing him, three great wingbeats, each shoving him away and throwing embers.
			_face(p)
			var away := 1 if p.x > _x else -1
			_fly_to(Vector2(p.x - away * 180.0, 80.0), FLY_SPEED * 0.6, delta)
			_air_pose(delta, false)
			_beat_rate = 4.0
			var beat := int((2.4 - _timer) / 0.7)
			var in_beat := fmod(2.4 - _timer, 0.7)
			_set_wind(away * GUST_WIND if beat < 3 and in_beat > 0.25 and in_beat < 0.65 else 0.0)
			if beat < 3 and beat >= _gusts and in_beat > 0.25:
				_gusts += 1
				Sfx.play("wing", -2.0)
				_shake = 0.15
				for i in 2:
					_spawn("ember", _body_point() + Vector2(away * 40.0, randf_range(-30, 30)),
						Vector2(away * randf_range(170, 230), randf_range(-40, 20)), 120.0, 3.0)
			if _timer <= 0.0:
				_set_wind(0.0)
				_enter(St.HOVER, 0.7)
		St.SLAM_RISE:
			# Up above him, its shadow following him across the floor.
			_face(p)
			_fly_to(Vector2(p.x - _body_offset().x, SLAM_ALT), FLY_SPEED * 1.6, delta)
			_air_pose(delta)
			_beat_rate = 11.0
			if _timer <= 0.0:
				_fall_speed = 0.0
				_enter(St.SLAM_FALL, 2.0)
		St.SLAM_FALL:
			_fall_speed = minf(_fall_speed + 1600.0 * delta, 560.0)
			_alt -= _fall_speed * delta
			_tuck = move_toward(_tuck, 0.0, 6.0 * delta)
			_beat_rate = 0.0
			_flap = lerp_angle(_flap, 0.55, 10.0 * delta)
			if _alt <= 0.0:
				_alt = 0.0
				_shake = 0.6
				for side in [-1, 1]:
					_spawn("fire_wave", Vector2(_x + side * 70.0, _floor), Vector2(side * 170.0, 0), 0.0, 3.0)
				for i in 8:
					_debris(Vector2(_x + randf_range(-70, 70), _floor - 2))
				if hp <= max_hp / 2:
					_rain_embers(p)
				_enter(St.GROUNDED, 2.2)
		St.GROUNDED:
			# Down on the floor, head low, panting: hit it.
			_tuck = move_toward(_tuck, 0.0, 6.0 * delta)
			_crouch = move_toward(_crouch, 0.6, 3.0 * delta)
			_neck = lerp_angle(_neck, 0.5, 4.0 * delta)
			_jaw = 0.25 + 0.15 * sin(_time * 9.0)
			_tilt = lerp_angle(_tilt, 0.0, 6.0 * delta)
			_beat_rate = 0.0
			_flap = lerp_angle(_flap, -0.5, 4.0 * delta)
			if fmod(_time, 0.25) < delta:
				_puff(_mouth(), Vector2(_dir * 10.0, -14.0), 3.0)
			if _timer <= 0.0:
				_enter(St.TAKEOFF, 0.7)
		St.TAKEOFF:
			_crouch = move_toward(_crouch, 0.0, 4.0 * delta)
			_beat_rate = 12.0
			_alt = lerpf(_alt, HOVER_ALT * 0.6, 3.0 * delta)
			_neck = lerp_angle(_neck, -0.2, 4.0 * delta)
			_tuck = move_toward(_tuck, LEGS_TUCKED, 2.0 * delta)
			if _timer <= 0.0:
				_enter(St.HOVER, 0.6)
		St.FINAL_RISE:
			# Beaten, it won't fall: it climbs high over the roost, white-hot, wings ablaze.
			_fly_to(Vector2((_left + _right) / 2.0, FINAL_ALT), FLY_SPEED * 1.2, delta)
			_face(p)
			_air_pose(delta, false)
			_beat_rate = 12.0
			_neck = lerp_angle(_neck, -0.7, 3.0 * delta)
			_jaw = lerpf(_jaw, 0.7, 4.0 * delta)
			_shake = maxf(_shake, 0.05 + 0.25 * (1.0 - _timer / 2.0))
			_blast_at = Vector2(p.x, _floor)
			if fmod(_time, 0.05) < delta:
				Effects.sparks(get_parent(), _body_point() + Vector2(randf_range(-80, 80), randf_range(-30, 30)),
					COLOR_FIRE, 2, 90.0)
			if _timer <= 0.0:
				_enter(St.FINAL_AIM, 1.1)
		St.FINAL_AIM:
			# The ring of fire on the floor follows him, then holds: the moment to get out.
			_face(p)
			_air_pose(delta, false)
			_tilt = lerp_angle(_tilt, -0.3, 4.0 * delta)
			_beat_rate = 14.0
			if _timer > 0.35:
				_blast_at = _blast_at.lerp(Vector2(p.x, _floor), 6.0 * delta)
			if _timer <= 0.0:
				_dive_to = Vector2(_blast_at.x - _body_offset().x, 0.0)
				_enter(St.FINAL_DIVE)
		St.FINAL_DIVE:
			_beat_rate = 0.0
			_flap = lerp_angle(_flap, 0.55, 10.0 * delta)
			_tilt = lerp_angle(_tilt, 0.6, 8.0 * delta)
			_tuck = move_toward(_tuck, LEGS_TUCKED, 4.0 * delta)
			var to := _dive_to - Vector2(_x, _alt)
			var step := FINAL_DIVE_SPEED * delta
			if fmod(_time, 0.03) < delta:
				_puff(_body_point(), Vector2(randf_range(-20, 20), randf_range(-30, 0)), 6.0)
			if to.length() <= step:
				_x = _dive_to.x
				_alt = 0.0
				_explode()
			else:
				var v := to.normalized() * step
				_x += v.x
				_alt += v.y
		St.EXPLODE:
			# Blown apart: the blast spreads and burns out, leaving ash drifting down.
			_blast = minf(_blast + delta / 0.35, 1.0)
			if fmod(_time, 0.05) < delta and _timer > 0.6:
				var at := _blast_at + Vector2(randf_range(-BLAST_RADIUS, BLAST_RADIUS), randf_range(-60, 0))
				_puff(at, Vector2(randf_range(-10, 10), -20.0), 7.0)
			if _timer <= 0.0:
				_finish()


## Its last attack lands: a great blast of fire where it struck, hurting all it reaches.
func _explode() -> void:
	_alpha = 0.0
	_blast = 0.0
	_shake = 1.2
	_piece_rest = Vector2(clampf(_blast_at.x, _left + 40.0, _right - 40.0), _floor - TILE)
	Sfx.play("burst", 2.0, 0.0)
	Sfx.play("slam", 2.0, 0.0)
	Sfx.play("fire_breath", 0.0, 0.0)
	Effects.slow_motion(get_tree(), 0.3, 0.6)
	for i in 40:
		Effects.sparks(get_parent(), _blast_at + Vector2(randf_range(-30, 30), randf_range(-40, 0)),
			COLOR_FIRE if i % 3 else COLOR_FIRE_HOT, 3, 260.0)
	for i in 16:
		_debris(_blast_at + Vector2(randf_range(-BLAST_RADIUS, BLAST_RADIUS), -2))
	_enter(St.EXPLODE, 2.2)


func _finish() -> void:
	_alpha = 0.0
	_done = true
	_set_wind(0.0)
	Game.defeated[boss_id] = true
	_restore_camera()
	defeated.emit()
	set_physics_process(false)
	queue_redraw()


## Easing back to standing at rest, breathing.
func _relax(settle: float) -> void:
	_crouch = move_toward(_crouch, 0.0, settle * 0.5)
	_tilt = lerp_angle(_tilt, 0.0, settle)
	_neck = lerp_angle(_neck, -0.05 + sin(_time * 1.6) * 0.04, settle)
	_jaw = lerpf(_jaw, 0.0, settle)
	_tail = lerp_angle(_tail, sin(_time * 1.1) * 0.06, settle)


## How it holds itself on the wing: level, legs tucked, tail streaming, head toward him.
func _air_pose(delta: float, settle_neck := true) -> void:
	_tilt = lerp_angle(_tilt, 0.0, 4.0 * delta)
	_tuck = move_toward(_tuck, LEGS_TUCKED, 3.0 * delta)
	_crouch = move_toward(_crouch, 0.0, 3.0 * delta)
	_tail = lerp_angle(_tail, sin(_time * 2.0) * 0.1, 4.0 * delta)
	_beat_rate = lerpf(_beat_rate, 7.0, 3.0 * delta)
	if settle_neck:
		_neck = lerp_angle(_neck, 0.1 + sin(_time * 1.6) * 0.05, 4.0 * delta)
		_jaw = lerpf(_jaw, 0.0, 4.0 * delta)


func _face(p: Vector2) -> void:
	if absf(p.x - _x) > 40.0:
		_dir = 1 if p.x > _x else -1


## Flies toward (x, height above the floor), slowing as it gets there.
func _fly_to(goal: Vector2, speed: float, delta: float) -> void:
	goal.x = clampf(goal.x, _left + WALL_MARGIN * 0.5, _right - WALL_MARGIN * 0.5)
	var to := goal - Vector2(_x, _alt)
	var v := to.limit_length(1.0) * speed * clampf(to.length() / 40.0, 0.15, 1.0)
	_x += v.x * delta
	_alt += v.y * delta


## Turns its head (and neck) to point its mouth at a spot in the room (`weight` is how far
## toward it this frame).
func _aim_head(target: Vector2, weight: float) -> void:
	var to := target - _w(HEAD_PIVOT)
	var aim := atan2(to.y, to.x * _dir) - _tilt  # as if it faced right
	_neck = lerp_angle(_neck, clampf(aim - HEAD_REST, -0.8, 1.1), clampf(weight, 0.0, 1.0))


## Its wings beat on their own rhythm; a sound on each downstroke.
func _update_wings(delta: float) -> void:
	if _wings <= 0.0 or _beat_rate <= 0.0:
		return
	var before := sin(_beat)
	_beat += _beat_rate * delta
	var s := sin(_beat)
	_flap = lerpf(-0.6, 0.55, (s + 1.0) / 2.0)
	if before > 0.0 and s <= 0.0 and _state != St.GUST:
		Sfx.play("wing", -12.0, 0.15)


func _walk(speed: float, delta: float, keep_in := true) -> void:
	_x += speed * delta
	if keep_in:
		_x = clampf(_x, _left + WALL_MARGIN, _right - WALL_MARGIN)
	_stride += delta * absf(speed) / 6.0


## Where phase 1's breath is aimed: straight out at chest height to the far wall.
func _breath_target() -> Vector2:
	return Vector2(_right if _dir > 0 else _left, _floor - JET_HEIGHT)


## The jet runs from its mouth the way its head points until it hits rock.
func _update_jet() -> void:
	if not _jet_on:
		return
	var from := _mouth()
	var angle := _neck + HEAD_REST + _tilt  # as if it faced right
	var heading := Vector2(cos(angle) * _dir, sin(angle))
	var to := from + heading * 700.0
	var room := get_parent()
	var query := PhysicsRayQueryParameters2D.create(room.to_global(from), room.to_global(to), LAYER_WORLD)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	_jet_end = room.to_local(hit.position) if hit else to
	if fmod(_time, 0.05) < get_physics_process_delta_time():
		Effects.sparks(room, _jet_end, COLOR_FIRE, 3, 80.0)


func _rain_embers(p: Vector2) -> void:
	for i in 7:
		var x := clampf(p.x + (i - 3) * 48.0 + randf_range(-10, 10), _left + 12.0, _right - 12.0)
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


func _set_wind(push: float) -> void:
	var player := _player()
	if player and "wind" in player:
		player.wind = push


func _update_boxes() -> void:
	# The blast hurts for its first moment.
	_set_box(_blast_box, _state == St.EXPLODE and _timer > 1.9, _blast_at + Vector2(0, -BLAST_RADIUS * 0.4))
	# Diving at the ring, its body still hurts.
	if _state == St.FINAL_DIVE:
		_set_box(_body_box, true, _body_point(), _tilt * _dir)
		_body_box.harmless = false
		return
	var alive := _fighting()
	var head_angle := (_neck + _tilt) * _dir
	_set_box(_head_box, alive, _head_point(), head_angle)
	# Braced and breathing fire, it doesn't hurt to touch: there's room to slide under it.
	var braced := _state in [St.BREATH_WINDUP, St.BREATH]
	_body_box.harmless = braced
	_set_box(_body_box, alive, _body_point(), _tilt * _dir)
	_set_box(_legs_box, alive and not braced, _w(Vector2(160, 118 - 10.0 * _tuck)), _tilt * _dir)
	var tail_mid := _on_part(TAIL_PIVOT, _tail_angle(), Vector2(50, 98))
	var tail_angle := (_tail_angle() + _tilt) * _dir
	_set_box(_tail_box, _state == St.TAIL_LASH, tail_mid, tail_angle)
	if _jet_on and alive:
		var from := _mouth()
		var shape: RectangleShape2D = _jet_box.get_child(0).shape
		shape.size = Vector2(maxf(from.distance_to(_jet_end), 1.0), JET_WIDTH)
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


func _debris(at: Vector2) -> void:
	var room := get_parent()
	if room.has_method("_spawn_debris"):
		room._spawn_debris(at, COLOR_ASH)


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
	_set_wind(0.0)


## Where its reward appears: the fire piece where it floated down (phase 1), or the mask
## shard where it burned away (phase 2).
func reward_point() -> Vector2:
	return _piece_rest


# --- Art ---

func _draw() -> void:
	if _done:
		return
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	if _state == St.DORMANT:
		tint = Color(0.7, 0.66, 0.64)
	if _heat > 0.0:
		# Heating up: its scales glow ember-orange, then white-hot.
		var hot := Color(2.1, 1.05, 0.55).lerp(Color(2.6, 2.1, 1.5), clampf((_heat - 0.75) / 0.25, 0.0, 1.0))
		tint = Color(tint.r, tint.g, tint.b).lerp(hot, clampf(_heat, 0.0, 1.0) * 0.85)
	tint.a = _alpha
	if _state in [St.FINAL_RISE, St.FINAL_AIM, St.FINAL_DIVE]:
		# The ring of fire on the floor where it'll strike.
		var held := _state != St.FINAL_RISE and (_state == St.FINAL_DIVE or _timer <= 0.35)
		var pulse := 0.5 + 0.5 * sin(_time * (20.0 if held else 8.0))
		var at := _blast_at - position
		_draw_ellipse(at, Vector2(BLAST_RADIUS, 7.0), Color(COLOR_FIRE, 0.12 + 0.12 * pulse))
		draw_arc(at, BLAST_RADIUS, PI, TAU, 32, Color(COLOR_FIRE, 0.25 + 0.35 * pulse), 2.0)
		_draw_ellipse(at, Vector2(BLAST_RADIUS * 0.15, 3.0), Color(COLOR_FIRE_HOT, 0.4 + 0.4 * pulse))
	if _state == St.EXPLODE:
		# The blast: a dome of fire swelling and burning out.
		var at := _blast_at - position
		var grow := ease(_blast, 0.4)
		var fade := clampf(_timer / 2.2, 0.0, 1.0)
		draw_circle(at, BLAST_RADIUS * (0.5 + 0.7 * grow), Color(COLOR_FIRE, 0.35 * fade))
		draw_circle(at, BLAST_RADIUS * (0.3 + 0.5 * grow), Color(COLOR_FIRE_HOT, 0.45 * fade))
		draw_circle(at, BLAST_RADIUS * 0.25 * (1.0 - _blast), Color(1, 1, 1, 0.8 * fade))
	for ember in _embers:
		# A glow on the floor where each ember will land, brightening as it nears.
		var grow := clampf(1.0 - ember.t / 0.9, 0.2, 1.0)
		_draw_ellipse(Vector2(ember.x, _floor) - position, Vector2(4.0 + 6.0 * grow, 2.0), Color(COLOR_FIRE, 0.25 + 0.3 * grow))
	if _alpha > 0.0:
		# Its shadow on the floor: smaller and fainter the higher it flies.
		var high := clampf(_alt / 250.0, 0.0, 1.0)
		var shadow_x := _w(Vector2(150, 131)).x
		_draw_ellipse(Vector2(shadow_x, _floor) - position, Vector2(lerpf(80.0, 36.0, high), lerpf(5.0, 3.0, high)),
			Color(COLOR_SHADOW, COLOR_SHADOW.a * _alpha * lerpf(1.0, 0.6, high)))
		if _heat > 0.0:
			# A haze of heat and fire around it.
			var flicker := 0.85 + 0.15 * sin(_time * 13.0)
			var core := _body_point() - position
			draw_circle(core, 90.0 * flicker, Color(COLOR_FIRE, 0.07 * _heat * _alpha))
			draw_circle(core, 60.0 * flicker, Color(COLOR_FIRE, 0.1 * _heat * _alpha))
			draw_circle(core, 34.0 * flicker, Color(COLOR_FIRE_HOT, 0.1 * _heat * _alpha))
		_draw_drake(tint)
	if phase == 1 and _piece_t >= 0.0:
		_draw_piece_free()
	for s in _smoke:
		draw_circle(s.pos - position, s.size, Color(COLOR_SMOKE, 0.5 * clampf(s.life, 0.0, 1.0)))
	if _jet_on:
		_draw_jet()


func _draw_drake(tint: Color) -> void:
	var swing := sin(_stride) * 0.22
	var squash := clampf((LEG_LENGTH - CROUCH_DROP * _crouch) / LEG_LENGTH, 0.35, 1.0)
	var lift := 0.0
	if _state == St.REAR or _state == St.SLAM:
		lift = -_tilt * 0.6  # forelegs reach forward as it rears
	var spread := _wings > 0.0
	if spread:
		# The far wing, behind it all, a little behind the near one's beat.
		_draw_wing(_flap * 0.85 - 0.12, Color(tint.r * 0.55, tint.g * 0.55, tint.b * 0.55, tint.a),
			Vector2(8, -2))
	_draw_part(TAIL, TAIL_PIVOT, _tail_angle(), tint)
	_draw_part(HIND, HIND_PIVOT, swing + _tuck, tint, squash)
	_draw_part(FRONT, FRONT_PIVOT, -swing - lift + _tuck, tint, 1.0 if lift > 0.0 else squash)
	# The inside of its mouth shows as the jaw drops.
	if _jaw > 0.05:
		var glow := COLOR_MOUTH
		if _state in [St.BREATH_WINDUP, St.BREATH, St.AIR_BREATH_WINDUP, St.AIR_BREATH]:
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
	var body: Texture2D = BODY_BARE if spread else (BODY_PINNED if phase == 1 and _piece_t < 0.0 else BODY)
	_draw_part(body, BODY_PIVOT, 0.0, tint)
	if spread:
		_draw_wing(_flap, tint, Vector2.ZERO)
		if _wing_fire > 0.0:
			_draw_wing_fire(_flap, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)
	# Its eyes: dark while it sleeps, glowing otherwise; its throat lit before the breath.
	if _state != St.DORMANT:
		var eye := _on_part(HEAD_PIVOT, _neck, EYE) - position
		draw_circle(eye, 4.0, Color(COLOR_EYES, (0.3 + 0.15 * sin(_time * 5.0)) * tint.a))
	if _state == St.BREATH_WINDUP or _state == St.AIR_BREATH_WINDUP:
		var total := 1.1 if _state == St.BREATH_WINDUP else 1.4
		var grow := clampf(1.0 - _timer / total, 0.0, 1.0)
		# A glow kept inside its open jaws (the inside of the mouth is lit up too).
		var inside := (_on_part(HEAD_PIVOT, _neck, Vector2(238, 64)) + _jaw_point(Vector2(236, 66))) / 2.0 - position
		draw_circle(inside, 2.0 + 2.5 * grow, Color(COLOR_FIRE_HOT, 0.55 * grow))


## Flames along a burning wing: from its root out to the tip, and back along the trailing
## edge, as far as the fire has spread.
func _draw_wing_fire(angle: float, nudge: Vector2) -> void:
	var size := SCALE * WING_SCALE * lerpf(0.3, 1.0, _wings)
	var root := _w(SHOULDER + nudge) - position
	var turn := (angle + _tilt) * _dir
	var points: Array[Vector2] = []
	for i in 7:
		points.append(WING_ROOT.lerp(WING_TIP, i / 6.0))
	for i in 5:
		points.append(WING_TIP.lerp(WING_TRAIL, (i + 1) / 5.0))
	var shown := int(ceil(points.size() * _wing_fire))
	for i in shown:
		var off := (points[i] - WING_ROOT) * size
		off.x *= _dir
		var at := root + off.rotated(turn)
		var flicker := 0.7 + 0.3 * sin(_time * 25.0 + i * 1.7)
		var r := (4.0 + 3.0 * float(i % 3)) * flicker
		draw_circle(at, r + 3.0, Color(COLOR_FIRE, 0.3))
		draw_circle(at + Vector2(0, -2), r, Color(COLOR_FIRE, 0.8))
		draw_circle(at + Vector2(0, -3), r * 0.5, Color(COLOR_FIRE_HOT, 0.9))


## A spread wing from its shoulder; small while it's still unfolding.
func _draw_wing(angle: float, tint: Color, nudge: Vector2) -> void:
	var size := SCALE * WING_SCALE * lerpf(0.3, 1.0, _wings)
	draw_set_transform(_w(SHOULDER + nudge) - position, (angle + _tilt) * _dir, Vector2(size * _dir, size))
	draw_texture(WING, -WING_ROOT, tint)
	draw_set_transform(Vector2.ZERO)


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


## Torn free of its wing: floating up and out into the middle of the forge, turning upright
## as it settles.
func _draw_piece_free() -> void:
	var t := _piece_t
	var at := _piece_from.lerp(_piece_rest, ease(t, -1.8)) - Vector2(0, sin(t * PI) * 40.0) - position
	Shard.draw_piece(self, "double_jump", at, (1.0 - ease(t, 0.5)) * TAU * 1.5)


## The jet of fire from its mouth to where it lands: flickering blobs swelling outward.
func _draw_jet() -> void:
	var from := _mouth() - position
	var to := _jet_end - position
	var length := from.distance_to(to)
	var steps := int(length / 6.0)
	for i in steps:
		var t := float(i) / maxf(1.0, steps - 1)
		# Narrow at the lips (no wider than its open mouth), swelling as it goes.
		var jitter := lerpf(0.3, 2.0, t)
		var at := from.lerp(to, t) + Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
		var r := lerpf(1.5, JET_WIDTH * 0.6, sqrt(t)) * randf_range(0.85, 1.15)
		draw_circle(at, r + lerpf(0.5, 2.0, t), Color(COLOR_FIRE, 0.35))
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
