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

## Ice dash: a fixed-length horizontal burst with no gravity. One air dash per jump.
const DASH_SPEED := 320.0
const DASH_TIME := 0.18
const DASH_COOLDOWN := 0.45
const TRAIL_LIFE := 0.2

## Lightning shockline: fires straight ahead like a harpoon. If it strikes an
## anchor or enemy it latches on and yanks Storm to it; if it hits a wall or
## runs out of range it retracts.
const SHOCK_RANGE := 160.0
const SHOCK_FIRE_SPEED := 1000.0
## How close to the line an anchor or enemy must be to get caught.
const SHOCK_CATCH_RADIUS := 12.0
const SHOCK_RETRACT_SPEED := 1400.0
const SHOCK_PULL_SPEED := 480.0
const SHOCK_MAX_PULL_TIME := 0.6
const SHOCK_COOLDOWN := 0.2
const SHOCK_ARRIVE_DIST := 10.0
const SHOCK_STRIKE_DIST := 14.0
## Launch off an anchor on arrival: forward speed and upward speed.
const SHOCK_FLING := Vector2(200, -200)
const SHOCK_STRIKE_BOUNCE := Vector2(140, -240)
## How long the fling's momentum resists air steering.
const CARRY_TIME := 0.25

const INVULN_TIME := 1.0
const HURT_LOCK_TIME := 0.25
const HURT_KNOCKBACK := Vector2(160, -200)

const COLOR_CLOAK := Color("2b2f45")
const COLOR_FACE := Color("d9dde8")
const COLOR_EYES := Color("0b0c12")
const COLOR_HILT := Color("a08a5c")
const COLOR_STEEL := Color("b8c2d6")
const COLOR_SLASH := Color(0.85, 0.9, 1.0)
const COLOR_ICE := Color(0.6, 0.88, 1.0)
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
var _hurt_lock := 0.0
var _recoil := 0.0
## True while rising from a pogo or knockback, so releasing jump doesn't cut the arc.
var _no_jump_cut := false
## Holds Storm in place after touching spikes, until Main respawns him.
var _frozen := false

var _dash_time := 0.0
var _dash_cd := 0.0
var _dash_dir := 1
var _air_dash := true
## Recent positions during a dash, drawn as fading afterimages: [{pos, age}].
var _trail: Array[Dictionary] = []

enum Shock { NONE, FIRING, PULLING }
var _shock := Shock.NONE
var _shock_target: Node2D = null
## Where the end of the line is, in global coordinates.
var _shock_tip := Vector2.ZERO
var _shock_dir := Vector2.RIGHT
var _shock_time := 0.0
var _shock_cd := 0.0
## After a miss, the line is drawn reeling back in while Storm moves freely.
var _shock_retracting := false
var _carry := 0.0


func _ready() -> void:
	collision_layer = LAYER_PLAYER
	collision_mask = LAYER_WORLD
	floor_snap_length = 4.0
	var shape := RectangleShape2D.new()
	shape.size = BODY_SIZE
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -BODY_SIZE.y / 2)
	add_child(col)
	hp = Game.max_hp


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
	_air_dash = true
	_trail.clear()
	_shock = Shock.NONE
	_shock_target = null
	_shock_retracting = false
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
		_air_dash = true
		if not controls_locked and _on_safe_ground():
			safe_position = global_position

	if not controls_locked and _shock == Shock.NONE:
		if Input.is_action_just_pressed("dash") and _can_dash():
			_start_dash(input_x)
		elif Input.is_action_just_pressed("shockline") and _can_shock():
			_fire_shockline(input_x)

	if _shock == Shock.FIRING:
		_update_shock_firing(delta)
	elif _shock == Shock.PULLING:
		_update_shock_pull(delta)
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
		if not controls_locked and Input.is_action_just_pressed("attack") and _attack_cd <= 0.0:
			_attack()

	move_and_slide()
	if _shock == Shock.PULLING:
		_check_shock_arrival()
	_check_damage()
	queue_redraw()


func _tick_timers(delta: float) -> void:
	_coyote -= delta
	_jump_buffer -= delta
	_attack_cd -= delta
	_slash_time -= delta
	_invuln -= delta
	_hurt_lock -= delta
	_recoil -= delta
	_dash_cd -= delta
	_shock_cd -= delta
	if _shock_retracting:
		_shock_tip = _shock_tip.move_toward(_center(), SHOCK_RETRACT_SPEED * delta)
		_shock_retracting = _shock_tip.distance_to(_center()) > 4.0
	_carry -= delta
	for point in _trail:
		point.age += delta
	while not _trail.is_empty() and _trail[0].age > TRAIL_LIFE:
		_trail.pop_front()


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

func _can_dash() -> bool:
	return Game.has_ability("dash") and _dash_cd <= 0.0 and _dash_time <= 0.0 \
		and (is_on_floor() or _air_dash)


func _start_dash(input_x: float) -> void:
	if input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
	_dash_dir = facing
	_dash_time = DASH_TIME
	_dash_cd = DASH_COOLDOWN
	_carry = 0.0
	if not is_on_floor():
		_air_dash = false


func _update_dash(delta: float) -> void:
	_dash_time -= delta
	velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
	_trail.append({"pos": global_position, "age": 0.0})
	if _dash_time <= 0.0 or is_on_wall():
		_dash_time = 0.0
		velocity.x = _dash_dir * RUN_SPEED


# --- Lightning shockline ---

func _center() -> Vector2:
	return global_position + Vector2(0, -BODY_SIZE.y / 2)


func _can_shock() -> bool:
	return Game.has_ability("shockline") and _shock_cd <= 0.0


func _fire_shockline(input_x: float) -> void:
	if input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
	_shock = Shock.FIRING
	_shock_dir = Vector2(facing, 0)
	_shock_tip = _center()
	_shock_retracting = false
	_dash_time = 0.0
	_carry = 0.0


## The line flies straight out. Storm braces in place until it hits or misses.
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
		_shock = Shock.PULLING
		_shock_target = target
		_shock_tip = target.shock_point()
		_shock_time = 0.0
		return
	_shock_tip = to
	if out_of_range or not wall.is_empty():
		_shock = Shock.NONE
		_shock_retracting = true
		_shock_cd = SHOCK_COOLDOWN


## The first anchor or enemy the line passes over between two points.
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


func _update_shock_pull(delta: float) -> void:
	_shock_time += delta
	if not is_instance_valid(_shock_target) or _shock_time > SHOCK_MAX_PULL_TIME:
		_end_shockline()
		return
	if not controls_locked and Input.is_action_just_pressed("jump"):
		# Cancel the pull into a jump.
		_end_shockline()
		velocity.y = JUMP_VELOCITY
		_no_jump_cut = false
		return
	_shock_tip = _shock_target.shock_point()
	var to: Vector2 = _shock_tip - _center()
	_shock_dir = to.normalized()
	velocity = _shock_dir * SHOCK_PULL_SPEED


func _check_shock_arrival() -> void:
	if not is_instance_valid(_shock_target):
		_end_shockline()
		return
	var is_enemy := _shock_target.has_method("take_hit")
	var dist: float = _center().distance_to(_shock_target.shock_point())
	if dist <= (SHOCK_STRIKE_DIST if is_enemy else SHOCK_ARRIVE_DIST):
		if is_enemy:
			_shock_strike(_shock_target)
		else:
			_shock_fling()
	elif _shock_time > 0.05 and get_real_velocity().length() < 20.0:
		_end_shockline()  # snagged on a wall or ledge


func _shock_fling() -> void:
	_end_shockline()
	velocity = Vector2(_shock_dir.x * SHOCK_FLING.x, SHOCK_FLING.y)
	_carry = CARRY_TIME
	_no_jump_cut = true
	_air_dash = true
	_coyote = 0.0


func _shock_strike(enemy: Node2D) -> void:
	_end_shockline()
	var side := signf(_shock_dir.x) if _shock_dir.x != 0.0 else float(facing)
	enemy.take_hit(1, Vector2(side, 0))
	velocity = Vector2(-side * SHOCK_STRIKE_BOUNCE.x, SHOCK_STRIKE_BOUNCE.y)
	_no_jump_cut = true
	_air_dash = true
	_invuln = maxf(_invuln, 0.3)
	_hitstop()


func _end_shockline() -> void:
	_shock = Shock.NONE
	_shock_target = null
	_shock_cd = SHOCK_COOLDOWN


# --- Combat ---

func _attack() -> void:
	_attack_cd = ATTACK_COOLDOWN
	_slash_time = SLASH_TIME
	if Input.is_action_pressed("look_up"):
		_slash_dir = Vector2.UP
	elif Input.is_action_pressed("look_down") and not is_on_floor():
		_slash_dir = Vector2.DOWN
	else:
		_slash_dir = Vector2(facing, 0)

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
			return Rect2(-11, -BODY_SIZE.y - reach, 22, reach + 4)
		Vector2.DOWN:
			return Rect2(-11, -4, 22, reach + 4)
	var width := reach + BODY_SIZE.x / 2
	var x := 0.0 if _slash_dir.x > 0.0 else -width
	return Rect2(x, -BODY_SIZE.y + 1, width, 20)


func _hitstop() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(HITSTOP_TIME, true, false, true).timeout
	Engine.time_scale = 1.0


func _check_damage() -> void:
	if hp <= 0:
		return
	var hurtbox := Rect2(-BODY_SIZE.x / 2 + 1, -BODY_SIZE.y + 2, BODY_SIZE.x - 2, BODY_SIZE.y - 3)
	for hit in _query(hurtbox, LAYER_ENEMY | LAYER_HAZARD):
		var source: Node2D = hit.collider
		if source.is_in_group("hazard"):
			if not controls_locked:
				_hurt_by_hazard()
			return
		if _invuln <= 0.0 and source.has_method("take_hit"):
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


# --- Placeholder art ---

func _draw() -> void:
	for point in _trail:
		var fade: float = 1.0 - point.age / TRAIL_LIFE
		var o: Vector2 = point.pos - global_position
		draw_rect(Rect2(o + Vector2(-5, -22), Vector2(10, 22)), Color(COLOR_ICE, 0.35 * fade))

	if _shock != Shock.NONE or _shock_retracting:
		_draw_shockline(_center() - global_position, _shock_tip - global_position)

	var blinking := _invuln > 0.0 and fmod(_invuln, 0.16) < 0.08
	if not blinking:
		draw_rect(Rect2(-5, -15, 10, 15), COLOR_CLOAK)
		draw_rect(Rect2(-4, -22, 8, 8), COLOR_FACE)
		draw_rect(Rect2(-3 + facing, -19, 2, 3), COLOR_EYES)
		draw_rect(Rect2(1 + facing, -19, 2, 3), COLOR_EYES)
		if _slash_time <= 0.0:
			# The broken blade, held low. It visibly lengthens with each piece.
			var hand := Vector2(facing * 5, -8)
			draw_line(hand, hand + Vector2(facing * (3 + Game.pieces * 4), 3), COLOR_STEEL, 2.0)
			draw_rect(Rect2(hand.x - 1, hand.y - 1, 3, 3), COLOR_HILT)

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
