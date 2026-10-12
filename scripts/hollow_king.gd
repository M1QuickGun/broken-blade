extends Node2D
## The Hollow King (the throne room): the evil sitting on the throne in the dead king's
## armor, Storm's father, a phantom blade of smoke and violet light in his hand.
##
## Phase 1, the King. He kneels before the throne until Storm comes near, then rises and
## steps down to fight on the floor, turning each piece's evil against him in turn:
## - Slash: he stalks Storm, raises the blade high and brings it down in a great arc in front
##   of him; afterwards he's slow to recover: the opening.
## - Ice: he plants the blade and frost runs out both ways along the floor (the Colossus):
##   jump it.
## - Fire: he flings embers that arc down around Storm, their glow on the floor showing
##   where, and fire runs along the floor at him (the Drake).
## - Bolts: lightning strikes where Storm stands, one after another, each flickering first
##   (the Stormcaller): keep moving.
## - Thrust: he draws the blade back, a thin line along the floor showing its reach, and
##   drives it out low across the room: jump it.
## Below 40% his armor cracks and light bleeds out of it: he fights faster, and adds
## judgement: phantom blades hang over Storm one after another and plunge down (each marked
## on the floor first).
##
## Beaten, the King falls to his knees, and the evil tears out of him: phase 2, the evil
## unbound, towering over the room (the King's empty armor left kneeling below). Touching it
## doesn't hurt; its head is where to strike, from the rings or with the shockline:
## - Claw: a claw of shadow hangs over Storm, its shadow on the floor following him, then
##   slams down, and stays there a moment: strike the claw while it's down (it hurts the
##   evil too).
## - Sweep: a claw wells up at one end of the room and sweeps the floor end to end: jump it,
##   or be up on a ring.
## - Ruin: ice, fire and lightning fall all over the room, each marked on the floor first.
## - Orbs: it breathes three orbs of dark that drift after Storm; strike them to pop them.
## Below 40% it fights faster. It's struck at its three eyes (a blow at it lands on the eye
## nearest Storm); with all three put out it slumps, its core bare, for double damage. A
## slammed claw stays down as a slope to run up toward its head. At half health the King's
## empty armor rises and holds it fast for a while; below a third the floor gives way to
## burning dark and pillars rise to stand on. The last blow drives Storm along the shockline
## into its core; then light breaks through it, its arms fall away and it splits apart.
## Phase 1 opens with the King leaping from his throne into the hall; he lunges across it,
## raises ice and flame from the floor, and if his blade is struck in the instant before his
## overhead slash falls, he's parried and reels open. The chandeliers stay hidden until the
## evil rises, then come down on their chains as rings.

signal defeated
## Emitted when it wakes; the room bars its doors then.
signal engaged

const Effects := preload("res://scripts/effects.gd")
const Projectile := preload("res://scripts/projectile.gd")

const IDLE := preload("res://art/bosses/king/idle.png")
const WALK := preload("res://art/bosses/king/walk.png")
const CAST := preload("res://art/bosses/king/cast.png")
const THRUST := preload("res://art/bosses/king/thrust.png")
const SLASH := preload("res://art/bosses/king/slash.png")
const KNEEL := preload("res://art/bosses/king/kneel.png")
const EVIL := preload("res://art/bosses/king/evil.png")
## The evil cut for moving: its body without arms, and each arm (art cut from EVIL at
## ARM_L_AT / ARM_R_AT, hung from its shoulder).
const EVIL_BODY := preload("res://art/bosses/king/evil_body.png")
const ARM_L := preload("res://art/bosses/king/evil_arm_l.png")
const ARM_R := preload("res://art/bosses/king/evil_arm_r.png")
const ARM_L_AT := Vector2(0, 64)
const ARM_R_AT := Vector2(174, 64)
const SHOULDER_L := Vector2(72, 84)
const SHOULDER_R := Vector2(184, 84)
const HAND_L := Vector2(40, 189)
const HAND_R := Vector2(216, 189)
const FRAME := 128
## The King's frames drawn this big (world units), his feet this far down the frame.
const DRAW := 130.0
const FEET := 124.0 / 128.0
## The evil drawn this big; its head (the core, where to strike) at this point of the art.
const EVIL_DRAW := 236.0
const EVIL_HEAD := Vector2(128, 70) / 256.0
## The shadow claw: the evil's left claw cut out of its art, conjured on its own.
const CLAW_ART := Rect2(10, 150, 70, 80)
const CLAW_DRAW := Vector2(62, 70)

const TILE := 16
const LAYER_WORLD := 1
const LAYER_ENEMY := 4

const PATTERN_1 := ["lunge", "slash", "ice", "slash", "fire", "lunge", "thrust", "bolts", "slash"]
const PATTERN_2 := ["claw", "ruin", "claw", "sweep", "orbs", "claw", "sweep", "ruin"]
## Cracked (below 40%), the King's pattern with judgement in it.
const PATTERN_CRACKED := ["lunge", "judgement", "slash", "fire", "lunge", "thrust", "judgement", "ice", "slash", "bolts"]
const CRACK_AT := 0.4
const JUDGEMENT := 3
const JUDGEMENT_EVERY := 0.55
const JUDGEMENT_WARNING := 0.9
## The evil's health once it tears free.
const EVIL_HP := 56
const FAST_PACE := 0.78
const EVIL_FAST_AT := 0.4
const EVIL_FAST_PACE := 0.72
const WALK_SPEED := 70.0
const SLASH_REACH := Vector2(110, 84)
## The lunge: across the hall in a rush, afterimages behind.
const LUNGE_SPEED := 430.0
## The parry: strike his blade as it comes down to stagger him.
const PARRY_WINDOW := 0.3
const STAGGER_TIME := 2.2
const THRUST_REACH := 260.0
const BOLTS := 5
const BOLT_EVERY := 0.36
const BOLT_WARNING := 0.7
## The evil's head drifts toward Storm along this height, this fast.
const EVIL_HEIGHT := 150.0
## Its three eyes, where to strike it (offsets from its head) and how much each takes; with
## all three put out it slumps, its core open, for EYES_DOWN seconds.
const EYES := [Vector2(-34, 16), Vector2(34, 16), Vector2(0, -24)]
const EYE_HP := 8
const EYES_DOWN := 4.0
## The arm it slams down stays as a slope up toward its head, this long.
const ARM_TIME := 3.2
const ARM_SLOPE := 0.66
## At half health, your father's armor rises and holds it; below a third, the floor gives way.
const HOLD_AT := 0.5
const HOLD_TIME := 5.0
const COLLAPSE_AT := 0.33
const EVIL_DRIFT := 30.0
const CLAW_HOVER := 120.0
const SWEEP_SPEED := 300.0
const RUIN_TIME := 3.0
const RUIN_EVERY := 0.18
const RUIN_WARNING := 0.8
const DEATH_TIME := 4.2

const COLOR_VIOLET := Color(0.72, 0.45, 1.0)
const COLOR_VIOLET_HOT := Color(0.95, 0.85, 1.0)
const COLOR_ICE := Color(0.7, 0.92, 1.0)
const COLOR_FIRE := Color(1.0, 0.55, 0.18)
const COLOR_SPARK := Color(0.78, 0.66, 1.0)
const COLOR_SMOKE := Color(0.06, 0.04, 0.09)
const COLOR_SHADOW := Color(0.02, 0.02, 0.06, 0.45)

enum St {
	DORMANT, RISE, IDLE, WALK, SLASH_WINDUP, SLASH, RECOVER, CAST, BOLT_WAIT, THRUST_WINDUP, THRUST,
	LEAP, LUNGE_WINDUP, LUNGE, STAGGER,
	KNEEL, TEAR, HOVER, CLAW_AIM, CLAW_FALL, CLAW_DOWN, CLAW_RISE, SWEEP_WARN, SWEEP, RUIN, ORBS, DYING,
	SLUMP, HELD, FINAL,
}

var boss_id := ""
var kind := "hollow_king"
var phase := 1
var title := ""
## Set when the evil tears free (the HUD shows it under the title).
var subtitle := ""
var max_hp := 18
var hp := 0

var _state := St.DORMANT
var _timer := 0.0
var _state_time := 1.0
var _time := 0.0
var _flash := 0.0
var _shake := 0.0
var _cam_base := Vector2.ZERO
var _move := 0
var _attack := ""
var _pace := 1.0
## The King: where his feet are, which way he faces.
var _pos := Vector2.ZERO
var _dir := -1
var _throne := Vector2.ZERO
var _floor := 0.0
var _left := 0.0
var _right := 0.0
## The evil: where its head is, how far it's grown in, how solid it is.
var _head := Vector2.ZERO
var _grow := 0.0
var _evil_alpha := 0.0
var _armor_alpha := 1.0
## The shadow claw: where it is, which way a sweep runs.
var _claw := Vector2.ZERO
var _sweep_dir := 1
var _strikes: Array[Dictionary] = []
var _next_ruin := 0.0
var _hunt := 0
var _done := false
## Below 40% the King's armor cracks.
var _cracked := false
## Where the King's opening leap lands, and the afterimages of his lunge.
var _leap_from := Vector2.ZERO
var _trail: Array[Dictionary] = []
## The parry: his raised blade, there to be struck in the last moment before it falls.
var _parry_box: Hitbox
## The evil's eyes: health left in each, and their hitboxes.
var _eye_hp: Array[int] = [EYE_HP, EYE_HP, EYE_HP]
var _eye_boxes: Array[Hitbox] = []
## The arm-slope while a claw rests on the floor.
var _arm: StaticBody2D
var _arm_top := Vector2.ZERO
## The rings (chandeliers): hidden while the King fights, let down on their chains after.
var _rings: Array[Node2D] = []
var _ring_rest: Array[Vector2] = []
var _held_done := false
var _collapsed := false
var _void: Hitbox
var _pillars: Array[StaticBody2D] = []
var _final_from := Vector2.ZERO

var _body_box: Hitbox
var _blade_box: Hitbox
var _head_box: Hitbox
var _claw_box: Hitbox


## One of its parts. `weak`: struck, it hurts the boss. `harmless`: touched, it doesn't hurt
## Storm. `slide_through`: a slide passes under it.
class Hitbox extends Area2D:
	var boss: Node
	var weak := false
	var harmless := false
	var slide_through := false
	var on_hit: Callable
	## One of the evil's eyes (0-2), or -1.
	var eye := -1

	func take_hit(damage: int, from_dir: Vector2) -> void:
		if eye >= 0:
			boss.hit_eye(eye, damage)
		elif on_hit.is_valid():
			on_hit.call()
		elif weak:
			boss.take_hit(damage, from_dir)


func _ready() -> void:
	hp = max_hp
	z_index = -1
	_throne = position
	_pos = position
	_measure()
	_body_box = _make_box(Vector2(38, 86), true, false)
	_parry_box = _make_box(Vector2(46, 44), false, true)
	_parry_box.on_hit = _parried
	_blade_box = _make_box(SLASH_REACH, false, false)
	_blade_box.slide_through = true
	_head_box = _make_box(Vector2(64, 54), true, true)
	_claw_box = _make_box(Vector2(50, 40), false, false)
	for i in EYES.size():
		var eye := _make_box(Vector2(20, 20), false, true)
		eye.eye = i
		_eye_boxes.append(eye)
	_head_box.on_hit = _clink
	_head_box.weak = false
	for box in [_body_box, _blade_box, _head_box, _claw_box, _parry_box] + _eye_boxes:
		_set_box(box, false)
	# The chandeliers stay hidden while the King fights; they come down when the evil rises.
	for child in get_parent().get_children():
		if child.has_method("shock_point") and child.get("style") is String:
			_rings.append(child)
			_ring_rest.append(child.position)
			child.visible = false
			child.remove_from_group("shock_target")


## The floor in front of the throne, and the stretch of it the fight has.
func _measure() -> void:
	var room := get_parent()
	var cx := int(position.x / TILE)
	var cy := int(position.y / TILE)
	while cx > 0 and room._cell(cx, cy) == "#":
		cx -= 1
	_right = (cx + 1) * TILE
	_floor = _ground((cx + 0.5) * TILE)
	var x := cx
	while x > 0 and room._cell(x - 1, int(_floor / TILE) - 1) != "#":
		x -= 1
	_left = x * TILE


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


func _set_box(box: Area2D, on: bool, at := Vector2.ZERO) -> void:
	box.collision_layer = LAYER_ENEMY if on else 0
	if on:
		box.global_position = get_parent().to_global(at)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


## Where the shockline latches on: the King's chest, or the evil's head.
func shock_point() -> Vector2:
	return get_parent().to_global(_head if phase == 2 else _pos + Vector2(0, -40))


func reward_point() -> Vector2:
	return get_parent().to_global(Vector2(_pos.x, _floor - TILE))


func take_hit(damage: int, _from_dir: Vector2) -> void:
	if not _fighting():
		return
	if phase == 2 and _state not in [St.SLUMP, St.FINAL]:
		# A blow at the evil (or the shockline's) lands on the eye nearest Storm.
		var player := _player()
		var best := -1
		for i in EYES.size():
			if _eye_hp[i] > 0 and (best < 0 or player == null
					or (_head + EYES[i]).distance_to(player.position) < (_head + EYES[best]).distance_to(player.position)):
				best = i
		if best >= 0:
			hit_eye(best, damage)
		return
	if _state == St.STAGGER or _state == St.SLUMP:
		damage *= 2
	_hurt(damage)


func _hurt(damage: int) -> void:
	hp -= damage
	_flash = 0.14
	Sfx.play("hit_boss", -3.0)
	var at := _head if phase == 2 else _pos + Vector2(0, -40)
	Effects.sparks(get_parent(), at, COLOR_VIOLET, 14)
	Effects.sparks(get_parent(), at, COLOR_VIOLET_HOT, 6, 160.0)
	if phase == 1 and not _cracked and hp > 0 and hp <= int(max_hp * CRACK_AT):
		# His armor cracks; light bleeds out of it.
		_cracked = true
		_pace = FAST_PACE
		_shake = 0.5
		Sfx.play("shatter", -2.0, 0.0)
		Sfx.play("roar", -4.0, 0.0)
		Effects.sparks(get_parent(), _pos + Vector2(0, -40), COLOR_VIOLET_HOT, 24, 180.0)
	if phase == 2 and hp <= int(max_hp * EVIL_FAST_AT):
		_pace = EVIL_FAST_PACE
	if phase == 2 and not _held_done and hp > 0 and hp <= int(max_hp * HOLD_AT):
		# Your father's armor rises and takes hold of it.
		_held_done = true
		_end_arm()
		_strikes.clear()
		_enter(St.HELD, HOLD_TIME)
		_say("The King's empty armor rises, and holds it fast.")
		return
	if phase == 2 and not _collapsed and hp > 0 and hp <= int(max_hp * COLLAPSE_AT):
		_collapse()
	if hp > 0:
		return
	hp = 0
	Effects.slow_motion(get_tree())
	_strikes.clear()
	remove_from_group("shock_target")
	if phase == 1:
		# The King falls to his knees, and the evil tears out of him.
		_enter(St.KNEEL, 1.8)
	else:
		# The last blow: the reforged blade, driven into its core along the shockline.
		remove_from_group("boss")
		_end_arm()
		_clear_collapse()
		var player := _player()
		if player:
			player.controls_locked = true
			_final_from = player.global_position
		_enter(St.FINAL, 1.4)
		Sfx.play("shock_fire", 0.0, 0.0)


## One of its eyes struck: put out at last, and with all three out it slumps, core open.
func hit_eye(i: int, damage: int) -> void:
	if phase != 2 or not _fighting() or _eye_hp[i] <= 0 or _state == St.SLUMP:
		return
	_eye_hp[i] = maxi(0, _eye_hp[i] - damage)
	Effects.sparks(get_parent(), _head + EYES[i], Color(1.0, 0.95, 0.7), 10, 140.0)
	_hurt(damage)
	if _eye_hp[i] == 0:
		Sfx.play("shatter", -4.0, 0.0)
		Effects.puff(get_parent(), _head + EYES[i], COLOR_SMOKE, 10, 90.0)
	if _eye_hp.all(func(h: int) -> bool: return h <= 0) and hp > 0:
		_end_arm()
		_strikes.clear()
		Sfx.play("roar", -2.0, 0.0)
		_enter(St.SLUMP, EYES_DOWN)


## A blow at its closed head rings off.
func _clink() -> void:
	if phase == 2 and _state == St.SLUMP:
		take_hit(Game.blade_damage(), Vector2.ZERO)
		return
	Sfx.play("hit", -8.0, 0.0)
	Effects.sparks(get_parent(), _head, Color(0.6, 0.6, 0.7), 4, 90.0)


func _say(text: String) -> void:
	var main = get_tree().current_scene
	if main and main.get("hud"):
		main.hud.show_message(text)


## His blade struck as it fell: it rings off, and he reels with his guard wide open.
func _parried() -> void:
	if _state != St.SLASH_WINDUP:
		return
	Sfx.play("shatter", 0.0, 0.0)
	Sfx.play("hit_boss", -2.0, 0.0)
	_shake = 0.4
	Effects.sparks(get_parent(), _pos + Vector2(_dir * 20.0, -96.0), COLOR_VIOLET_HOT, 24, 220.0)
	Effects.slow_motion(get_tree(), 0.3, 0.25)
	_enter(St.STAGGER, STAGGER_TIME)


func _fighting() -> bool:
	return _state not in [St.DORMANT, St.RISE, St.LEAP, St.KNEEL, St.TEAR, St.DYING, St.FINAL]


# --- Behaviour ---

func _physics_process(delta: float) -> void:
	_time += delta
	_flash -= delta
	_timer -= delta
	var player := _player()
	var p := player.position + Vector2(0, -11) if player else _pos
	_update_strikes(delta)
	if phase == 1:
		_phase_1(p, delta)
	else:
		_phase_2(p, delta)
	_update_boxes()
	_update_shake(delta)
	queue_redraw()


func _enter(state: St, time := 0.0) -> void:
	if state in [St.THRUST_WINDUP, St.LUNGE_WINDUP, St.SWEEP_WARN, St.RUIN]:
		Sfx.play("warn", -6.0, 0.0)  # its biggest blows ring a warning first
	_state = state
	if state not in [St.RISE, St.LEAP, St.KNEEL, St.TEAR, St.DYING, St.WALK, St.BOLT_WAIT, St.RUIN, St.LUNGE]:
		time *= _pace
	_timer = time
	_state_time = maxf(time, 0.001)
	match state:
		St.SLASH_WINDUP, St.THRUST_WINDUP:
			Sfx.play("swing", -8.0, 0.0)
		St.SLASH, St.THRUST:
			Sfx.play("swing", -1.0)
		St.CAST:
			Sfx.play("shock_charge", -6.0, 0.05)
		St.KNEEL:
			Sfx.play("slam", -2.0)
		St.TEAR:
			Sfx.play("roar", 0.0, 0.0)
		St.DYING:
			Sfx.play("roar", 0.0, 0.0)
			Sfx.play("thunder", -2.0, 0.0)


func _next_attack() -> String:
	var pattern: Array = (PATTERN_CRACKED if _cracked else PATTERN_1) if phase == 1 else PATTERN_2
	var attack: String = pattern[_move % pattern.size()]
	_move += 1
	return attack


func _face(p: Vector2) -> void:
	if absf(p.x - _pos.x) > 8.0:
		_dir = 1 if p.x > _pos.x else -1


# --- Phase 1: the King ---

func _phase_1(p: Vector2, delta: float) -> void:
	match _state:
		St.DORMANT:
			if absf(p.x - _pos.x) < 15.0 * TILE:
				engaged.emit()
				add_to_group("boss")
				add_to_group("shock_target")
				_shake = 0.5
				Sfx.play("roar", -2.0, 0.0)
				_enter(St.RISE, 1.8)
		St.RISE:
			# He stands up out of his kneel before the throne...
			if _timer <= 0.0:
				_leap_from = _pos
				_enter(St.LEAP, 0.9)
				Sfx.play("swing", -4.0, 0.0)
		St.LEAP:
			# ...and leaps down into the middle of the hall.
			var t := clampf(1.0 - _timer / _state_time, 0.0, 1.0)
			var land := Vector2((_left + _right) / 2.0, _floor)
			_pos = _leap_from.lerp(land, t) + Vector2(0, -sin(t * PI) * 90.0)
			_face(p)
			if _timer <= 0.0:
				_pos = land
				_shake = 0.6
				Sfx.play("slam", 0.0)
				for side in [-1, 1]:
					Effects.puff(get_parent(), _pos + Vector2(side * 24.0, -4.0), COLOR_SMOKE, 8, 90.0)
				_enter(St.IDLE, 0.7)
		St.IDLE:
			_face(p)
			if _timer <= 0.0:
				_attack = _next_attack()
				match _attack:
					"slash":
						_enter(St.WALK, 2.6)
					"ice", "fire", "bolts", "judgement":
						_enter(St.CAST, 0.9)
					"thrust":
						_enter(St.THRUST_WINDUP, 1.0)
					"lunge":
						_enter(St.LUNGE_WINDUP, 0.7)
		St.LUNGE_WINDUP:
			# Crouched, blade low and back, flickering: then across the hall.
			_face(p)
			if _timer <= 0.0:
				_enter(St.LUNGE, 1.2)
				Sfx.play("swing", 0.0)
		St.LUNGE:
			_pos.x += _dir * LUNGE_SPEED / _pace * delta
			if fmod(_time, 0.035) < delta:
				_trail.append({"pos": _pos, "at": _time, "dir": _dir})
			var stop := _left + 2.0 * TILE if _dir < 0 else _right - 2.0 * TILE
			if (_dir < 0 and _pos.x <= stop) or (_dir > 0 and _pos.x >= stop) or _timer <= 0.0:
				_pos.x = clampf(_pos.x, _left + 2.0 * TILE, _right - 2.0 * TILE)
				_shake = 0.3
				_enter(St.RECOVER, 0.8)
		St.STAGGER:
			# Parried: reeling, his guard open.
			if _timer <= 0.0:
				_enter(St.IDLE, 0.5)
		St.WALK:
			# Stalking him until he's in reach of the blade.
			_face(p)
			var gap := p.x - _pos.x
			if absf(gap) > SLASH_REACH.x * 0.6 and _timer > 0.0:
				_pos.x = clampf(_pos.x + _dir * WALK_SPEED / _pace * delta, _left + 2.0 * TILE, _right - TILE)
			else:
				_enter(St.SLASH_WINDUP, 0.75)
		St.SLASH_WINDUP:
			if _timer <= 0.0:
				_enter(St.SLASH, 0.22)
				_shake = 0.2
		St.SLASH:
			if _timer <= 0.0:
				_enter(St.RECOVER, 0.9)
		St.CAST:
			_face(p)
			if _timer <= 0.0:
				_cast(p)
		St.BOLT_WAIT:
			if _timer <= 0.0 and _hunt > 0:
				_hunt -= 1
				_timer = BOLT_EVERY * _pace
				var x := clampf(p.x, _left + 12.0, _right - 12.0)
				_strikes.append({"x": x, "t": BOLT_WARNING, "kind": "bolt"})
			elif _timer <= 0.0 and _hunt < 0:
				# Judgement: a phantom blade over where he stands, then the next.
				_hunt += 1
				_timer = JUDGEMENT_EVERY * _pace
				var x := clampf(p.x, _left + 12.0, _right - 12.0)
				_strikes.append({"x": x, "t": JUDGEMENT_WARNING, "kind": "blade"})
				Sfx.play("swing", -10.0, 0.2)
			elif _hunt == 0 and _strikes.is_empty():
				_enter(St.RECOVER, 0.6)
		St.THRUST_WINDUP:
			_face(p)
			if _timer <= 0.0:
				_enter(St.THRUST, 0.3)
				_shake = 0.25
		St.THRUST:
			if _timer <= 0.0:
				_enter(St.RECOVER, 0.8)
		St.RECOVER:
			if _timer <= 0.0:
				_enter(St.IDLE, 0.5)
		St.KNEEL:
			if _timer <= 0.0:
				_enter(St.TEAR, 3.0)
				_head = _pos + Vector2(0, -40)
		St.TEAR:
			# The evil pours up out of him and swells into its true size over the room.
			var t := clampf(1.0 - _timer / _state_time, 0.0, 1.0)
			_grow = t
			_evil_alpha = clampf(t * 1.6, 0.0, 1.0)
			_armor_alpha = lerpf(1.0, 0.55, t)
			var home := Vector2(clampf(p.x, _left + 140.0, _right - 140.0), EVIL_HEIGHT)
			_head = (_pos + Vector2(0, -40)).lerp(home, t * t)
			_shake = maxf(_shake, 0.1)
			if fmod(_time, 0.06) < delta:
				Effects.puff(get_parent(), _pos + Vector2(randf_range(-14, 14), -30), COLOR_SMOKE, 3, 60.0)
			if _timer <= 0.0:
				phase = 2
				max_hp = ceili(EVIL_HP * (1.5 if Game.hard else 1.0))
				hp = max_hp
				title = "The Evil Unbound"
				subtitle = "What the blade was made to hold"
				_lower_rings()
				_pace = 1.0
				_move = 0
				add_to_group("shock_target")
				_enter(St.HOVER, 0.8)


## The spell he was gathering: ice along the floor, fire flung and run along it, or bolts.
func _cast(p: Vector2) -> void:
	match _attack:
		"ice":
			# Ice bursting up out of the floor in a row running at him, each marked first.
			var side := 1 if p.x > _pos.x else -1
			for k in 9:
				var x := _pos.x + side * (40.0 + k * 30.0)
				if x < _left + 8.0 or x > _right - 8.0:
					break
				_strikes.append({"x": x, "t": 0.45 + k * 0.09, "kind": "ice_spike"})
			Sfx.play("shatter", -6.0)
			_shake = 0.3
			_enter(St.RECOVER, 1.2)
		"fire":
			for k in 4:
				var x := clampf(p.x + (k - 1.5) * 34.0, _left + 12.0, _right - 12.0)
				var from := _pos + Vector2(_dir * 20.0, -60.0)
				var flight := 0.9 + k * 0.08
				var g := 520.0
				var vel := Vector2((x - from.x) / flight, (_floor - 4.0 - from.y - 0.5 * g * flight * flight) / flight)
				_spawn("ember", from, vel, g, flight + 0.3)
				_strikes.append({"x": x, "t": flight, "kind": "ember"})
			# And pillars of flame where he stands, and to either side.
			for k in [-1, 0, 1]:
				var x := clampf(p.x + k * 70.0, _left + 12.0, _right - 12.0)
				_strikes.append({"x": x, "t": 1.0 + absf(k) * 0.25, "kind": "fire_pillar"})
			Sfx.play("fire_breath", -4.0)
			_enter(St.RECOVER, 1.5)
		"bolts":
			_hunt = BOLTS
			_enter(St.BOLT_WAIT, 0.0)
		"judgement":
			_hunt = -JUDGEMENT  # (counted up from below zero: blades, not bolts)
			_enter(St.BOLT_WAIT, 0.0)


# --- Phase 2: the evil unbound ---

func _phase_2(p: Vector2, delta: float) -> void:
	if _state not in [St.DYING, St.FINAL]:
		# Its head drifts after Storm along the top of the room (it sinks when it slumps or
		# is held, low enough to reach).
		var want := clampf(p.x, _left + 120.0, _right - 100.0)
		var drift := 0.0 if _state in [St.SLUMP, St.HELD, St.CLAW_DOWN] else EVIL_DRIFT / _pace
		_head.x = move_toward(_head.x, want, drift * delta)
		var low := 70.0 if _state in [St.SLUMP, St.HELD] else 0.0
		_head.y = move_toward(_head.y, EVIL_HEIGHT + low + sin(_time * 0.9) * 6.0, 90.0 * delta)
	match _state:
		St.HOVER:
			if _timer <= 0.0:
				_attack = _next_attack()
				match _attack:
					"claw":
						_claw = Vector2(p.x, _floor - CLAW_HOVER)
						_enter(St.CLAW_AIM, 1.1)
					"sweep":
						_sweep_dir = 1 if p.x < (_left + _right) / 2.0 else -1
						_claw = Vector2(_left + 30.0 if _sweep_dir > 0 else _right - 30.0, _floor - 20.0)
						_enter(St.SWEEP_WARN, 1.0)
					"ruin":
						_next_ruin = 0.0
						_enter(St.RUIN, RUIN_TIME)
						Sfx.play("roar", -4.0, 0.1)
					"orbs":
						_enter(St.ORBS, 0.9)
		St.CLAW_AIM:
			# The claw hangs over him, following; its shadow on the floor.
			var lock := _timer < 0.25 * _state_time
			if not lock:
				_claw.x = move_toward(_claw.x, clampf(p.x, _left + 30.0, _right - 30.0), 260.0 * delta)
			_claw.y = _floor - CLAW_HOVER + sin(_time * 6.0) * 3.0
			if _timer <= 0.0:
				_enter(St.CLAW_FALL, 0.16)
		St.CLAW_FALL:
			_claw.y = move_toward(_claw.y, _floor - CLAW_DRAW.y * 0.4, CLAW_HOVER / 0.16 * delta)
			if _timer <= 0.0:
				_claw.y = _floor - CLAW_DRAW.y * 0.4
				_shake = 0.4
				Sfx.play("slam", 0.0)
				for side in [-1, 1]:
					Effects.puff(get_parent(), Vector2(_claw.x + side * 20.0, _floor - 4.0), COLOR_SMOKE, 5, 70.0)
				_make_arm()
				_enter(St.CLAW_DOWN, ARM_TIME)
		St.CLAW_DOWN:
			if _timer <= 0.0:
				_end_arm()
				_enter(St.CLAW_RISE, 0.4)
		St.SLUMP:
			# All its eyes put out: it sags, its core bare. Then the eyes open again.
			if fmod(_time, 0.15) < delta:
				Effects.sparks(get_parent(), _head, COLOR_VIOLET_HOT, 3, 80.0)
			if _timer <= 0.0:
				_eye_hp = [EYE_HP, EYE_HP, EYE_HP]
				_enter(St.HOVER, 0.8)
		St.HELD:
			# Your father holds it down: no attacks, its head low.
			if _timer <= 0.0:
				_enter(St.HOVER, 0.6)
		St.FINAL:
			# Storm along the shockline into its core.
			var t := clampf(1.0 - _timer / _state_time, 0.0, 1.0)
			var player := _player()
			if player:
				player.velocity = Vector2.ZERO
				player.global_position = _final_from.lerp(get_parent().to_global(_head + Vector2(0, 10)), minf(1.0, t * 1.6))
			_shake = maxf(_shake, 0.2 * t)
			if _timer <= 0.0:
				_flash = 0.4
				Sfx.play("burst", 0.0, 0.0)
				Sfx.play("shatter", 0.0, 0.0)
				Effects.sparks(get_parent(), _head, COLOR_VIOLET_HOT, 40, 260.0)
				if player:
					player.global_position = get_parent().to_global(Vector2(_head.x, _floor - 2.0))
				_enter(St.DYING, DEATH_TIME)
		St.CLAW_RISE:
			_claw.y -= 300.0 * delta
			if _timer <= 0.0:
				_enter(St.HOVER, 0.7)
		St.SWEEP_WARN:
			if fmod(_time, 0.08) < delta:
				Effects.puff(get_parent(), _claw + Vector2(randf_range(-10, 10), 10), COLOR_SMOKE, 2, 40.0)
			if _timer <= 0.0:
				_enter(St.SWEEP, 0.0)
				Sfx.play("roar", -6.0, 0.2)
		St.SWEEP:
			_claw.x += _sweep_dir * SWEEP_SPEED / _pace * delta
			if fmod(_time, 0.05) < delta:
				Effects.puff(get_parent(), Vector2(_claw.x, _floor - 4.0), COLOR_SMOKE, 2, 50.0)
			if (_sweep_dir > 0 and _claw.x > _right + 20.0) or (_sweep_dir < 0 and _claw.x < _left - 20.0):
				_enter(St.HOVER, 0.8)
		St.RUIN:
			# Ice, fire and lightning all over the room, each marked on the floor first.
			_next_ruin -= delta
			if _next_ruin <= 0.0 and _timer > RUIN_WARNING:
				_next_ruin = RUIN_EVERY * _pace
				var kinds := ["icicle", "ember", "bolt"]
				var x := randf_range(_left + 12.0, _right - 12.0)
				if randf() < 0.35:
					x = clampf(p.x + randf_range(-30, 30), _left + 12.0, _right - 12.0)
				_strikes.append({"x": x, "t": RUIN_WARNING, "kind": kinds[randi() % 3]})
			if _timer <= 0.0 and _strikes.is_empty():
				_enter(St.HOVER, 0.8)
		St.ORBS:
			if _timer <= 0.0:
				for side in [-1, 0, 1]:
					_spawn("orb", _head + Vector2(side * 12.0, 30.0), Vector2(side * 70.0, 40.0), 0.0, 6.0)
				Sfx.play("screech", -4.0, 0.1)
				_enter(St.HOVER, 1.4)
		St.DYING:
			# Light breaking out of it in cracks, then it comes apart.
			var t := clampf(1.0 - _timer / _state_time, 0.0, 1.0)
			_shake = maxf(_shake, 0.15 + 0.3 * t)
			if fmod(_time, 0.12) < delta:
				Effects.sparks(get_parent(), _head + Vector2(randf_range(-60, 60), randf_range(-40, 120)),
					[COLOR_ICE, COLOR_FIRE, COLOR_SPARK][randi() % 3], 6, 140.0)
				Sfx.play("crackle", -8.0, 0.3)
			_evil_alpha = 1.0 - clampf((t - 0.75) / 0.25, 0.0, 1.0)
			if _timer <= 0.0 and not _done:
				_done = true
				_restore_camera()
				Sfx.play("burst", 0.0, 0.0)
				Effects.puff(get_parent(), _head, COLOR_SMOKE, 30, 160.0)
				Game.defeated[boss_id] = true
				defeated.emit()


# --- The arm, the chandeliers, the collapse ---

## The arm it slammed down rests as a slope from the claw up toward its head: run up it.
func _make_arm() -> void:
	_end_arm()
	var side := 1.0 if _head.x >= _claw.x else -1.0
	if absf(_head.x - _claw.x) < 50.0:
		side = 1.0 if _claw.x < (_left + _right) / 2.0 else -1.0
	var run := clampf(absf(_head.x - _claw.x) - 20.0, 90.0, 180.0)
	var from := Vector2(_claw.x, _floor - 2.0)
	_arm_top = from + Vector2(side * run, -run * ARM_SLOPE)
	_arm = StaticBody2D.new()
	_arm.collision_layer = LAYER_WORLD
	_arm.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(from.distance_to(_arm_top), 6.0)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.one_way_collision = true
	_arm.add_child(col)
	_arm.position = (from + _arm_top) / 2.0
	_arm.rotation = (_arm_top - from).angle() if side > 0.0 else (from - _arm_top).angle()
	get_parent().add_child(_arm)


func _end_arm() -> void:
	if _arm:
		_arm.queue_free()
		_arm = null


func _lower_rings() -> void:
	for i in _rings.size():
		var ring := _rings[i]
		ring.visible = true
		ring.position = _ring_rest[i] + Vector2(0, -220)
		var tween := ring.create_tween()
		tween.tween_interval(0.3 * i)
		tween.tween_property(ring, "position", _ring_rest[i], 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func() -> void: ring.add_to_group("shock_target"))
	Sfx.play("rumble", -6.0, 0.0)


## Below a third: the floor gives way to burning dark, and stone pillars rise out of it.
func _collapse() -> void:
	_collapsed = true
	_shake = 0.8
	Sfx.play("rumble", 0.0, 0.0)
	Sfx.play("roar", -2.0, 0.0)
	_say("The floor gives way to the dark. Get up on the pillars.")
	_void = _make_box(Vector2(_right - _left, 6.0), false, false)
	var x := _left + 60.0
	while x < _right - 40.0:
		var pillar := StaticBody2D.new()
		pillar.collision_layer = LAYER_WORLD
		pillar.collision_mask = 0
		var shape := RectangleShape2D.new()
		shape.size = Vector2(34, 40)
		var col := CollisionShape2D.new()
		col.shape = shape
		pillar.add_child(col)
		pillar.position = Vector2(x, _floor + 20.0)
		get_parent().add_child(pillar)
		pillar.create_tween().tween_property(pillar, "position:y", _floor - 20.0, 0.8).set_trans(Tween.TRANS_BACK)
		_pillars.append(pillar)
		x += 110.0


func _clear_collapse() -> void:
	if _void:
		_void.queue_free()
		_void = null
	for pillar in _pillars:
		pillar.queue_free()
	_pillars.clear()


# --- Strikes: the marked spots where something's about to land ---

func _update_strikes(delta: float) -> void:
	var landed := []
	for s in _strikes:
		s.t -= delta
		if s.t <= 0.0:
			landed.append(s)
			match s.kind:
				"bolt", "blade":
					var proj := Projectile.new()
					proj.kind = "bolt"
					proj.height = _floor
					proj.life = 0.3
					proj.position = Vector2(s.x, _floor)
					get_parent().add_child(proj)
					_shake = maxf(_shake, 0.2)
					Sfx.play("thunder", -10.0, 0.2)
				"icicle":
					_spawn("icicle", Vector2(s.x, _floor - 200.0), Vector2(0, 500.0), 900.0, 1.0)
				"ice_spike":
					_spawn("ice_spike", Vector2(s.x, _floor), Vector2.ZERO, 0.0, 0.6)
					Sfx.play("shatter", -14.0, 0.3)
				"fire_pillar":
					_spawn("fire_pillar", Vector2(s.x, _floor), Vector2.ZERO, 0.0, 0.8)
					Sfx.play("fire_breath", -8.0, 0.2)
				"ember" when phase == 2:
					_spawn("ember", Vector2(s.x, _floor - 200.0), Vector2(0, 460.0), 900.0, 1.0)
	for s in landed:
		_strikes.erase(s)


func _spawn(p_kind: String, pos: Vector2, vel: Vector2, accel: float, p_life: float) -> void:
	var proj := Projectile.new()
	proj.kind = p_kind
	proj.velocity = vel
	proj.fall_accel = accel
	proj.life = p_life
	proj.position = pos
	get_parent().add_child(proj)


func _update_boxes() -> void:
	var king := phase == 1 and _fighting()
	_set_box(_body_box, king, _pos + Vector2(0, -43))
	# The body takes double in a stagger (see take_hit); its contact still hurts.
	var parrying := _state == St.SLASH_WINDUP and _timer < PARRY_WINDOW * _pace
	_set_box(_parry_box, parrying, _pos + Vector2(_dir * 20.0, -96.0))
	var slashing := _state == St.SLASH
	var shape: RectangleShape2D = _blade_box.get_child(0).shape
	if slashing:
		shape.size = SLASH_REACH
		_set_box(_blade_box, true, _pos + Vector2(_dir * (SLASH_REACH.x / 2.0 + 6.0), -SLASH_REACH.y / 2.0))
	elif _state == St.LUNGE:
		shape.size = Vector2(70, 40)
		_set_box(_blade_box, true, _pos + Vector2(_dir * 40.0, -30.0))
	elif _state == St.THRUST:
		shape.size = Vector2(THRUST_REACH, 12)
		_set_box(_blade_box, true, _pos + Vector2(_dir * (THRUST_REACH / 2.0 + 10.0), -12.0))
	else:
		_set_box(_blade_box, false)
	_set_box(_head_box, phase == 2 and _fighting(), _head)
	for i in EYES.size():
		_set_box(_eye_boxes[i], phase == 2 and _fighting() and _eye_hp[i] > 0 and _state != St.SLUMP, _head + EYES[i])
	if _void:
		_set_box(_void, true, Vector2((_left + _right) / 2.0, _floor - 3.0))
	# The claw hurts as it falls and sweeps; resting on the floor it can be struck instead.
	var claw_live := _state in [St.CLAW_FALL, St.SWEEP]
	_claw_box.weak = _state == St.CLAW_DOWN
	_claw_box.harmless = _state == St.CLAW_DOWN
	_set_box(_claw_box, claw_live or _state == St.CLAW_DOWN, _claw + Vector2(0, 8))


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


# --- Drawing ---

func _draw() -> void:
	for s in _strikes:
		# Where each strike will land: a glow on the floor, brightening as it comes.
		var warning := RUIN_WARNING if phase == 2 else (JUDGEMENT_WARNING if s.kind == "blade" else 1.0 if s.kind == "fire_pillar" \
			else 0.45 if s.kind == "ice_spike" else BOLT_WARNING)
		var grow := clampf(1.0 - s.t / warning, 0.0, 1.0)
		var color: Color = {"bolt": COLOR_SPARK, "blade": COLOR_VIOLET, "icicle": COLOR_ICE, "ember": COLOR_FIRE,
			"ice_spike": COLOR_ICE, "fire_pillar": COLOR_FIRE}[s.kind]
		if s.kind == "blade":
			# A phantom blade hanging point-down over the spot, sinking as it comes.
			var tip := Vector2(s.x, _floor - 90.0 + 50.0 * grow * grow) - position
			draw_line(tip, tip + Vector2(0, -46), Color(COLOR_VIOLET, 0.35 + 0.4 * grow), 5.0)
			draw_line(tip, tip + Vector2(0, -46), Color(COLOR_VIOLET_HOT, 0.5 + 0.4 * grow), 1.5)
			draw_line(tip + Vector2(-8, -40), tip + Vector2(8, -40), Color(COLOR_VIOLET_HOT, 0.6 * grow + 0.2), 2.0)
		_draw_ellipse(Vector2(s.x, _floor) - position, Vector2(5.0 + 9.0 * grow, 2.5), Color(color, 0.25 + 0.4 * grow))
		if s.kind == "bolt" and fmod(_time, 0.1) < 0.06:
			draw_line(Vector2(s.x, 0) - position, Vector2(s.x, _floor) - position, Color(color, 0.1 + 0.3 * grow), 1.0)
	if _collapsed and _void:
		# The floor gone to burning dark.
		var y := _floor - position.y
		draw_rect(Rect2(_left - position.x, y - 6.0, _right - _left, 6.0), Color(0.05, 0.02, 0.08))
		for k in 24:
			var x := _left + fmod(k * 37.0 + _time * 40.0, _right - _left)
			draw_circle(Vector2(x - position.x, y - 4.0 - fmod(_time * 20.0 + k * 3.0, 14.0)), 2.0, Color(COLOR_VIOLET, 0.4))
	for pillar in _pillars:
		var at: Vector2 = pillar.position - position
		draw_rect(Rect2(at - Vector2(17, 20), Vector2(34, 40)), Color(0.32, 0.3, 0.36))
		draw_rect(Rect2(at - Vector2(17, 20), Vector2(34, 3)), Color(0.5, 0.48, 0.55))
	if phase == 2 or _state == St.TEAR:
		_draw_evil()
	_draw_king()
	if phase == 2:
		_draw_claw()
		_draw_eyes()
		if _state == St.HELD:
			# A chain of pale light from the King's hand to the evil's arm.
			var hand := _pos + Vector2(_dir * 24.0, -70.0) - position
			var arm := _head + Vector2(-60.0 if _pos.x < _head.x else 60.0, 70.0) - position
			for i in 8:
				var a := hand.lerp(arm, i / 8.0)
				var b := hand.lerp(arm, (i + 1) / 8.0)
				draw_line(a, b, Color(0.9, 0.95, 1.0, 0.6 + 0.3 * sin(_time * 8.0 + i)), 3.0)
	if _state == St.FINAL:
		var player := _player()
		if player:
			var at: Vector2 = get_parent().to_global(_head)
			draw_line(player.global_position - global_position + Vector2(0, -12), at - global_position,
				COLOR_VIOLET_HOT, 3.0)
	if _flash > 0.2 and phase == 2:
		draw_rect(Rect2(-position, get_parent().size_px), Color(1, 1, 1, (_flash - 0.2) * 2.0))


func _draw_king() -> void:
	var tint := Color(3, 3, 3) if _flash > 0.0 and phase == 1 else Color.WHITE
	tint.a = _armor_alpha
	if phase == 2 or _state in [St.KNEEL, St.TEAR]:
		# Kneeling, emptied: the King's armor, left behind (it fades once it's held the evil).
		tint = Color(0.55, 0.52, 0.6, _armor_alpha * (0.0 if _held_done and _state != St.HELD else 1.0))
	if _state == St.HELD:
		tint = Color(1.2, 1.25, 1.5, 0.85)  # risen, pale with light
	var tex: Texture2D = IDLE
	var frame := 0
	var t := clampf(1.0 - _timer / _state_time, 0.0, 1.0)
	match _state:
		St.DORMANT:
			tex = KNEEL
			frame = 7
		St.RISE:
			# Up out of his kneel, then down off the dais.
			tex = KNEEL if t < 0.45 else IDLE
			frame = clampi(7 - int(t / 0.45 * 8.0), 0, 7) if t < 0.45 else 0
		St.KNEEL:
			tex = KNEEL
			frame = mini(int(t * 8.0), 7)
		St.TEAR, St.HOVER, St.CLAW_AIM, St.CLAW_FALL, St.CLAW_DOWN, St.CLAW_RISE, St.SWEEP_WARN, \
				St.SWEEP, St.RUIN, St.ORBS, St.DYING, St.SLUMP, St.FINAL:
			tex = KNEEL
			frame = 7
		St.HELD:
			tex = IDLE
			frame = 0
		St.WALK:
			tex = WALK
			frame = int(_time * 8.0) % 8
		St.CAST, St.BOLT_WAIT:
			tex = CAST
			frame = mini(int((1.0 - _timer / _state_time) * 8.0), 7) if _state == St.CAST else 7
		St.THRUST_WINDUP:
			tex = THRUST
			frame = mini(int((1.0 - _timer / _state_time) * 6.0), 5)
		St.THRUST:
			tex = THRUST
			frame = 6 + mini(int((1.0 - _timer / _state_time) * 2.0), 1)
		St.SLASH_WINDUP:
			tex = SLASH
			frame = mini(int(t * 6.0), 5)
		St.SLASH:
			tex = SLASH
			frame = 6 if t < 0.5 else 7
		St.RECOVER:
			tex = SLASH if _attack == "slash" else THRUST if _attack in ["thrust", "lunge"] else CAST
			frame = 7
		St.LEAP:
			tex = SLASH
			frame = 2 if t < 0.5 else 6
		St.LUNGE_WINDUP:
			tex = THRUST
			frame = mini(int(t * 5.0), 4)
		St.LUNGE:
			tex = THRUST
			frame = 7
		St.STAGGER:
			tex = KNEEL
			frame = 3
	var at := _pos - position
	var size := DRAW
	var drop := 0.0
	if _state == St.DORMANT:
		tint = Color(0.6, 0.58, 0.66)  # kneeling in the dark before his throne
	for ghost in _trail:
		# The lunge's afterimages.
		var fade: float = 1.0 - (_time - ghost.at) / 0.35
		if fade > 0.0:
			draw_set_transform(ghost.pos - position, 0.0, Vector2(ghost.dir, 1))
			draw_texture_rect_region(THRUST, Rect2(Vector2(-size / 2.0, -size * FEET), Vector2(size, size)),
				Rect2(7 * FRAME, 0, FRAME, FRAME), Color(COLOR_VIOLET, 0.35 * fade))
	_trail = _trail.filter(func(g: Dictionary) -> bool: return _time - g.at < 0.35)
	if phase == 1 and _state != St.DORMANT and tint.a > 0.0:
		# A pale edge of light around him, so he never sinks into the dark or the throne.
		draw_set_transform(at, 0.0, Vector2(_dir, 1))
		for o in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5)]:
			draw_texture_rect_region(tex, Rect2(Vector2(-size / 2.0, -size * FEET + drop) + o, Vector2(size, size)),
				Rect2(frame * FRAME, 0, FRAME, FRAME), Color(0.85, 0.8, 1.0, 0.35 * tint.a))
	if _state == St.LUNGE_WINDUP and fmod(_time, 0.12) < 0.06:
		tint = Color(1.6, 1.3, 2.0, tint.a)
	if _state == St.STAGGER:
		tint = Color(1.4, 1.4, 1.6, tint.a) if fmod(_time, 0.2) < 0.1 else tint
	if _state == St.SLASH_WINDUP:
		# The phantom blade raised high, glowing brighter.
		var g := clampf(1.0 - _timer / _state_time, 0.0, 1.0)
		draw_circle(at + Vector2(_dir * 20.0, -96.0), 10.0 + 14.0 * g, Color(COLOR_VIOLET, 0.15 + 0.3 * g))
		if _timer < PARRY_WINDOW * _pace and fmod(_time, 0.08) < 0.05:
			# The moment to strike his blade: it flashes.
			draw_circle(at + Vector2(_dir * 20.0, -96.0), 6.0, COLOR_VIOLET_HOT)
	# (The art faces right.)
	draw_set_transform(at, 0.0, Vector2(_dir, 1))
	draw_texture_rect_region(tex, Rect2(Vector2(-size / 2.0, -size * FEET + drop), Vector2(size, size)),
		Rect2(frame * FRAME, 0, FRAME, FRAME), tint)
	draw_set_transform(Vector2.ZERO)
	if _cracked and phase == 1 and _state != St.TEAR:
		# Light bleeding out of the cracks in his armor.
		var pulse := 0.6 + 0.4 * sin(_time * 7.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var chest := at + Vector2(_dir * 2.0, -48.0 + (16.0 if _state == St.KNEEL else 0.0))
		draw_circle(chest, 16.0, Color(COLOR_VIOLET, 0.12 * pulse))
		for k in 7:
			var from := chest + Vector2(rng.randf_range(-8, 8), rng.randf_range(-14, 22))
			var pts := PackedVector2Array([from])
			for i in 3:
				pts.append(pts[-1] + Vector2(rng.randf_range(-5, 5), rng.randf_range(-6, 6)))
			draw_polyline(pts, Color(COLOR_VIOLET_HOT, 0.75 * pulse), 1.0)
	if _state == St.SLASH:
		# The great arc of the blade coming down.
		var center := at + Vector2(_dir * 12.0, -48.0)
		var pts := PackedVector2Array()
		for i in 9:
			var a := lerpf(-1.4, 1.2, float(i) / 8.0 * (0.4 + 0.6 * t))
			pts.append(center + Vector2(_dir * cos(a), sin(a)) * 86.0)
		draw_polyline(pts, Color(COLOR_VIOLET, 0.35), 22.0)
		draw_polyline(pts, Color(COLOR_VIOLET, 0.6), 10.0)
		draw_polyline(pts, COLOR_VIOLET_HOT, 3.0)
	if _state == St.THRUST_WINDUP:
		# A thin line along the floor showing how far the thrust will reach.
		var g := clampf(1.0 - _timer / _state_time, 0.0, 1.0)
		if fmod(_time, 0.1) < 0.06 or g > 0.8:
			draw_line(at + Vector2(_dir * 20.0, -12.0), at + Vector2(_dir * (THRUST_REACH + 10.0), -12.0),
				Color(COLOR_VIOLET, 0.2 + 0.5 * g), 1.0)
	if _state == St.THRUST:
		var from := at + Vector2(_dir * 20.0, -12.0)
		var to := at + Vector2(_dir * (THRUST_REACH + 10.0), -12.0)
		draw_line(from, to, Color(COLOR_VIOLET, 0.5), 12.0)
		draw_line(from, to, COLOR_VIOLET_HOT, 3.0)


func _draw_evil() -> void:
	var size := EVIL_DRAW * lerpf(0.2, 1.0, _grow)
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	tint.a = _evil_alpha
	var t := 0.0
	if _state == St.DYING:
		t = clampf(1.0 - _timer / _state_time, 0.0, 1.0)
		tint = tint.lerp(Color(2.5, 2.5, 2.8, _evil_alpha), t * 0.6)
	var origin := _head - position - EVIL_HEAD * size + Vector2(0, sin(_time * 1.3) * 2.0)
	var k := size / 256.0
	# The arms, hung from the shoulders behind the body, swaying; the one reaching out for
	# a claw thins away into the smoke that carries it.
	var reaching := _claw_side()
	for side in [-1, 1]:
		var tex: Texture2D = ARM_L if side < 0 else ARM_R
		var at: Vector2 = ARM_L_AT if side < 0 else ARM_R_AT
		var shoulder: Vector2 = SHOULDER_L if side < 0 else SHOULDER_R
		var sway: float = sin(_time * 1.1 + side) * 0.06 * side
		var arm_tint := tint
		var fall := 0.0
		if reaching == side:
			arm_tint.a *= 0.25
		if _state == St.DYING:
			fall = 120.0 * t * t  # its arms fall away first
			arm_tint.a *= 1.0 - clampf(t * 1.4, 0.0, 1.0)
		var pivot := origin + shoulder * k + Vector2(0, fall)
		draw_set_transform(pivot, sway + side * 0.3 * t, Vector2.ONE)
		draw_texture_rect(tex, Rect2((at - shoulder) * k, Vector2(tex.get_size()) * k), false, arm_tint)
		draw_set_transform(Vector2.ZERO)
	if _state == St.DYING:
		# Splitting down the middle, light pouring out of the gap.
		var gap := 40.0 * t * t
		var half := Vector2(128, 256)
		draw_rect(Rect2(origin + Vector2(128 * k - gap / 2.0, 0), Vector2(gap, size)), Color(COLOR_VIOLET_HOT, 0.8 * t))
		draw_texture_rect_region(EVIL_BODY, Rect2(origin - Vector2(gap / 2.0, 0), half * k),
			Rect2(Vector2.ZERO, half), tint)
		draw_texture_rect_region(EVIL_BODY, Rect2(origin + Vector2(128 * k + gap / 2.0, 0), half * k),
			Rect2(Vector2(128, 0), half), tint)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in int(3 + t * 9):
			var a := rng.randf() * TAU
			var from := _head - position + Vector2(rng.randf_range(-30, 30), rng.randf_range(-10, 90))
			draw_line(from, from + Vector2.from_angle(a) * rng.randf_range(20, 60) * t,
				Color(COLOR_VIOLET_HOT, 0.8 * _evil_alpha), 2.0)
	else:
		draw_texture_rect(EVIL_BODY, Rect2(origin, Vector2(size, size)), false, tint)
	if reaching != 0:
		# The reaching arm, stretched out into a tendril of smoke to the claw.
		var shoulder: Vector2 = origin + (SHOULDER_L if reaching < 0 else SHOULDER_R) * k
		var hand := _claw - position + Vector2(0, -CLAW_DRAW.y * 0.4)
		var bend := (shoulder + hand) / 2.0 + Vector2(reaching * 30.0, -20.0 + sin(_time * 3.0) * 6.0)
		var pts := PackedVector2Array()
		for i in 13:
			var u := i / 12.0
			pts.append(shoulder.lerp(bend, u).lerp(bend.lerp(hand, u), u))
		for i in 12:
			var w := lerpf(16.0, 6.0, i / 11.0)
			draw_line(pts[i], pts[i + 1], Color(COLOR_SMOKE, 0.9 * _evil_alpha), w)
		draw_polyline(pts, Color([COLOR_ICE, COLOR_FIRE, COLOR_SPARK][int(_time * 2.0) % 3], 0.5 * _evil_alpha), 1.0)


## Which arm is out after a claw (-1 left, 1 right), or 0.
func _claw_side() -> int:
	if _state not in [St.CLAW_AIM, St.CLAW_FALL, St.CLAW_DOWN, St.CLAW_RISE, St.SWEEP_WARN, St.SWEEP]:
		return 0
	return -1 if _claw.x < _head.x else 1


func _draw_eyes() -> void:
	if _state in [St.DYING, St.FINAL]:
		return
	for i in EYES.size():
		var at: Vector2 = _head + EYES[i] - position
		if _eye_hp[i] <= 0 or _state == St.SLUMP:
			draw_circle(at, 6.0, Color(0.05, 0.03, 0.06))
			continue
		var pulse := 0.6 + 0.4 * sin(_time * 4.0 + i)
		draw_circle(at, 10.0, Color(1.0, 0.9, 0.55, 0.18 * pulse))
		draw_circle(at, 5.5, Color(1.0, 0.95, 0.7))
		draw_circle(at, 2.5, Color(0.2, 0.05, 0.1))
		var frac := float(_eye_hp[i]) / EYE_HP
		draw_arc(at, 8.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 16, Color(1.0, 0.85, 0.5, 0.7), 1.5)
	if _state == St.SLUMP:
		# Its core, bare: strike it.
		var core := _head - position
		draw_circle(core, 16.0 + 3.0 * sin(_time * 10.0), Color(COLOR_VIOLET_HOT, 0.35))
		draw_circle(core, 8.0, COLOR_VIOLET_HOT)


func _draw_claw() -> void:
	if _state not in [St.CLAW_AIM, St.CLAW_FALL, St.CLAW_DOWN, St.CLAW_RISE, St.SWEEP_WARN, St.SWEEP]:
		return
	var at := _claw - position
	if _arm and _state == St.CLAW_DOWN:
		# The arm laid down as a slope, dark and veined, up toward its body.
		var bottom := Vector2(_claw.x, _floor - 2.0) - position
		var top := _arm_top - position
		var side := (top - bottom).orthogonal().normalized()
		draw_colored_polygon(PackedVector2Array([bottom + side * 9.0, top + side * 7.0, top - side * 3.0, bottom - side * 4.0]),
			Color(0.05, 0.03, 0.07))
		draw_line(bottom + side * 9.0, top + side * 7.0, Color(0.7, 0.62, 0.85), 2.0)
		var vein: Color = [COLOR_ICE, COLOR_FIRE, COLOR_SPARK][int(_time * 2.0) % 3]
		draw_line(bottom + side * 3.0, top + side * 2.0, Color(vein, 0.6), 1.0)
		var shoulder := _head + Vector2(signf(_arm_top.x - _claw.x) * -50.0, 60.0) - position
		draw_line(top, shoulder, Color(COLOR_SMOKE, 0.9), 10.0)
	if _state == St.CLAW_AIM:
		# Its shadow on the floor, darkening as it's about to fall.
		var g := clampf(1.0 - _timer / _state_time, 0.0, 1.0)
		_draw_ellipse(Vector2(at.x, _floor - position.y), Vector2(18.0 + 10.0 * g, 3.5), Color(0, 0, 0, 0.25 + 0.35 * g))
	var alpha := 1.0
	if _state == St.SWEEP_WARN:
		alpha = clampf(1.0 - _timer / _state_time, 0.0, 1.0)
	var tint := Color(1, 1, 1, alpha)
	if _state == St.CLAW_DOWN and fmod(_time, 0.3) < 0.15:
		tint = Color(1.4, 1.2, 1.6, alpha)  # resting on the floor: strike it
	var flip := -1.0 if (_state in [St.SWEEP_WARN, St.SWEEP] and _sweep_dir < 0) else 1.0
	draw_set_transform(at, 0.0, Vector2(flip, 1))
	draw_texture_rect_region(EVIL, Rect2(-CLAW_DRAW / 2.0, CLAW_DRAW), CLAW_ART, tint)
	draw_set_transform(Vector2.ZERO)


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, color)
