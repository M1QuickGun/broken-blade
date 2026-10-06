extends Node2D
## The Stormcaller, the Lightning peaks' boss: the king's court sorcerer, who first sealed the
## evil into the blade, taken by it. Fought twice. Drawn from sprite sheets (art/bosses/
## stormcaller_*.png, facing right): small and kneeling while bound, towering once free.
##
## Phase 1, the Spire: bound. The lightning tip is driven through its back and a crackling
## chain runs from it to the plinth, so it can't go further from the plinth than the chain
## reaches (the walls and their ledges are out of reach). It blinks from spot to spot (a
## crackle on the floor shows where), and casts, in a fixed order:
## - Floor arcs: it slams its hands down; lightning runs out both ways along the floor: jump.
## - Orbs: two balls of static drift after Storm; strike them to pop them.
## - Roof bolts: back on the plinth it calls bolts down from the roof (sparks fall from where
##   each will strike), then kneels spent for a while: the big opening.
## - Chain lash: the chain glows, and it swings over the plinth from one side to the other;
##   everything within the chain's reach is swept. Get out to the walls.
## Touching it hurts, except while it kneels spent. Beaten, it collapses, the tip tears out of
## it and floats down; then it rises and swells into its true form, and bursts up through the
## spire's roof.
##
## Phase 2, the eyrie (open to the storm, lightning rods standing high around it): free and
## towering, a sorcerer whose robes dissolve into storm cloud. It blinks between the rods; the
## shockline reaches it there. Touching it doesn't hurt; its spells do. In a fixed order:
## - Bolt rain: lightning strikes in rows across the arena, every other column, then the
##   others (their lines flicker first). Then it sinks to the ground, spent: the opening.
## - Beam: it locks on to Storm's height and fires a beam across the whole arena.
## - Copies: two copies of it appear at other rods (fainter: one blow pops one) and all three
##   send an orb after him.
## - Rod strike: the rod nearest Storm glows, then lightning strikes it: don't hang there.
## Below half health it rains a third row of bolts and casts faster. Beaten, it unravels into
## the storm.
##
## The node's origin is the room's B marker: phase 1, on top of the plinth; phase 2, on the
## floor in the middle.

signal defeated
## Sent when it wakes: the room bars its doors then.
signal engaged

const Effects := preload("res://scripts/effects.gd")
const Projectile := preload("res://scripts/projectile.gd")

## Sprite sheets: horizontal strips, facing right.
const BOUND := preload("res://art/bosses/stormcaller_bound.png")
const BOUND_CAST := preload("res://art/bosses/stormcaller_bound_cast.png")
const FREED := preload("res://art/bosses/stormcaller.png")
const FREED_CAST := preload("res://art/bosses/stormcaller_cast.png")
const BOUND_FRAME := 64
const FREED_FRAME := 128
## Drawn sizes (world units), and where its feet are in each frame (from the top).
const BOUND_DRAW := 48.0
const FREED_DRAW := 124.0
const BOUND_FEET := 63.0 / 64.0
const FREED_FEET := 120.0 / 128.0

const TILE := 16
const LAYER_WORLD := 1
const LAYER_ENEMY := 4
## Phase 1: how far the chain lets it go from the plinth.
const REACH := 150.0
const PATTERN_1 := ["arcs", "orbs", "bolts", "lash"]
## Phase 2: how high it hangs below a rod, how far beside it, and the spacing of the bolt
## rows.
const ROD_DROP := 54.0
const ROD_SIDE := 40.0
const BOLT_SPACING := 64.0
const BEAM_WIDTH := 10.0
const PATTERN_2 := ["bolts", "beam", "copies", "rods", "beam", "bolts", "rods"]
## Its pace: every wind-up, recovery and pause it takes is this share of what it says.
const TEMPO := 0.7
## How long a blink takes, and how long its bolts give warning.
const BLINK_TIME := 0.42
const BOLT_WARNING := 0.75
## Phase 2: the time between rows of bolt rain.
const ROW_GAP := 0.75

const COLOR_SPARK := Color(0.78, 0.66, 1.0)
const COLOR_HOT := Color(0.95, 0.92, 1.0)
const COLOR_CHAIN := Color(0.55, 0.45, 0.85)
const COLOR_PIECE := Color(0.85, 0.8, 1.0)
const COLOR_SHADOW := Color(0.02, 0.02, 0.06, 0.45)

enum St {
	DORMANT, WAKE, IDLE, BLINK, CAST, RECOVER, SPENT, LASH_CHARGE, LASH_SWING,
	SLUMP, SWELL, ESCAPE, ARRIVE, BOLT_WAIT, BEAM_AIM, BEAM, ROD_AIM, UNRAVEL,
}

## Set by the room before it's added (see Rooms.BOSSES).
var boss_id := ""
var kind := "stormcaller"
var phase := 1
var title := ""
var max_hp := 14

var hp := 0

var _state := St.DORMANT
var _timer := 0.0
var _time := 0.0
var _flash := 0.0
var _shake := 0.0
var _cam_base := Vector2.ZERO
var _move := 0
var _attack := ""
## Where its feet are (it floats a little above them), which way it faces, how visible it is.
var _pos := Vector2.ZERO
var _dir := 1
var _alpha := 1.0
var _floor := 0.0
var _left := 0.0
var _right := 0.0
## Phase 1: the plinth top it's chained to; how big it's drawn (it swells as it frees itself).
var _anchor := Vector2.ZERO
var _grow := 0.0
## A blink: where to, and what it does when it gets there.
var _blink_to := Vector2.ZERO
var _after_blink := St.IDLE
var _blink_time := 0.0
## The chain lash: which way it swings.
var _lash_side := 1
## How long the current state was set to last (after TEMPO), for anything timed across it.
var _state_time := 1.0
## Bolts waiting to strike: {x, t, top, height}.
var _strikes: Array[Dictionary] = []
## Phase 2: the lightning rods (where the "*" anchors stand); the copies: {pos, life, box};
## the beam's height and length; the rod about to be struck; rod strikes left.
var _rods: Array[Vector2] = []
var _copies: Array[Dictionary] = []
var _beam_y := 0.0
var _beam_end := 0.0
var _rod := Vector2.ZERO
var _rod_strikes := 0
var _bolt_rows := 2
var _pace := 1.0
## The lightning tip: still in its back (-1), flying free (0 to 1); where it comes to rest.
var _piece_t := -1.0
var _piece_from := Vector2.ZERO
var _piece_rest := Vector2.ZERO
var _roof_broken := false
var _done := false

var _body_box: Hitbox
var _chain_box: Hitbox
var _beam_box: Hitbox


## One of its parts. `weak`: struck, it hurts the Stormcaller (or calls `on_hit`, for a copy).
## `harmless`: touched, it doesn't hurt Storm. `slide_through`: a slide passes under it.
class Hitbox extends Area2D:
	var boss: Node
	var weak := false
	var harmless := false
	var slide_through := false
	var on_hit: Callable

	func take_hit(damage: int, from_dir: Vector2) -> void:
		if on_hit.is_valid():
			on_hit.call()
		elif weak:
			boss.take_hit(damage, from_dir)


func _ready() -> void:
	hp = max_hp
	z_index = -1
	_pos = position
	_measure()
	_body_box = _make_box(Vector2(22, 30), true, false)
	_chain_box = _make_box(Vector2(10, 8), false, false)
	_chain_box.slide_through = true
	_beam_box = _make_box(Vector2(10, BEAM_WIDTH), false, false)
	_beam_box.slide_through = true
	if phase == 1:
		_anchor = position + Vector2(TILE / 2.0, 0)
		_pos = _anchor + Vector2(0, -2)
	else:
		(_body_box.get_child(0).shape as RectangleShape2D).size = Vector2(44, 84)
		_body_box.harmless = true  # a towering thing of storm: only its spells hurt
		_grow = 1.0
		_alpha = 0.0
		_pos = Vector2(position.x, _floor - 400.0)
	for box in [_body_box, _chain_box, _beam_box]:
		_set_box(box, false)


func _measure() -> void:
	var room := get_parent()
	_floor = _ground(position.x + 0.1) if phase == 2 else _ground(position.x - 6.0 * TILE)
	var cy := int(_floor / TILE) - 1
	var x := int(position.x / TILE)
	while x < room.size_tiles.x - 1 and room._cell(x + 1, cy) != "#":
		x += 1
	_right = (x + 1) * TILE
	x = int(position.x / TILE)
	while x > 0 and room._cell(x - 1, cy) != "#":
		x -= 1
	_left = x * TILE
	for yy in room.size_tiles.y:
		for xx in room.size_tiles.x:
			if room._cell(xx, yy) == "*":
				_rods.append(Vector2((xx + 0.5) * TILE, (yy + 0.5) * TILE))


## The top of the ground under x (the floor, or the plinth).
func _ground(x: float) -> float:
	var room := get_parent()
	var cx := clampi(int(x / TILE), 0, room.size_tiles.x - 1)
	for cy in range(1, room.size_tiles.y):
		if room._cell(cx, cy) == "#":
			return cy * TILE
	return room.size_px.y


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


func shock_point() -> Vector2:
	return get_parent().to_global(_center())


## The middle of its body.
func _center() -> Vector2:
	if phase == 1 and _grow <= 0.0:
		return _pos + Vector2(0, -16)
	return _pos + Vector2(0, -FREED_DRAW * 0.45 * _scale())


## How big the freed form is drawn (it swells into it at the end of phase 1).
func _scale() -> float:
	return lerpf(0.35, 1.0, _grow) if phase == 1 else 1.0


func _hands() -> Vector2:
	if phase == 1 and _grow <= 0.0:
		return _pos + Vector2(_dir * 12.0, -26.0)
	return _pos + Vector2(_dir * 34.0, -FREED_DRAW * 0.55)


func take_hit(damage: int, _from_dir: Vector2) -> void:
	if not _fighting():
		return
	hp -= damage
	_flash = 0.1
	Sfx.play("hit_boss", -3.0)
	Effects.sparks(get_parent(), _center(), COLOR_SPARK, 14)
	if phase == 2 and hp <= max_hp / 2:
		_pace = 0.8
	if hp <= 0:
		hp = 0
		Effects.slow_motion(get_tree())
		remove_from_group("shock_target")
		remove_from_group("boss")
		_strikes.clear()
		_clear_copies()
		_alpha = 1.0
		if phase == 1:
			_enter(St.SLUMP, 2.0)
		else:
			_enter(St.UNRAVEL, 2.6)


func _fighting() -> bool:
	return _state not in [St.DORMANT, St.WAKE, St.ARRIVE, St.SLUMP, St.SWELL, St.ESCAPE, St.UNRAVEL] \
		and _alpha > 0.5


# --- Behaviour ---

func _physics_process(delta: float) -> void:
	_time += delta
	_flash -= delta
	_timer -= delta
	var player := _player()
	var p := player.position + Vector2(0, -11) if player else _pos
	_update_strikes(delta)
	_update_copies(delta)
	if _state == St.BLINK:
		_update_blink(delta)
	elif phase == 1:
		_phase_1(p, delta)
	else:
		_phase_2(p, delta)
	_update_boxes()
	_update_shake(delta)
	queue_redraw()


func _enter(state: St, time := 0.0) -> void:
	_state = state
	if state not in [St.WAKE, St.ARRIVE, St.BLINK, St.BOLT_WAIT, St.SLUMP, St.SWELL, St.ESCAPE, St.UNRAVEL]:
		time *= TEMPO
	_timer = time
	_state_time = maxf(time, 0.001)
	match state:
		St.WAKE, St.ARRIVE, St.SWELL:
			Sfx.play("roar", -2.0, 0.1)
		St.CAST, St.LASH_CHARGE, St.BEAM_AIM, St.ROD_AIM:
			Sfx.play("shock_charge", -6.0, 0.05)
		St.LASH_SWING, St.BEAM:
			Sfx.play("zap", -3.0)
		St.SLUMP, St.UNRAVEL:
			Sfx.play("thunder", -2.0, 0.0)


func _wake() -> void:
	engaged.emit()
	add_to_group("boss")
	add_to_group("shock_target")
	_shake = 0.6
	_enter(St.WAKE if phase == 1 else St.ARRIVE, 1.6 if phase == 1 else 2.2)


func _next_attack() -> String:
	var pattern: Array = PATTERN_1 if phase == 1 else PATTERN_2
	var attack: String = pattern[_move % pattern.size()]
	_move += 1
	return attack


func _face(p: Vector2) -> void:
	if absf(p.x - _pos.x) > 8.0:
		_dir = 1 if p.x > _pos.x else -1


## Vanishes in a crackle and reappears at `to`, then goes into `then`.
func _blink(to: Vector2, then: St, time: float) -> void:
	_blink_to = to
	_after_blink = then
	_blink_time = time
	_enter(St.BLINK, BLINK_TIME)
	Sfx.play("crackle", -6.0)
	Effects.sparks(get_parent(), _center(), COLOR_SPARK, 8, 90.0)


func _update_blink(_delta: float) -> void:
	# Fading out, a crackle where it'll appear, then fading in there.
	var out := BLINK_TIME * 0.6
	var back := BLINK_TIME * 0.25
	if _timer > out:
		_alpha = clampf((_timer - out) / (BLINK_TIME - out), 0.0, 1.0)
	elif _timer > back:
		_alpha = 0.0
		_pos = _blink_to
	else:
		_alpha = clampf(1.0 - _timer / back, 0.0, 1.0)
	if _timer <= 0.0:
		_alpha = 1.0
		var player := _player()
		if player:
			_face(player.position)
		_enter(_after_blink, _blink_time)


# --- Phase 1 ---

func _phase_1(p: Vector2, delta: float) -> void:
	match _state:
		St.DORMANT:
			if absf(p.x - _anchor.x) < 15.0 * TILE:
				_wake()
		St.WAKE:
			_face(p)
			if _timer <= 0.0:
				_enter(St.IDLE, 0.8)
		St.IDLE:
			_face(p)
			if _timer <= 0.0:
				_attack = _next_attack()
				match _attack:
					"arcs":
						# Down on the floor between Storm and the plinth.
						var side := 1.0 if _anchor.x > p.x else -1.0
						var x := _in_reach(p.x + side * 90.0)
						_blink(Vector2(x, _ground(x)), St.CAST, 0.7)
					"orbs":
						var x := _in_reach(_anchor.x + randf_range(-1.0, 1.0) * REACH * 0.7)
						_blink(Vector2(x, _ground(x) - 30.0), St.CAST, 0.8)
					"bolts":
						_blink(_anchor + Vector2(0, -2), St.CAST, 1.0)
						_call_bolts(p, [0.0, -64.0, 64.0, -128.0, 128.0], 0.08, TILE)
					"lash":
						_lash_side = 1 if p.x > _anchor.x else -1
						var x := _anchor.x + _lash_side * REACH * 0.95
						_blink(Vector2(x, _ground(x)), St.LASH_CHARGE, 0.8)
		St.CAST:
			if _timer <= 0.0:
				_cast_now()
		St.RECOVER:
			if _timer <= 0.0:
				_enter(St.IDLE, 0.5)
		St.SPENT:
			# Kneeling spent on the plinth: hit it.
			if fmod(_time, 0.2) < delta:
				Effects.sparks(get_parent(), _center() + Vector2(randf_range(-10, 10), -10), COLOR_SPARK, 1, 30.0)
			if _timer <= 0.0:
				_enter(St.IDLE, 0.4)
		St.LASH_CHARGE:
			if fmod(_time, 0.06) < delta:
				Effects.sparks(get_parent(), _anchor.lerp(_pos, randf()), COLOR_HOT, 1, 40.0)
			if _timer <= 0.0:
				_enter(St.LASH_SWING, 1.0)
		St.LASH_SWING:
			# Up over the plinth from one side to the other, the chain sweeping all it reaches.
			var t := clampf(1.0 - _timer / _state_time, 0.0, 1.0)
			var start := -0.3 if _lash_side > 0 else PI + 0.3
			var end := PI + 0.3 if _lash_side > 0 else -0.3
			var a := lerpf(start, end, ease(t, -1.6))
			var at := _anchor + Vector2(cos(a) * REACH, -sin(a) * REACH * 0.85)
			at.y = minf(at.y, _ground(at.x))
			_pos = at
			_dir = -_lash_side
			if _timer <= 0.0:
				_enter(St.RECOVER, 0.7)
		St.SLUMP:
			# It collapses; the chain snaps and the tip tears out of its back.
			_pos.y = move_toward(_pos.y, _ground(_pos.x), 60.0 * delta)
			if _piece_t < 0.0 and _timer < 1.3:
				_piece_t = 0.0
				_piece_from = _tip_point()
				var side := 1.0 if _pos.x < _anchor.x else -1.0
				_piece_rest = Vector2(_anchor.x + side * 70.0, _ground(_anchor.x + side * 70.0) - TILE)
				_shake = 0.5
				Sfx.play("burst", -2.0)
				Effects.sparks(get_parent(), _piece_from, COLOR_HOT, 16, 140.0)
			if _piece_t >= 0.0:
				_piece_t = minf(_piece_t + delta / 1.2, 1.0)
			if _timer <= 0.0:
				_enter(St.SWELL, 2.0)
		St.SWELL:
			# Free, it rises over the plinth and swells into what it really is.
			_piece_t = minf(_piece_t + delta / 1.2, 1.0)
			_pos = _pos.lerp(_anchor + Vector2(0, -20), 2.0 * delta)
			_grow = minf(_grow + delta / 1.6, 1.0)
			_shake = maxf(_shake, 0.05)
			if fmod(_time, 0.05) < delta:
				Effects.sparks(get_parent(), _center() + Vector2(randf_range(-30, 30), randf_range(-40, 40)), COLOR_SPARK, 2, 80.0)
			if _timer <= 0.0:
				_enter(St.ESCAPE, 4.0)
		St.ESCAPE:
			# Up through the spire's roof and away into the storm.
			_pos.y -= (80.0 + (4.0 - _timer) * 260.0) * delta
			var top := _pos.y - FREED_DRAW * 0.9
			if not _roof_broken and top < TILE * 1.5:
				_roof_broken = true
				_shake = 1.0
				Sfx.play("thunder", 0.0, 0.0)
				var room := get_parent()
				if room.has_method("break_lid"):
					room.break_lid(Color(0.35, 0.38, 0.48))
			if _pos.y < -6.0 * TILE * 2.0 or _timer <= 0.0:
				_finish()


## A spot along the floor within the chain's reach of the plinth.
func _in_reach(x: float) -> float:
	return clampf(x, maxf(_anchor.x - REACH, _left + 24.0), minf(_anchor.x + REACH, _right - 24.0))


## The spell it was winding up goes off.
func _cast_now() -> void:
	match _attack:
		"arcs":
			_shake = 0.3
			Sfx.play("zap", -4.0)
			for side in [-1, 1]:
				_spawn("spark_wave", Vector2(_pos.x + side * 10.0, _ground(_pos.x)), Vector2(side * 200.0, 0), 3.0)
			_enter(St.RECOVER, 0.8 * _pace)
		"orbs":
			for side in [-1, 0, 1]:
				_spawn("orb", _hands() + Vector2(side * 6.0, 0), Vector2(side * 60.0, -70.0), 5.0)
			_enter(St.RECOVER, 0.9 * _pace)
		"bolts":
			# Spent from calling them down.
			if phase == 1:
				_enter(St.SPENT, 1.8)
			else:
				_enter(St.BOLT_WAIT, (_bolt_rows - 1) * ROW_GAP + 0.3)
		"copies":
			_make_copies()
			_enter(St.RECOVER, 1.2 * _pace)


# --- Phase 2 ---

func _phase_2(p: Vector2, delta: float) -> void:
	var bob := Vector2(0, sin(_time * 1.8) * 4.0)
	match _state:
		St.DORMANT:
			if p.x > _left + 8.0 * TILE and p.x < _right - 4.0 * TILE:
				_strike(position.x, 0.0, _floor)
				_pos = Vector2(position.x, _floor - 90.0)
				_wake()
		St.ARRIVE:
			_alpha = move_toward(_alpha, 1.0, delta * 1.5)
			_face(p)
			if _timer <= 0.0:
				_alpha = 1.0
				_enter(St.IDLE, 0.8)
		St.IDLE:
			_face(p)
			_pos += bob * delta
			if _timer <= 0.0:
				_attack = _next_attack()
				match _attack:
					"bolts":
						_blink(_rod_spot(_middle_rod(), p), St.CAST, 0.9 * _pace)
						var xs: Array = []
						var x := _left + BOLT_SPACING / 2.0
						while x < _right:
							xs.append(x)
							x += BOLT_SPACING
						var rows := 3 if hp <= max_hp / 2 else 2
						_bolt_rows = rows
						var first := BLINK_TIME + 0.9 * _pace * TEMPO
						for row in rows:
							for i in xs.size():
								if i % 2 == row % 2:
									_strikes.append({"x": xs[i], "t": first + row * ROW_GAP, "top": 0.0,
										"height": _ground(xs[i])})
					"beam":
						_blink(_rod_spot(_far_rod(p), p), St.BEAM_AIM, 0.9 * _pace)
					"copies":
						_blink(_rod_spot(_far_rod(p), p), St.CAST, 0.8 * _pace)
					"rods":
						_rod_strikes = 3
						_rod = _near_rod(p)
						_blink(_rod_spot(_far_rod(p), p), St.ROD_AIM, 0.8 * _pace)
		St.CAST:
			_pos += bob * delta
			if _timer <= 0.0:
				_cast_now()
		St.BOLT_WAIT:
			if _timer <= 0.0:
				# Spent: it sinks down to the ground.
				_enter(St.SPENT, 2.4)
		St.SPENT:
			_pos.y = move_toward(_pos.y, _floor, 160.0 * delta)
			if fmod(_time, 0.15) < delta:
				Effects.sparks(get_parent(), _center() + Vector2(randf_range(-20, 20), -20), COLOR_SPARK, 1, 30.0)
			if _timer <= 0.0:
				_blink(_rod_spot(_far_rod(p), p), St.IDLE, 0.6)
		St.RECOVER:
			_pos += bob * delta
			if _timer <= 0.0:
				_enter(St.IDLE, 0.6 * _pace)
		St.BEAM_AIM:
			# Its hand glows; a thin line across the arena at his height, tracking, then held.
			if _timer > 0.3:
				_face(p)
				_beam_y = clampf(p.y, TILE * 2.0, _floor - 6.0)
			_beam_end = _right if _dir > 0 else _left
			if _timer <= 0.0:
				_enter(St.BEAM, 0.6)
		St.BEAM:
			if _timer <= 0.0:
				_enter(St.RECOVER, 0.6)
		St.ROD_AIM:
			# The rod glows, crackling; then lightning strikes it.
			if fmod(_time, 0.05) < delta:
				Effects.sparks(get_parent(), _rod + Vector2(randf_range(-8, 8), randf_range(-8, 8)), COLOR_HOT, 1, 50.0)
			if _timer <= 0.0:
				_strike(_rod.x, 0.0, _rod.y + 46.0)
				_rod_strikes -= 1
				if _rod_strikes > 0:
					_rod = _near_rod(p)
					_enter(St.ROD_AIM, 0.7 * _pace)
				else:
					_enter(St.RECOVER, 0.6)
		St.UNRAVEL:
			# Beaten: it comes apart into the storm.
			_alpha = clampf(_timer / 2.6, 0.0, 1.0)
			_pos.y += 12.0 * delta
			if fmod(_time, 0.04) < delta:
				var at := _center() + Vector2(randf_range(-30, 30), randf_range(-60, 50))
				Effects.sparks(get_parent(), at, COLOR_SPARK, 2, 70.0)
			if _timer <= 0.0:
				_piece_rest = Vector2(clampf(_pos.x, _left + 40.0, _right - 40.0), _floor - TILE)
				_finish()


## Where it hangs beside a rod, on the side away from Storm.
func _rod_spot(rod: Vector2, p: Vector2) -> Vector2:
	var side := -1.0 if p.x > rod.x else 1.0
	var at := rod + Vector2(side * ROD_SIDE, ROD_DROP)
	at.x = clampf(at.x, _left + 30.0, _right - 30.0)
	at.y = minf(at.y, _floor - 4.0)
	return at


## The rod nearest the middle of the arena.
func _middle_rod() -> Vector2:
	var middle := (_left + _right) / 2.0
	var best := _rods[0]
	for rod in _rods:
		if absf(rod.x - middle) < absf(best.x - middle):
			best = rod
	return best


func _near_rod(p: Vector2) -> Vector2:
	var best := _rods[0]
	for rod in _rods:
		if rod.distance_to(p) < best.distance_to(p):
			best = rod
	return best


## A rod well away from Storm (not the nearest, not always the farthest).
func _far_rod(p: Vector2) -> Vector2:
	var sorted := _rods.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(p) > b.distance_to(p))
	return sorted[randi() % mini(2, sorted.size())]


## Two copies at other rods; all three send an orb after Storm.
func _make_copies() -> void:
	Sfx.play("crackle", -2.0)
	var player := _player()
	var p := player.position if player else _pos
	var spots := _rods.duplicate()
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(_pos) > b.distance_to(_pos))
	for i in mini(2, spots.size()):
		var at := _rod_spot(spots[i], p)
		var box := _make_box(Vector2(40, 80), false, true)
		var copy := {"pos": at, "life": 4.0, "box": box}
		box.on_hit = func() -> void: _pop_copy(copy)
		_copies.append(copy)
		Effects.sparks(get_parent(), at + Vector2(0, -50), COLOR_SPARK, 10, 90.0)
	for from in [_hands()] + _copies.map(func(c: Dictionary) -> Vector2: return c.pos + Vector2(0, -FREED_DRAW * 0.55)):
		_spawn("orb", from, (p - from).normalized() * 40.0, 5.0)


func _pop_copy(copy: Dictionary) -> void:
	if not _copies.has(copy):
		return
	Sfx.play("crackle", -4.0)
	Effects.sparks(get_parent(), copy.pos + Vector2(0, -50), COLOR_HOT, 12, 110.0)
	copy.box.queue_free()
	_copies.erase(copy)


func _update_copies(delta: float) -> void:
	for copy in _copies.duplicate():
		copy.life -= delta
		_set_box(copy.box, true, copy.pos + Vector2(0, -FREED_DRAW * 0.45))
		if copy.life <= 0.0:
			_pop_copy(copy)


func _clear_copies() -> void:
	for copy in _copies.duplicate():
		_pop_copy(copy)


# --- Bolts ---

## Bolts at these offsets from Storm, down from the roof (or the sky), one after another.
func _call_bolts(p: Vector2, offsets: Array, step: float, top: float) -> void:
	for i in offsets.size():
		var x := clampf(p.x + offsets[i], _left + 12.0, _right - 12.0)
		_strikes.append({"x": x, "t": BOLT_WARNING + i * step, "top": top, "height": _ground(x) - top})


## A bolt striking now, from `top` down to `bottom`.
func _strike(x: float, top: float, bottom: float) -> void:
	var proj := Projectile.new()
	proj.kind = "bolt"
	proj.height = bottom - top
	proj.life = 0.3
	proj.position = Vector2(x, bottom)
	get_parent().add_child(proj)
	_shake = maxf(_shake, 0.2)
	Sfx.play("thunder", -10.0, 0.2)


func _update_strikes(delta: float) -> void:
	var struck := []
	for s in _strikes:
		s.t -= delta
		if s.t <= 0.0:
			_strike(s.x, s.top, s.top + s.height)
			struck.append(s)
	for s in struck:
		_strikes.erase(s)


func _update_boxes() -> void:
	var visible_ := _fighting()
	if phase == 1:
		# Touching it hurts, but not while it kneels spent.
		_body_box.harmless = _state == St.SPENT
	_set_box(_body_box, visible_, _center())
	var lashing := _state == St.LASH_SWING
	if lashing:
		var from := _anchor + Vector2(0, -2)
		var to := _back()
		var shape: RectangleShape2D = _chain_box.get_child(0).shape
		shape.size = Vector2(maxf(from.distance_to(to), 1.0), 8.0)
		_set_box(_chain_box, true, (from + to) / 2.0, (to - from).angle())
	else:
		_set_box(_chain_box, false)
	if _state == St.BEAM:
		var from := _hands()
		var shape: RectangleShape2D = _beam_box.get_child(0).shape
		shape.size = Vector2(absf(_beam_end - from.x), BEAM_WIDTH)
		_set_box(_beam_box, true, Vector2((from.x + _beam_end) / 2.0, _beam_y))
	else:
		_set_box(_beam_box, false)


## Where the chain meets it (its back) and where the tip sticks out of it.
func _back() -> Vector2:
	return _pos + Vector2(-_dir * 6.0, -22.0)


func _tip_point() -> Vector2:
	return _pos + Vector2(-_dir * 8.0, -30.0)


func _finish() -> void:
	_alpha = 0.0
	_done = true
	Game.defeated[boss_id] = true
	_restore_camera()
	defeated.emit()
	set_physics_process(false)
	queue_redraw()


func reward_point() -> Vector2:
	return _piece_rest


# --- Effects ---

func _spawn(p_kind: String, pos: Vector2, vel: Vector2, p_life: float) -> void:
	var proj := Projectile.new()
	proj.kind = p_kind
	proj.velocity = vel
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


# --- Art ---

func _draw() -> void:
	if _done:
		return
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	if _state == St.DORMANT and phase == 1:
		tint = Color(0.6, 0.6, 0.7)
	if _state == St.SPENT:
		tint = Color(0.65, 0.62, 0.78)
	# Bolts about to strike: sparks at the top, a faint flickering line down.
	for s in _strikes:
		var grow := clampf(1.0 - s.t / BOLT_WARNING, 0.0, 1.0)
		var x: float = s.x - position.x
		var top: float = s.top - position.y
		var bottom: float = s.top + s.height - position.y
		if fmod(_time, 0.1) < 0.06:
			draw_line(Vector2(x, top), Vector2(x, bottom), Color(COLOR_SPARK, 0.12 + 0.35 * grow), 1.0)
		draw_circle(Vector2(x, top + 2.0), 2.0 + 4.0 * grow, Color(COLOR_HOT, 0.3 + 0.5 * grow))
		_draw_ellipse(Vector2(x, bottom), Vector2(4.0 + 8.0 * grow, 2.0), Color(COLOR_SPARK, 0.2 + 0.3 * grow))
	if phase == 1:
		_draw_chain()
	if _state == St.BLINK:
		# A crackle where it's about to appear.
		var at := _blink_to - position
		for i in 3:
			var a := randf() * TAU
			draw_line(at + Vector2(0, -4), at + Vector2(0, -4) + Vector2.from_angle(a) * randf_range(4, 12), COLOR_HOT, 1.0)
		_draw_ellipse(at, Vector2(12, 2.5), Color(COLOR_SPARK, 0.5))
	for copy in _copies:
		_draw_sprite(copy.pos, Color(0.7, 0.7, 1.0, 0.6 * clampf(copy.life, 0.0, 1.0)), true)
	if _alpha > 0.0:
		_draw_sprite(_pos, Color(tint, tint.a * _alpha), false)
	if phase == 1 and _piece_t < 0.0 and _alpha > 0.0 and _grow <= 0.0:
		_draw_tip(_tip_point() - position, (deg_to_rad(-60.0) if _dir > 0 else deg_to_rad(-120.0)), _alpha)
	elif phase == 1 and _piece_t >= 0.0:
		var t := _piece_t
		var at := _piece_from.lerp(_piece_rest, ease(t, -1.8)) - Vector2(0, sin(t * PI) * 50.0) - position
		draw_circle(at, 10.0, Color(COLOR_PIECE, 0.3))
		_draw_tip(at, t * TAU * 3.0, 1.0)
	if _state == St.BEAM_AIM:
		var from := Vector2(_hands().x, _beam_y) - position
		var to := Vector2(_beam_end, _beam_y) - position
		var locked := _timer <= 0.3
		var alpha := 0.8 if locked and fmod(_time, 0.1) < 0.05 else 0.3
		draw_line(from, to, Color(COLOR_SPARK, alpha), 1.0)
		draw_circle(_hands() - position, 6.0 + 6.0 * (1.0 - _timer / _state_time), Color(COLOR_HOT, 0.4))
	if _state == St.BEAM:
		var from := Vector2(_hands().x, _beam_y) - position
		var to := Vector2(_beam_end, _beam_y) - position
		var pts := PackedVector2Array()
		var steps := maxi(2, int(absf(to.x - from.x) / 12.0))
		for i in steps + 1:
			pts.append(from.lerp(to, float(i) / steps) + Vector2(0, randf_range(-3, 3) if i > 0 and i < steps else 0.0))
		draw_polyline(pts, Color(COLOR_SPARK, 0.5), BEAM_WIDTH)
		draw_polyline(pts, COLOR_HOT, 2.5)
	if _state == St.ROD_AIM:
		var grow := clampf(1.0 - _timer / _state_time, 0.0, 1.0)
		draw_circle(_rod - position, 8.0 + 16.0 * grow, Color(COLOR_SPARK, 0.2 + 0.3 * grow))


## The bound form, or the freed one (swelling into it at the end of phase 1), casting or not.
func _draw_sprite(at: Vector2, tint: Color, copy: bool) -> void:
	var casting := _state in [St.CAST, St.LASH_CHARGE, St.BEAM_AIM, St.BEAM, St.ROD_AIM, St.LASH_SWING] and not copy
	var freed := phase == 2 or _grow > 0.0
	var tex: Texture2D
	var frame_px: int
	var size: float
	var feet: float
	if freed:
		tex = FREED_CAST if casting else FREED
		frame_px = FREED_FRAME
		size = FREED_DRAW * _scale()
		feet = FREED_FEET
	else:
		tex = BOUND_CAST if casting else BOUND
		frame_px = BOUND_FRAME
		size = BOUND_DRAW
		feet = BOUND_FEET
	var frames := tex.get_width() / frame_px
	var frame := int(_time * 9.0) % frames
	if casting:
		frame = mini(int((1.0 - clampf(_timer / _state_time, 0.0, 1.0)) * frames), frames - 1)
	if _state == St.SPENT or _state == St.SLUMP:
		frame = 0
	var hover := 0.0 if _state in [St.SPENT, St.SLUMP] else 6.0 + sin(_time * 2.2) * 2.0
	var origin := at - position + Vector2(0, -hover)
	if freed and not copy:
		_draw_ellipse(Vector2(at.x - position.x, _ground(at.x) - position.y), Vector2(18.0 * _scale(), 3.0), COLOR_SHADOW)
	draw_set_transform(origin, 0.0, Vector2(_dir, 1))
	draw_texture_rect_region(tex, Rect2(-size / 2.0, -size * feet, size, size),
		Rect2(frame * frame_px, 0, frame_px, frame_px), tint)
	draw_set_transform(Vector2.ZERO)


## The crackling chain from the plinth to its back: faint while it hangs slack, blazing when
## it lashes.
func _draw_chain() -> void:
	if _state in [St.SLUMP, St.SWELL, St.ESCAPE] or _done:
		return
	var from := _anchor + Vector2(0, -2) - position
	var to := _back() - position
	var hot := _state in [St.LASH_CHARGE, St.LASH_SWING]
	var pts := PackedVector2Array()
	var steps := maxi(3, int(from.distance_to(to) / 10.0))
	var side := (to - from).orthogonal().normalized()
	for i in steps + 1:
		var t := float(i) / steps
		var sag := sin(t * PI) * (0.0 if hot else 10.0)
		var jitter := randf_range(-2, 2) if hot and i > 0 and i < steps else 0.0
		pts.append(from.lerp(to, t) + Vector2(0, sag) + side * jitter)
	var alpha := _alpha if _state != St.BLINK else 0.5
	draw_polyline(pts, Color(COLOR_CHAIN, (0.9 if hot else 0.5) * alpha), 4.0 if hot else 2.0)
	if hot:
		draw_polyline(pts, Color(COLOR_HOT, alpha), 1.5)


## The lightning tip: a short length of blade with a point, glowing.
func _draw_tip(at: Vector2, angle: float, alpha: float) -> void:
	draw_circle(at, 7.0, Color(COLOR_PIECE, 0.2 * alpha))
	draw_set_transform(at, angle)
	draw_colored_polygon(PackedVector2Array([
		Vector2(12, 0), Vector2(2, -3), Vector2(-8, -3), Vector2(-6, 0), Vector2(-9, 2), Vector2(2, 3),
	]), Color(COLOR_PIECE, alpha))
	draw_line(Vector2(-6, 0), Vector2(10, 0), Color(1, 1, 1, alpha), 1.0)
	draw_set_transform(Vector2.ZERO)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
