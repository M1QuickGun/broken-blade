extends CharacterBody2D
## Storm, last of the royal line. The node's origin is at his feet.

signal hp_changed(hp: int, max_hp: int)
signal died
signal hit_hazard

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_HAZARD := 8

const BODY_SIZE := Vector2(10, 22)

const RUN_SPEED := 140.0
const GROUND_ACCEL := 1800.0
const AIR_ACCEL := 1400.0
const JUMP_VELOCITY := -330.0
const GRAVITY_UP := 900.0
const GRAVITY_DOWN := 1400.0
## Extra gravity while rising with jump released, for variable jump height.
const JUMP_CUT_MULT := 3.0
const MAX_FALL := 420.0
const COYOTE_TIME := 0.1
const SAFE_GROUND_MARGIN := 18.0
const JUMP_BUFFER := 0.12

const ATTACK_COOLDOWN := 0.38
const SLASH_TIME := 0.1
const POGO_VELOCITY := -300.0
const RECOIL_SPEED := 120.0
const RECOIL_TIME := 0.08
const HITSTOP_TIME := 0.04
const COMBO_WINDOW := 0.7
## After a slide or shockline strike, how long touching the enemy can't hurt Storm.
const STRIKE_GUARD_TIME := 0.3

## Ice dash: a fixed-length horizontal burst with no gravity. One air dash per jump.
const DASH_SPEED := 320.0
const DASH_TIME := 0.18
const DASH_COOLDOWN := 0.45
## The slide leaves a streak of frost on the floor that melts away over this long.
const TRAIL_LIFE := 1.2
## The slide is also an attack: the blade scraping ahead of Storm strikes the first
## enemy it meets, ending the slide and bouncing him back a little.
const SLIDE_REACH := 8.0
const SLIDE_BOUNCE := Vector2(130, -140)
const SLIDE_BOUNCE_TIME := 0.15

## Fire double jump: a second jump in midair that spins Storm into a ring of fire,
## striking everything around him. One per jump.
const DOUBLE_JUMP_VELOCITY := -300.0
const SPIN_TIME := 0.32
## The spin throws out a ring of fire that grows to this radius and strikes whatever it reaches.
const SPIN_RANGE := 56.0
const SPIN_RING_START := 10.0
## Enemies count as reached this far outside the ring, since they aren't points.
const SPIN_HIT_SLACK := 8.0
const EMBER_LIFE := 0.45
const MAX_EMBERS := 90

## Sliding and spinning tuck Storm down to half height: a slide from the feet up,
## a spin around the middle of his body.
const SMALL_HEIGHT := BODY_SIZE.y / 2
const FULL_BODY := Rect2(-BODY_SIZE.x / 2, -BODY_SIZE.y, BODY_SIZE.x, BODY_SIZE.y)
const SLIDE_BODY := Rect2(-BODY_SIZE.x / 2, -SMALL_HEIGHT, BODY_SIZE.x, SMALL_HEIGHT)
const SPIN_BODY := Rect2(-BODY_SIZE.x / 2, -(BODY_SIZE.y + SMALL_HEIGHT) / 2, BODY_SIZE.x, SMALL_HEIGHT)

## Lightning shockline: fires straight ahead like a harpoon and drags Storm to
## whatever it hits, or to the end of the line. Rings hold him while the button
## is held; enemies get struck.
const SHOCK_RANGE := 160.0
const SHOCK_FIRE_SPEED := 1300.0
## How close to the line a ring or enemy must be to get caught.
const SHOCK_CATCH_RADIUS := 14.0
## Aim assist: a ring or enemy within this angle (radians) of straight ahead
## gets the line fired directly at it.
const SHOCK_ASSIST_ANGLE := 0.6
const SHOCK_PULL_SPEED := 600.0
const SHOCK_MAX_PULL_TIME := 0.6
const SHOCK_COOLDOWN := 0.2
const SHOCK_ARRIVE_DIST := 10.0
const SHOCK_STRIKE_DIST := 14.0
## Where Storm's feet sit relative to a ring he's hanging from, so the ring is
## just above his head and he can fire level at the next one.
const SHOCK_HANG_OFFSET := Vector2(0, 19)
const SHOCK_STRIKE_BOUNCE := Vector2(140, -240)
## How long momentum after a shockline pull resists air steering.
const CARRY_TIME := 0.25

const INVULN_TIME := 1.0
const HURT_LOCK_TIME := 0.25
const HURT_KNOCKBACK := Vector2(160, -200)

const COLOR_SLASH := Color(0.85, 0.9, 1.0)
const COLOR_ICE := Color(0.6, 0.88, 1.0)
const COLOR_FIRE := Color(1.0, 0.45, 0.12)
const COLOR_FIRE_CORE := Color(1.0, 0.85, 0.4)
const COLOR_BOLT := Color("fff3a8")
const COLOR_BOLT_GLOW := Color(0.65, 0.55, 1.0, 0.45)

var facing := 1
var hp := 0
## Set by Main during room transitions and respawns.
var controls_locked := false
## Last spot Storm stood on solid ground; spikes send him back here.
var safe_position := Vector2.ZERO

var _coyote := 0.0
var _jump_buffer := 0.0
var _attack_cd := 0.0
var _slash_time := 0.0
var _slash_dir := Vector2.RIGHT
var _invuln := 0.0
var _strike_guard := 0.0
var _hurt_lock := 0.0
var _recoil := 0.0
## True while rising from a pogo or knockback, so releasing jump doesn't cut the arc.
var _no_jump_cut := false
## Holds Storm in place after touching spikes, until Main respawns him.
var _frozen := false

var _dash_time := 0.0
var _dash_cd := 0.0
var _dash_dir := 1
## Recent positions during a dash, drawn as fading afterimages: [{pos, age}].
var _trail: Array[Dictionary] = []

enum Shock { NONE, FIRING, PULLING, HANGING }
var _shock := Shock.NONE
var _shock_target: Node2D = null
## Where the end of the line is, in global coordinates.
var _shock_tip := Vector2.ZERO
var _shock_dir := Vector2.RIGHT
var _shock_time := 0.0
var _shock_cd := 0.0
var _carry := 0.0

var _air_jump := true
var _spin_time := 0.0
## Enemies already struck by the current spin, so each is hit once.
var _spin_hit: Array[Object] = []
## Fire sparks thrown off by the spin: [{pos, vel, age}] in global coordinates.
var _embers: Array[Dictionary] = []

var _col: CollisionShape2D
## Storm's collision box in local coordinates: FULL_BODY, SLIDE_BODY or SPIN_BODY.
var _body := FULL_BODY

## Sprite strips in res://art/storm/<blade stage>/<anim>.png: square frames side by side,
## facing right. Each blade stage has its own set, since the blade in Storm's hand grows;
## an animation a stage doesn't have falls back to the bare-hilt one. [fps, loop]
const ANIMS := {
	"idle": [6.0, true],
	"run": [14.0, true],
	"attack": [26.0, false],
	"attack2": [26.0, false],
	"attack_up": [26.0, false],
	"attack_down": [26.0, false],
	"jump": [0.0, false],
	"slide": [40.0, false],
	"spin": [26.0, false],
}
## Where Storm's body sits across each frame size, in art pixels. Larger frames leave
## room for the blade ahead of him, so he's off-centre and the flip has to account for it.
const BODY_X_BY_FRAME := {80: 33.0, 96: 37.0}
## Jump strip frames used while rising, near the apex, and falling.
const JUMP_FRAME_RISE := 4
const JUMP_FRAME_APEX := 6
const JUMP_FRAME_FALL := 8
## The dash is short, so the slide starts partway into its drop-down.
const SLIDE_FIRST_FRAME := 4

var _sprite: AnimatedSprite2D
## SpriteFrames per blade stage, built on first use.
var _stage_frames := {}
## Keeps the attack animation playing after the (much shorter) hitbox is gone.
var _attack_anim := 0.0
## Forward swings alternate between a rising slash and a backhand return, so a string
## of attacks swings back and forth. Pausing longer than COMBO_WINDOW starts over.
var _backswing := false
var _last_swing := -INF


func _ready() -> void:
	collision_layer = LAYER_PLAYER
	collision_mask = LAYER_WORLD
	floor_snap_length = 4.0
	var shape := RectangleShape2D.new()
	shape.size = BODY_SIZE
	_col = CollisionShape2D.new()
	_col.shape = shape
	_col.position = Vector2(0, -BODY_SIZE.y / 2)
	add_child(_col)
	hp = Game.max_hp
	_build_sprite()


func place_at(pos: Vector2) -> void:
	global_position = pos
	safe_position = pos
	_coyote = 0.0
	_jump_buffer = 0.0
	_reset_moves()


func respawn_at_safe() -> void:
	global_position = safe_position
	velocity = Vector2.ZERO
	_frozen = false
	_reset_moves()


func heal_full() -> void:
	hp = Game.max_hp
	_invuln = 0.0
	_frozen = false
	velocity = Vector2.ZERO
	_reset_moves()
	hp_changed.emit(hp, Game.max_hp)


func _reset_moves() -> void:
	_dash_time = 0.0
	_air_jump = true
	_spin_time = 0.0
	_embers.clear()
	_trail.clear()
	_shock = Shock.NONE
	_shock_target = null
	_carry = 0.0


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if _frozen:
		queue_redraw()
		return

	var input_x := 0.0
	if not controls_locked:
		input_x = Input.get_axis("move_left", "move_right")
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = JUMP_BUFFER

	if is_on_floor():
		_coyote = COYOTE_TIME
		_no_jump_cut = false
		_air_jump = true
		if not controls_locked and _on_safe_ground():
			safe_position = global_position

	if not controls_locked and (_shock == Shock.NONE or _shock == Shock.HANGING):
		if Input.is_action_just_pressed("dash") and _can_dash():
			if _shock == Shock.HANGING:
				_end_shockline(0.0)
			_start_dash(input_x)
		elif Input.is_action_just_pressed("shockline") and _can_shock():
			_fire_shockline(input_x)

	if _shock == Shock.FIRING:
		_update_shock_firing(delta)
	elif _shock == Shock.PULLING:
		_update_shock_pull(delta)
	elif _shock == Shock.HANGING:
		if input_x != 0.0:
			facing = 1 if input_x > 0.0 else -1
		_update_shock_hang()
	elif _dash_time > 0.0:
		_update_dash(delta)
	else:
		_move_horizontal(input_x, delta)
		_apply_gravity(delta)
		if _jump_buffer > 0.0 and _coyote > 0.0:
			velocity.y = JUMP_VELOCITY
			_jump_buffer = 0.0
			_coyote = 0.0
			_no_jump_cut = false
		elif _jump_buffer > 0.0 and _can_double_jump():
			_start_spin()
		if _spin_time > 0.0:
			_update_spin()
		elif not controls_locked and Input.is_action_just_pressed("attack") and _attack_cd <= 0.0:
			_attack()

	_update_height()
	move_and_slide()
	if _shock == Shock.PULLING:
		_check_shock_arrival()
	_check_damage()
	_update_sprite()
	queue_redraw()


func _tick_timers(delta: float) -> void:
	_coyote -= delta
	_jump_buffer -= delta
	_attack_cd -= delta
	_slash_time -= delta
	_attack_anim -= delta
	_invuln -= delta
	_strike_guard -= delta
	_hurt_lock -= delta
	_recoil -= delta
	_dash_cd -= delta
	_shock_cd -= delta
	_carry -= delta
	_spin_time -= delta
	for point in _trail:
		point.age += delta
	while not _trail.is_empty() and _trail[0].age > TRAIL_LIFE:
		_trail.pop_front()
	for ember in _embers:
		ember.age += delta
		ember.pos += ember.vel * delta
		ember.vel.y -= 60.0 * delta  # sparks drift upward
	while not _embers.is_empty() and _embers[0].age > EMBER_LIFE:
		_embers.pop_front()


# --- Body height ---

func _is_small() -> bool:
	return _body != FULL_BODY


## Tucks down to half height while sliding or spinning, and stands back up once
## there's headroom (so a slide under a low ceiling doesn't wedge Storm into it).
func _update_height() -> void:
	var want := FULL_BODY
	if _spin_time > 0.0:
		want = SPIN_BODY
	elif _dash_time > 0.0:
		want = SLIDE_BODY
	if want == _body:
		return
	if want == FULL_BODY and not _query(FULL_BODY.grow(-0.5), LAYER_WORLD).is_empty():
		return  # still under (or over) something; stay tucked
	_body = want
	(_col.shape as RectangleShape2D).size = _body.size
	_col.position = _body.get_center()


## True when there's solid ground well past both feet, so a spike respawn
## never drops Storm at the lip of the pit he just fell into.
func _on_safe_ground() -> bool:
	var space := get_world_2d().direct_space_state
	for dx in [-SAFE_GROUND_MARGIN, SAFE_GROUND_MARGIN]:
		var q := PhysicsPointQueryParameters2D.new()
		q.position = global_position + Vector2(dx, 4)
		q.collision_mask = LAYER_WORLD
		if space.intersect_point(q, 1).is_empty():
			return false
	return true


func _move_horizontal(input_x: float, delta: float) -> void:
	if _hurt_lock > 0.0 or _recoil > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		return
	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	if _carry > 0.0 and not is_on_floor():
		accel *= 0.25
	velocity.x = move_toward(velocity.x, input_x * RUN_SPEED, accel * delta)
	if input_x != 0.0 and _slash_time <= 0.0:
		facing = 1 if input_x > 0.0 else -1


func _apply_gravity(delta: float) -> void:
	var g := GRAVITY_UP if velocity.y < 0.0 else GRAVITY_DOWN
	if velocity.y < 0.0 and not _no_jump_cut and not Input.is_action_pressed("jump"):
		g *= JUMP_CUT_MULT
	velocity.y = minf(velocity.y + g * delta, MAX_FALL)


# --- Ice dash ---

## The ice slide freezes the ground under Storm as he goes, so it only works on the floor.
func _can_dash() -> bool:
	return Game.has_ability("dash") and _dash_cd <= 0.0 and _dash_time <= 0.0 and is_on_floor()


func _start_dash(input_x: float) -> void:
	_spin_time = 0.0
	if input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
	_dash_dir = facing
	_dash_time = DASH_TIME
	_dash_cd = DASH_COOLDOWN
	_carry = 0.0


func _update_dash(delta: float) -> void:
	_dash_time -= delta
	if _slide_strike():
		return
	velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
	_trail.append({"pos": global_position, "age": 0.0})
	# Sliding off a ledge ends the slide: there's no ground left to freeze.
	if _dash_time <= 0.0 or is_on_wall() or not is_on_floor():
		_dash_time = 0.0
		velocity.x = _dash_dir * RUN_SPEED


func _slide_strike() -> bool:
	var width := BODY_SIZE.x / 2 + SLIDE_REACH
	var rect := Rect2(0.0 if _dash_dir > 0 else -width, -SMALL_HEIGHT, width, SMALL_HEIGHT)
	for hit in _query(rect, LAYER_ENEMY):
		var target: Object = hit.collider
		if not target.has_method("take_hit"):
			continue
		target.take_hit(1, Vector2(_dash_dir, 0))
		_dash_time = 0.0
		velocity = Vector2(-_dash_dir * SLIDE_BOUNCE.x, SLIDE_BOUNCE.y)
		_no_jump_cut = true
		_recoil = SLIDE_BOUNCE_TIME
		_strike(Vector2(_dash_dir, 0))
		return true
	return false


# --- Fire double jump ---

func _can_double_jump() -> bool:
	return Game.has_ability("double_jump") and _air_jump and not controls_locked \
		and not is_on_floor() and _hurt_lock <= 0.0


func _start_spin() -> void:
	velocity.y = DOUBLE_JUMP_VELOCITY
	_jump_buffer = 0.0
	_air_jump = false
	_no_jump_cut = true  # the spin always has the same arc
	_carry = 0.0
	_spin_time = SPIN_TIME
	_spin_hit.clear()
	_attack_anim = 0.0
	_sprite.play("spin")
	_sprite.frame = 0
	for i in 10:
		var dir := Vector2.from_angle(TAU * i / 10.0)
		_embers.append({"pos": _center() + dir * 6.0, "vel": dir * 90.0, "age": 0.0})


## The ring of fire sweeps outward; every enemy it reaches is struck once, and it
## throws sparks off its edge as it goes.
func _update_spin() -> void:
	var radius := _spin_ring_radius()
	var center := _center()
	var reach := Vector2(SPIN_RANGE, SPIN_RANGE)
	var struck := false
	for hit in _query(Rect2(center - global_position - reach, reach * 2), LAYER_ENEMY):
		var target: Node2D = hit.collider
		if not target.has_method("take_hit") or _spin_hit.has(target):
			continue
		var to := target.global_position - center
		if to.length() > radius + SPIN_HIT_SLACK:
			continue
		_spin_hit.append(target)
		target.take_hit(1, to.normalized() if to != Vector2.ZERO else Vector2(facing, 0))
		struck = true
	if struck:
		_hitstop()
	for i in (3 if _embers.size() < MAX_EMBERS else 0):
		var dir := Vector2.from_angle(randf() * TAU)
		_embers.append({"pos": center + dir * radius, "vel": dir * 40.0, "age": 0.0})


## The ring grows quickly at first and slows as it reaches full size.
func _spin_ring_radius() -> float:
	var t := 1.0 - clampf(_spin_time / SPIN_TIME, 0.0, 1.0)
	return lerpf(SPIN_RING_START, SPIN_RANGE, 1.0 - pow(1.0 - t, 2.0))


# --- Lightning shockline ---

func _center() -> Vector2:
	return global_position + _body.get_center()


func _can_shock() -> bool:
	return Game.has_ability("shockline") and _shock_cd <= 0.0


func _fire_shockline(input_x: float) -> void:
	_spin_time = 0.0
	if input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
	_shock = Shock.FIRING
	_shock_dir = _shock_aim()
	_shock_tip = _center()
	_shock_target = null
	_dash_time = 0.0
	_carry = 0.0


## Straight ahead, or straight at the nearest ring or enemy roughly ahead.
func _shock_aim() -> Vector2:
	var ahead := Vector2(facing, 0)
	var center := _center()
	var best := ahead
	var best_dist := INF
	for target: Node2D in get_tree().get_nodes_in_group("shock_target"):
		var to: Vector2 = target.shock_point() - center
		var dist := to.length()
		if dist > SHOCK_RANGE or dist >= best_dist or absf(ahead.angle_to(to)) > SHOCK_ASSIST_ANGLE:
			continue
		var blocked := get_world_2d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters2D.create(center, target.shock_point(), LAYER_WORLD))
		if blocked.is_empty():
			best = to.normalized()
			best_dist = dist
	return best


## The line flies straight out while Storm braces. Whatever it hits, or wherever
## it runs out, he gets dragged there.
func _update_shock_firing(delta: float) -> void:
	velocity = Vector2.ZERO
	var from := _shock_tip
	var to := from + _shock_dir * SHOCK_FIRE_SPEED * delta
	var out_of_range := _center().distance_to(to) >= SHOCK_RANGE
	if out_of_range:
		to = _center() + _shock_dir * SHOCK_RANGE

	var wall := get_world_2d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters2D.create(from, to, LAYER_WORLD))
	if not wall.is_empty():
		to = wall.position

	var target := _shock_target_between(from, to)
	if target:
		_start_shock_pull(target, target.shock_point())
	elif out_of_range or not wall.is_empty():
		_start_shock_pull(null, to)
	else:
		_shock_tip = to


## The first ring or enemy the line passes over between two points.
func _shock_target_between(from: Vector2, to: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for target: Node2D in get_tree().get_nodes_in_group("shock_target"):
		var point: Vector2 = target.shock_point()
		var closest := Geometry2D.get_closest_point_to_segment(point, from, to)
		if closest.distance_to(point) > SHOCK_CATCH_RADIUS:
			continue
		var along := from.distance_to(closest)
		if along < best_dist:
			best = target
			best_dist = along
	return best


## Target is a ring or enemy, or null to be dragged to a bare point (a miss).
func _start_shock_pull(target: Node2D, point: Vector2) -> void:
	_shock = Shock.PULLING
	_shock_target = target
	_shock_tip = point
	_shock_time = 0.0


func _update_shock_pull(delta: float) -> void:
	_shock_time += delta
	if _shock_time > SHOCK_MAX_PULL_TIME or (_shock_target != null and not is_instance_valid(_shock_target)):
		_end_shockline()
		return
	if not controls_locked and Input.is_action_just_pressed("jump"):
		# Cancel the pull into a jump.
		_end_shockline()
		velocity.y = JUMP_VELOCITY
		_no_jump_cut = false
		return
	if _shock_target:
		_shock_tip = _shock_target.shock_point()
	var to: Vector2 = _shock_tip - _center()
	_shock_dir = to.normalized()
	velocity = _shock_dir * SHOCK_PULL_SPEED


func _check_shock_arrival() -> void:
	if _shock_target != null and not is_instance_valid(_shock_target):
		_end_shockline()
		return
	var is_enemy := _shock_target != null and _shock_target.has_method("take_hit")
	var dist := _center().distance_to(_shock_tip)
	if dist <= (SHOCK_STRIKE_DIST if is_enemy else SHOCK_ARRIVE_DIST):
		if is_enemy:
			_shock_strike(_shock_target)
		elif _shock_target:
			_start_shock_hang()
		else:
			_end_shockline()
			velocity = _shock_dir * RUN_SPEED
			_carry = CARRY_TIME
	elif _shock_time > 0.05 and get_real_velocity().length() < 20.0:
		_end_shockline()  # reached a wall, or snagged on a ledge


# Hanging from a ring: held for as long as the shockline button is held.

func _start_shock_hang() -> void:
	_shock = Shock.HANGING
	_air_jump = true
	_no_jump_cut = false
	_snap_to_ring()


func _update_shock_hang() -> void:
	if not is_instance_valid(_shock_target):
		_end_shockline(0.0)
		return
	if not controls_locked and Input.is_action_just_pressed("jump"):
		_end_shockline(0.0)
		velocity.y = JUMP_VELOCITY
		return
	if controls_locked or not Input.is_action_pressed("shockline"):
		_end_shockline(0.0)  # let go and drop
		return
	_snap_to_ring()


func _snap_to_ring() -> void:
	velocity = Vector2.ZERO
	_shock_tip = _shock_target.shock_point()
	global_position = _shock_tip + SHOCK_HANG_OFFSET


func _shock_strike(enemy: Node2D) -> void:
	_end_shockline()
	var side := signf(_shock_dir.x) if _shock_dir.x != 0.0 else float(facing)
	enemy.take_hit(1, Vector2(side, 0))
	velocity = Vector2(-side * SHOCK_STRIKE_BOUNCE.x, SHOCK_STRIKE_BOUNCE.y)
	_no_jump_cut = true
	_strike(Vector2(side, 0))


## A slide or shockline landing on an enemy: Storm swipes at it and bounces off. He's
## briefly safe from contact damage, without the hurt blink, so it reads as an attack.
func _strike(dir: Vector2) -> void:
	facing = 1 if dir.x > 0.0 else -1
	_slash_dir = dir
	_slash_time = SLASH_TIME
	_attack_anim = ATTACK_COOLDOWN
	_sprite.play("attack")
	_sprite.frame = 0
	_strike_guard = STRIKE_GUARD_TIME
	_hitstop()


func _end_shockline(cooldown := SHOCK_COOLDOWN) -> void:
	_shock = Shock.NONE
	_shock_target = null
	_shock_cd = cooldown


# --- Combat ---

func _attack() -> void:
	_attack_cd = ATTACK_COOLDOWN
	_slash_time = SLASH_TIME
	_attack_anim = ATTACK_COOLDOWN
	var anim := "attack"
	if Input.is_action_pressed("look_up"):
		_slash_dir = Vector2.UP
		anim = "attack_up"
	elif Input.is_action_pressed("look_down") and not is_on_floor():
		_slash_dir = Vector2.DOWN
		anim = "attack_down"
	else:
		_slash_dir = Vector2(facing, 0)
		var now := Time.get_ticks_msec() / 1000.0
		_backswing = not _backswing if now - _last_swing < COMBO_WINDOW else false
		_last_swing = now
		if _backswing:
			anim = "attack2"
	_sprite.play(anim)
	_sprite.frame = 0

	var hit_enemy := false
	var hit_hazard_tile := false
	for hit in _query(_slash_rect(), LAYER_ENEMY | LAYER_HAZARD):
		var target: Object = hit.collider
		if target.has_method("take_hit"):
			target.take_hit(1, _slash_dir)
			hit_enemy = true
		elif target.is_in_group("hazard"):
			hit_hazard_tile = true

	if _slash_dir == Vector2.DOWN and (hit_enemy or hit_hazard_tile):
		# Pogo: bounce off whatever was struck below.
		velocity.y = POGO_VELOCITY
		_no_jump_cut = true
		_coyote = 0.0
	elif hit_enemy and _slash_dir.x != 0.0:
		velocity.x = -_slash_dir.x * RECOIL_SPEED
		_recoil = RECOIL_TIME
	if hit_enemy:
		_hitstop()


## The area the blade covers, in local coordinates. Grows with each recovered piece.
func _slash_rect() -> Rect2:
	var reach := Game.blade_reach()
	match _slash_dir:
		Vector2.UP:
			return Rect2(-11, _body.position.y - reach, 22, reach + 4)
		Vector2.DOWN:
			return Rect2(-11, -4, 22, reach + 4)
	var width := reach + BODY_SIZE.x / 2
	var x := 0.0 if _slash_dir.x > 0.0 else -width
	return Rect2(x, _body.position.y + 1, width, _body.size.y - 2)


func _hitstop() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(HITSTOP_TIME, true, false, true).timeout
	Engine.time_scale = 1.0


func _check_damage() -> void:
	if hp <= 0:
		return
	var hurtbox := Rect2(_body.position + Vector2(1, 2), _body.size - Vector2(2, 3))
	for hit in _query(hurtbox, LAYER_ENEMY | LAYER_HAZARD):
		var source: Node2D = hit.collider
		if source.is_in_group("hazard"):
			if not controls_locked:
				_hurt_by_hazard()
			return
		if _invuln <= 0.0 and _strike_guard <= 0.0 and source.has_method("take_hit"):
			_hurt_by_enemy(source.global_position.x)
			return


func _hurt_by_enemy(source_x: float) -> void:
	_take_damage()
	if hp <= 0:
		return
	if _shock != Shock.NONE:
		_end_shockline()
	_dash_time = 0.0
	var away := signf(global_position.x - source_x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * HURT_KNOCKBACK.x, HURT_KNOCKBACK.y)
	_no_jump_cut = true
	_hurt_lock = HURT_LOCK_TIME
	_invuln = INVULN_TIME


func _hurt_by_hazard() -> void:
	_take_damage()
	if hp <= 0:
		return
	_invuln = INVULN_TIME
	controls_locked = true
	_frozen = true
	velocity = Vector2.ZERO
	hit_hazard.emit()


func _take_damage() -> void:
	hp -= 1
	hp_changed.emit(hp, Game.max_hp)
	if hp <= 0:
		controls_locked = true
		died.emit()


func _query(local_rect: Rect2, mask: int) -> Array[Dictionary]:
	var shape := RectangleShape2D.new()
	shape.size = local_rect.size
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, global_position + local_rect.get_center())
	q.collision_mask = mask
	q.collide_with_areas = true
	return get_world_2d().direct_space_state.intersect_shape(q, 16)


# --- Art ---

func _build_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	# Drawn at 2x detail, so shown at half scale.
	_sprite.scale = Vector2.ONE / Game.ART_SCALE
	# Behind the trail, shockline and slash, which are drawn by this node.
	_sprite.show_behind_parent = true
	add_child(_sprite)
	_apply_blade_stage()
	_sprite.play("idle")
	Game.pieces_changed.connect(func(_count: int) -> void: _apply_blade_stage())


## Swaps in the animation set for however much of the blade Storm now holds,
## carrying on from the same animation and frame.
func _apply_blade_stage() -> void:
	var stage := Game.blade_stage()
	if not _stage_frames.has(stage):
		_stage_frames[stage] = _load_stage_frames(stage)
	var anim := _sprite.animation
	var frame := _sprite.frame
	var playing := _sprite.is_playing()
	_sprite.sprite_frames = _stage_frames[stage]
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.animation = anim
		_sprite.frame = mini(frame, _sprite.sprite_frames.get_frame_count(anim) - 1)
		if playing:
			_sprite.play()


func _load_stage_frames(stage: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim: String in ANIMS:
		var path := "res://art/storm/%s/%s.png" % [stage, anim]
		if not ResourceLoader.exists(path):
			path = "res://art/storm/hilt/%s.png" % anim
		var sheet: Texture2D = load(path)
		var size := sheet.get_height()
		frames.add_animation(anim)
		frames.set_animation_speed(anim, ANIMS[anim][0])
		frames.set_animation_loop(anim, ANIMS[anim][1])
		for i in sheet.get_width() / size:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * size, 0, size, size)
			frames.add_frame(anim, atlas)
	return frames


func _update_sprite() -> void:
	_sprite.flip_h = facing < 0
	# Keep Storm's body on the node's origin, and his feet on the bottom edge of the frame.
	var size := int(_sprite.sprite_frames.get_frame_texture(_sprite.animation, 0).get_height())
	var body_x: float = BODY_X_BY_FRAME.get(size, size / 2.0)
	_sprite.offset = Vector2((size / 2.0 - body_x) * facing, -size / 2.0)
	_sprite.visible = not (_invuln > 0.0 and fmod(_invuln, 0.16) < 0.08)
	# The spin art whirls around the middle of its frame (half a frame above the feet, in
	# world units a quarter of the art size); drop it so that lines up with the spin body.
	_sprite.position.y = size / 4.0 + SPIN_BODY.get_center().y if _spin_time > 0.0 else 0.0
	if _spin_time > 0.0:
		return  # started in _start_spin, plays through once
	if _is_small():
		# Sliding, or still tucked under a low ceiling: hold the low slide pose.
		if _sprite.animation != "slide":
			_sprite.play("slide")
			_sprite.frame = SLIDE_FIRST_FRAME
		return
	if _attack_anim > 0.0:
		return
	if not is_on_floor() and _shock != Shock.HANGING:
		_sprite.animation = "jump"
		_sprite.pause()
		if velocity.y < -80.0:
			_sprite.frame = JUMP_FRAME_RISE
		elif velocity.y < 80.0:
			_sprite.frame = JUMP_FRAME_APEX
		else:
			_sprite.frame = JUMP_FRAME_FALL
	elif absf(velocity.x) > 10.0 and _shock == Shock.NONE:
		_sprite.play("run")
	else:
		_sprite.play("idle")


func _draw() -> void:
	for i in _trail.size():
		var point: Dictionary = _trail[i]
		var fade: float = 1.0 - point.age / TRAIL_LIFE
		var o: Vector2 = point.pos - global_position
		draw_rect(Rect2(o + Vector2(-3, -1.5), Vector2(6, 1.5)), Color(COLOR_ICE, 0.7 * fade))
		draw_rect(Rect2(o + Vector2(-3, -2), Vector2(6, 0.5)), Color(1, 1, 1, 0.5 * fade))
		if i % 3 == 0:
			# Little ice crystals sticking up out of the frost.
			draw_rect(Rect2(o + Vector2(-0.5, -3.5), Vector2(1, 2)), Color(COLOR_ICE, 0.8 * fade))

	if _spin_time > 0.0:
		var center := _center() - global_position
		var radius := _spin_ring_radius()
		var fade := clampf(_spin_time / SPIN_TIME * 1.5, 0.0, 1.0)
		draw_arc(center, radius, 0.0, TAU, 48, Color(COLOR_FIRE, 0.35 * fade), 7.0)
		draw_arc(center, radius, 0.0, TAU, 48, Color(COLOR_FIRE, 0.9 * fade), 3.0)
		draw_arc(center, radius - 1.0, 0.0, TAU, 48, Color(COLOR_FIRE_CORE, fade), 1.0)

	for ember in _embers:
		var life: float = 1.0 - ember.age / EMBER_LIFE
		var color := COLOR_FIRE_CORE.lerp(COLOR_FIRE, 1.0 - life)
		draw_circle(ember.pos - global_position, 0.6 + life, Color(color, life))


	if _shock != Shock.NONE:
		_draw_shockline(_center() - global_position, _shock_tip - global_position)

	if _slash_time > 0.0:
		var center := Vector2(0, -11)
		var angle := _slash_dir.angle()
		var radius := Game.blade_reach() + 4.0
		draw_arc(center, radius, angle - 1.0, angle + 1.0, 16, COLOR_SLASH, 3.0)
		draw_arc(center, radius * 0.75, angle - 0.8, angle + 0.8, 12, Color(COLOR_SLASH, 0.5), 2.0)


## The shockline: a taut, straight line with a bright spark at its tip.
func _draw_shockline(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, COLOR_BOLT_GLOW, 3.0)
	draw_line(from, to, COLOR_BOLT, 1.0)
	draw_circle(to, 2.5, COLOR_BOLT_GLOW)
	draw_circle(to, 1.2, COLOR_BOLT)
