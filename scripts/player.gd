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
## The shortest slide; holding the button keeps it going for as long as it's held.
const DASH_TIME := 0.27
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

## Wall jump (the hilt's sword catcher): holding toward a wall while falling hooks Storm
## onto it and he slides down slowly; jumping kicks him off and away. A short grace
## period after letting go still counts, and grabbing a wall restores the double jump.
const WALL_SLIDE_SPEED := 55.0
const WALL_JUMP_PUSH := 170.0
const WALL_JUMP_VELOCITY := -310.0
const WALL_COYOTE_TIME := 0.1
## How long after a wall jump air steering is weakened, so the kick-off carries.
const WALL_JUMP_CARRY := 0.18
## Holding toward the wall while jumping off it climbs instead: mostly up, a small hop
## out, so Storm comes straight back to the wall higher up.
const WALL_CLIMB_PUSH := 60.0
const WALL_CLIMB_VELOCITY := -340.0
## The cling art leans into the wall; this is how far back to draw each stage's pose so his
## boots meet the wall's surface instead of sinking into it (measured from the art).
## Where the hilt meets the wall while sliding, from Storm's centre (x toward the wall).
const WALL_SCRAPE := Vector2(5, -12)
const WALL_POSE_BACK := {"hilt": 14.0, "ice": 14.5, "ice_fire": 15.0, "ice_lightning": 15.0, "full": 15.0}
## The wall-slide art sits high in its frame (feet well above the bottom); drop it this much.
const WALL_POSE_DROP := 6.0

## Sliding and spinning tuck Storm down to half height: a slide from the feet up,
## a spin around the middle of his body.
const SMALL_HEIGHT := BODY_SIZE.y / 2
const FULL_BODY := Rect2(-BODY_SIZE.x / 2, -BODY_SIZE.y, BODY_SIZE.x, BODY_SIZE.y)
const SLIDE_BODY := Rect2(-BODY_SIZE.x / 2, -SMALL_HEIGHT, BODY_SIZE.x, SMALL_HEIGHT)
const SPIN_BODY := Rect2(-BODY_SIZE.x / 2, -(BODY_SIZE.y + SMALL_HEIGHT) / 2, BODY_SIZE.x, SMALL_HEIGHT)

## Lightning shockline: fires straight ahead like a harpoon and drags Storm to
## whatever it hits, or to the end of the line. Enemies get struck. At a ring, Storm hooks
## his sword through it and hangs there until he moves on: jump to leap off, down to drop,
## or cast again at the next ring.
const SHOCK_RANGE := 160.0
const SHOCK_FIRE_SPEED := 1300.0
## How close to the line a ring must be to get caught.
const SHOCK_CATCH_RADIUS := 14.0
## Enemies aren't aimed at (landing the line on one is up to the player), so the line
## catches them from further off to make up for it.
const SHOCK_ENEMY_CATCH_RADIUS := 26.0
## Aim assist, for rings only: a ring within this angle (radians) of straight ahead
## gets the line fired directly at it.
const SHOCK_ASSIST_ANGLE := 0.6
const SHOCK_PULL_SPEED := 600.0
const SHOCK_MAX_PULL_TIME := 0.6
const SHOCK_COOLDOWN := 0.2
## Before the tip flies, Storm stops and points the blade at the target for this long
## while lightning gathers at the tip.
const SHOCK_AIM_TIME := 0.16
const SHOCK_ARRIVE_DIST := 10.0
const SHOCK_STRIKE_DIST := 24.0
## Where Storm's feet sit relative to a ring he's hanging from, so the ring is
## just above his head and he can fire level at the next one.
const SHOCK_HANG_OFFSET := Vector2(0, 19)
const SHOCK_STRIKE_BOUNCE := Vector2(140, -240)
## How long momentum after a shockline pull resists air steering.
const CARRY_TIME := 0.25

const INVULN_TIME := 1.0
## Drinking a flask roots Storm in place; the healing lands partway through, and a hit
## before then spills it (the flask is spent either way).
const DRINK_TIME := 0.8
const DRINK_HEAL_AT := 0.35
const COLOR_FLASK := Color("9fe6ff")
const COLOR_FLASK_CORE := Color("f2fbff")
const HURT_LOCK_TIME := 0.25
const HURT_KNOCKBACK := Vector2(160, -200)

const COLOR_SLASH := Color(0.85, 0.9, 1.0)
## Each swing throws a crescent wave from the blade. It grows with every piece recovered and
## takes on each piece's element: ice, then fire and lightning around it.
const WAVE_TIME := 0.22
const WAVE_ARC := 1.15
const COLOR_WAVE_STEEL := Color(0.8, 0.84, 0.92)
const COLOR_WAVE_ICE := Color(0.62, 0.9, 1.0)
const COLOR_WAVE_BOLT := Color(0.72, 0.56, 1.0)
const COLOR_ICE := Color(0.6, 0.88, 1.0)
const COLOR_DUST := Color(0.55, 0.5, 0.45)
const COLOR_FIRE := Color(1.0, 0.45, 0.12)
const COLOR_FIRE_CORE := Color(1.0, 0.85, 0.4)
const COLOR_BOLT := Color("fff3a8")
const COLOR_WIRE := Color("3a2a5c")
## The lightning tip of the blade, pointing right. The shockline fires it off the sword
## on a line of crackling barbed wire.
const SHOCK_TIP := preload("res://art/blade/tip.png")
## Where the lightning tip sits on the held blade, relative to Storm's centre when facing
## right: the shockline fires from here.
## Measured on the held aim pose (art/storm/<stage>/point.png, last frame): the join
## between the blade and its lightning tip.
const SWORD_POINT := Vector2(19.75, -13.75)
## Being dragged along the line (art/storm/<stage>/pull.png) Storm flies flat behind his
## blade: the art sits high in its frame so it's dropped onto his body, and the line leaves
## from the end of the (tipless) blade.
const PULL_POSE_DROP := 14.5
const SWORD_POINT_PULL := Vector2(27, 1)
## Hanging from a ring (art/storm/<stage>/hang.png): where the art sits so its blade passes
## through the ring (measured from the art).
const HANG_POSE_OFFSET := Vector2(-5.5, 22)
## While the tip is out on the shockline, Storm's sword is shown without it: the stages
## that hold the tip look exactly like these once it's gone.
const TIPLESS_STAGE := {"ice_lightning": "ice", "full": "ice_fire"}
const WIRE_TWIST := 5.0
const WIRE_BARB_SPACING := 7.0
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
var _wave_time := 0.0
var _invuln := 0.0
var _strike_guard := 0.0
var _hurt_lock := 0.0
## Counts down while drinking a flask; _drink_healed is set once the sip has mended him.
var _drink_time := 0.0
var _drink_healed := false
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

enum Shock { NONE, AIMING, FIRING, PULLING, HANGING }
var _shock := Shock.NONE
var _shock_target: Node2D = null
## Where the end of the line is, in global coordinates.
var _shock_tip := Vector2.ZERO
var _shock_dir := Vector2.RIGHT
var _shock_time := 0.0
var _shock_cd := 0.0
var _carry := 0.0

var _air_jump := true
## Which side Storm is clinging to (1 = wall on his right, -1 = left, 0 = none), and
## the grace period and side for jumping off after letting go.
var _wall_dir := 0
var _wall_coyote := 0.0
var _wall_coyote_dir := 0
var _spin_time := 0.0
## Enemies already struck by the current spin, so each is hit once.
var _spin_hit: Array[Object] = []
## Sideways push from a boss's wingbeats (units per second); the boss sets it and clears it.
var wind := 0.0
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
	"slide": [20.0, true],
	"spin": [26.0, false],
	"wall": [6.0, true],
	"drink": [10.0, false],
	"pull": [10.0, true],
	"hang": [5.0, true],
	"point": [24.0, false],
}
## Where Storm's body sits across each frame size, in art pixels. Larger frames leave
## room for the blade ahead of him, so he's off-centre and the flip has to account for it.
const BODY_X_BY_FRAME := {80: 33.0, 96: 37.0}
## Jump strip frames used while rising, near the apex, and falling.
const JUMP_FRAME_RISE := 4
const JUMP_FRAME_APEX := 6
const JUMP_FRAME_FALL := 8
## The dash is short, so the slide starts partway into its drop-down.
const SLIDE_FIRST_FRAME := 1
const SLIDE_LOOP_FROM := 3

var _sprite: AnimatedSprite2D
## SpriteFrames per blade stage, built on first use.
var _stage_frames := {}
## The stage whose animations are showing (can differ from Game.blade_stage() mid-shockline).
var _shown_stage := ""
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
	add_to_group("player")
	Game.max_hp_changed.connect(_on_max_hp_changed)
	_build_sprite()


## A mask shard raises max health and fills the new mask.
func _on_max_hp_changed(_max: int) -> void:
	hp = mini(hp + 1, Game.max_hp)
	hp_changed.emit(hp, Game.max_hp)


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

	if _shock == Shock.AIMING:
		_update_shock_aiming(delta)
	elif _shock == Shock.FIRING:
		_update_shock_firing(delta)
	elif _shock == Shock.PULLING:
		_update_shock_pull(delta)
	elif _shock == Shock.HANGING:
		if input_x != 0.0:
			facing = 1 if input_x > 0.0 else -1
		_update_shock_hang()
	elif _dash_time > 0.0:
		_update_dash(delta)
	elif _drink_time > 0.0:
		_update_drink(delta)
	elif not controls_locked and Input.is_action_just_pressed("heal") and _can_drink():
		_start_drink()
	else:
		_move_horizontal(input_x, delta)
		_apply_gravity(delta)
		_update_wall(input_x)
		if _jump_buffer > 0.0 and _coyote > 0.0:
			velocity.y = JUMP_VELOCITY
			Sfx.play("jump", -6.0)
			_jump_buffer = 0.0
			_coyote = 0.0
			_no_jump_cut = false
		elif _jump_buffer > 0.0 and _wall_coyote > 0.0:
			_wall_jump()
		elif _jump_buffer > 0.0 and _can_double_jump():
			_start_spin()
		if _spin_time > 0.0:
			_update_spin()
		elif not controls_locked and Input.is_action_just_pressed("attack") and _attack_cd <= 0.0:
			_attack()

	_update_height()
	var falling := velocity.y
	var was_on_floor := is_on_floor()
	# A boss's wind carries him along without fighting his own speed.
	velocity.x += wind
	move_and_slide()
	velocity.x -= wind
	if is_on_floor() and not was_on_floor and falling > 180.0:
		Sfx.play("land", -8.0)
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
	_wave_time -= delta
	_attack_anim -= delta
	_invuln -= delta
	_strike_guard -= delta
	_hurt_lock -= delta
	_drink_time -= delta
	_recoil -= delta
	_dash_cd -= delta
	_shock_cd -= delta
	_carry -= delta
	_spin_time -= delta
	_wall_coyote -= delta
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
	if want == FULL_BODY and not _room_to_stand():
		return  # still under something; stay tucked
	_body = want
	(_col.shape as RectangleShape2D).size = _body.size
	_col.position = _body.get_center()


## Whether the full-height body fits here. Right at a ledge or wall the tucked body can
## sit where the full one would clip a corner, so a small nudge sideways or up that frees
## it is taken on the spot (this is what used to leave Storm stuck in the slide pose).
func _room_to_stand() -> bool:
	if _query(FULL_BODY.grow(-0.5), LAYER_WORLD).is_empty():
		return true
	for nudge: Vector2 in [Vector2(-3, 0), Vector2(3, 0), Vector2(-6, 0), Vector2(6, 0),
			Vector2(0, -3), Vector2(-3, -3), Vector2(3, -3)]:
		if _query(Rect2(FULL_BODY.position + nudge, FULL_BODY.size).grow(-0.5), LAYER_WORLD).is_empty() 				and _query(Rect2(_body.position + nudge, _body.size).grow(-0.5), LAYER_WORLD).is_empty():
			global_position += nudge
			return true
	return false


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


# --- Wall jump ---

func _update_wall(input_x: float) -> void:
	_wall_dir = 0
	if not Game.has_ability("wall_jump") or controls_locked or is_on_floor() \
			or not is_on_wall() or velocity.y < 0.0:
		return
	var side := -int(signf(get_wall_normal().x))
	if side == 0 or signf(input_x) != side:
		return
	_wall_dir = side
	facing = side
	velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)
	if velocity.y > 10.0 and _embers.size() < MAX_EMBERS:
		# The hilt grinding down the stone throws sparks back off the wall.
		var scrape := _center() + Vector2(side * WALL_SCRAPE.x, WALL_SCRAPE.y)
		_embers.append({"pos": scrape, "age": randf() * 0.15,
			"vel": Vector2(-side * randf_range(30.0, 80.0), randf_range(-50.0, 10.0)),
			"color": COLOR_FIRE_CORE if randf() < 0.5 else COLOR_FIRE})
	_wall_coyote = WALL_COYOTE_TIME
	_wall_coyote_dir = side
	_air_jump = true


func _wall_jump() -> void:
	Sfx.play("jump", -6.0)
	var toward_wall := signf(Input.get_axis("move_left", "move_right")) == _wall_coyote_dir
	if toward_wall:
		velocity = Vector2(-_wall_coyote_dir * WALL_CLIMB_PUSH, WALL_CLIMB_VELOCITY)
		facing = _wall_coyote_dir
	else:
		velocity = Vector2(-_wall_coyote_dir * WALL_JUMP_PUSH, WALL_JUMP_VELOCITY)
		facing = -_wall_coyote_dir
	_wall_dir = 0
	_wall_coyote = 0.0
	_jump_buffer = 0.0
	_no_jump_cut = false
	_carry = 0.0 if toward_wall else WALL_JUMP_CARRY


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
	Sfx.play("slide", -4.0)
	_dash_cd = DASH_COOLDOWN
	_carry = 0.0


func _update_dash(delta: float) -> void:
	_dash_time -= delta
	if not controls_locked and Input.is_action_pressed("dash"):
		_dash_time = maxf(_dash_time, delta)
	if _jump_buffer > 0.0 and _room_to_stand():
		_dash_time = 0.0  # jump straight out of the slide (the buffered jump fires next frame)
		return
	if _slide_strike():
		return
	velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
	_trail.append({"pos": global_position, "age": 0.0})
	# Ice sprays up off the dragging blade behind him, dust off his leading heel.
	for i in 2:
		if _embers.size() >= MAX_EMBERS:
			break
		_embers.append({"pos": global_position + Vector2(-_dash_dir * randf_range(8.0, 14.0), -1.0),
			"vel": Vector2(-_dash_dir * randf_range(40.0, 110.0), randf_range(-90.0, -30.0)),
			"age": randf() * 0.1, "color": Color.WHITE if i == 0 else COLOR_ICE})
	if _embers.size() < MAX_EMBERS:
		_embers.append({"pos": global_position + Vector2(_dash_dir * 10.0, -1.0),
			"vel": Vector2(-_dash_dir * randf_range(10.0, 40.0), randf_range(-40.0, -10.0)),
			"age": 0.15, "color": COLOR_DUST})
	# Sliding off a ledge ends the slide: there's no ground left to freeze.
	if _dash_time <= 0.0 or is_on_wall() or not is_on_floor():
		_dash_time = 0.0
		velocity.x = _dash_dir * RUN_SPEED


func _slide_strike() -> bool:
	var width := BODY_SIZE.x / 2 + SLIDE_REACH
	var rect := Rect2(0.0 if _dash_dir > 0 else -width, -SMALL_HEIGHT, width, SMALL_HEIGHT)
	for hit in _query(rect, LAYER_ENEMY):
		var target: Object = hit.collider
		if not target.has_method("take_hit") or target.get("slide_through") == true:
			continue  # (something a slide passes under, like a drake's breath or belly)
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
	Sfx.play("spin", -3.0)
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
	Sfx.play("shock_charge", -6.0, 0.0)
	_spin_time = 0.0
	if input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
	_shock = Shock.AIMING
	_shock_time = 0.0
	_shock_dir = _shock_aim()
	_shock_tip = _sword_point()
	_shock_target = null
	_dash_time = 0.0
	_carry = 0.0


## Straight ahead, or straight at the nearest ring roughly ahead. Enemies get no help.
func _shock_aim() -> Vector2:
	var ahead := Vector2(facing, 0)
	var center := _sword_point()
	var best := ahead
	var best_dist := INF
	for target: Node2D in get_tree().get_nodes_in_group("shock_target"):
		if _is_enemy(target):
			continue
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


## Where the lightning tip sits on the held blade, in global coordinates.
func _sword_point() -> Vector2:
	var point := SWORD_POINT
	if _shock == Shock.PULLING and _sprite.sprite_frames.has_animation("pull"):
		point = SWORD_POINT_PULL.rotated(_sprite.rotation * facing)
	return _center() + Vector2(point.x * facing, point.y)


## Storm hangs still, pointing the blade, then the tip flies.
func _update_shock_aiming(delta: float) -> void:
	velocity = Vector2.ZERO
	_shock_time += delta
	if _shock_time >= SHOCK_AIM_TIME:
		_shock = Shock.FIRING
		_shock_tip = _sword_point()
		Sfx.play("shock_fire", -4.0)


## The line flies straight out while Storm braces. Whatever it hits, or wherever
## it runs out, he gets dragged there.
func _update_shock_firing(delta: float) -> void:
	velocity = Vector2.ZERO
	var from := _shock_tip
	# Storm holds still while it flies, so the line runs straight out from the blade.
	var origin := _sword_point()
	var to := from + _shock_dir * SHOCK_FIRE_SPEED * delta
	var out_of_range := origin.distance_to(to) >= SHOCK_RANGE
	if out_of_range:
		to = origin + _shock_dir * SHOCK_RANGE

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


func _is_enemy(target: Node) -> bool:
	return target.has_method("take_hit")


## The first ring or enemy the line passes over between two points.
func _shock_target_between(from: Vector2, to: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for target: Node2D in get_tree().get_nodes_in_group("shock_target"):
		var point: Vector2 = target.shock_point()
		var closest := Geometry2D.get_closest_point_to_segment(point, from, to)
		var radius := SHOCK_ENEMY_CATCH_RADIUS if _is_enemy(target) else SHOCK_CATCH_RADIUS
		if closest.distance_to(point) > radius:
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
		if is_enemy and dist <= SHOCK_STRIKE_DIST * 2.0:
			_shock_strike(_shock_target)  # snagged just short of it: still close enough to land
		else:
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
		_no_jump_cut = false
		Sfx.play("jump", -6.0)
		return
	if not controls_locked and Input.is_action_just_pressed("look_down"):
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
	_wave_time = WAVE_TIME
	_wave_sparks()
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
	Sfx.play("swing", -5.0, 0.12)
	_attack_cd = ATTACK_COOLDOWN
	_slash_time = SLASH_TIME
	_attack_anim = ATTACK_COOLDOWN
	_wave_time = WAVE_TIME
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
	_wave_sparks()

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
		if source.get("harmless") == true:
			continue  # a weak point: there to be struck, not to hurt
		if _invuln <= 0.0 and _strike_guard <= 0.0 and source.has_method("take_hit"):
			_hurt_by_enemy(source.global_position.x)
			return


# --- Healing flask ---

func _can_drink() -> bool:
	return is_on_floor() and hp < Game.max_hp and Game.flasks > 0 and _shock == Shock.NONE 			and _spin_time <= 0.0 and _hurt_lock <= 0.0 and not _is_small()


func _start_drink() -> void:
	Sfx.play("flask", -3.0, 0.02)
	Game.use_flask()
	_drink_time = DRINK_TIME
	_drink_healed = false
	_attack_anim = 0.0
	_jump_buffer = 0.0


func _update_drink(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	_apply_gravity(delta)
	if not _drink_healed and DRINK_TIME - _drink_time >= DRINK_HEAL_AT:
		_drink_healed = true
		hp = mini(hp + Game.FLASK_HEAL, Game.max_hp)
		hp_changed.emit(hp, Game.max_hp)
		# The shrine's flame flares up around him.
		for i in 16:
			if _embers.size() >= MAX_EMBERS:
				break
			var dir := Vector2.from_angle(randf() * TAU)
			_embers.append({"pos": _center() + dir * 5.0, "vel": dir * 45.0 + Vector2(0, -20),
				"age": 0.0, "color": COLOR_FLASK_CORE if i % 3 == 0 else COLOR_FLASK})


## A soft glow of shrine flame around the flask; a plain vial too if there's no drinking art.
func _draw_flask() -> void:
	var at := _flask_point() - global_position
	var pulse := 0.5 + 0.5 * sin(_drink_time * 30.0)
	draw_circle(at, 5.0 + pulse, Color(COLOR_FLASK, 0.18))
	draw_circle(at, 2.5, Color(COLOR_FLASK, 0.3))
	if _sprite.sprite_frames.has_animation("drink"):
		return
	draw_rect(Rect2(at + Vector2(-1.5, -1), Vector2(3, 3.5)), COLOR_FLASK)
	draw_rect(Rect2(at + Vector2(-0.75, -2.5), Vector2(1.5, 1.5)), COLOR_FLASK_CORE)
	draw_rect(Rect2(at + Vector2(-0.75, -3.25), Vector2(1.5, 0.75)), Color("7a6049"))


## Where the flask sits in Storm's hand while he drinks.
func _flask_point() -> Vector2:
	# Up to his lips by the time the sip lands, then back down to his belt.
	var elapsed := DRINK_TIME - _drink_time
	var t := clampf(elapsed / DRINK_HEAL_AT, 0.0, 1.0) if elapsed < DRINK_HEAL_AT 			else clampf(_drink_time / (DRINK_TIME - DRINK_HEAL_AT), 0.0, 1.0)
	return _center() + Vector2(facing * lerpf(5.0, 3.0, t), lerpf(0.0, -8.0, t))


func _hurt_by_enemy(source_x: float) -> void:
	_drink_time = 0.0
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
	_drink_time = 0.0
	_take_damage()
	if hp <= 0:
		return
	_invuln = INVULN_TIME
	controls_locked = true
	_frozen = true
	velocity = Vector2.ZERO
	hit_hazard.emit()


func _take_damage() -> void:
	Sfx.play("hurt", -2.0)
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

## The slide's drop-in frames play once; after that only the sliding frames loop.
func _on_sprite_looped() -> void:
	if _sprite.animation == "slide":
		_sprite.frame = SLIDE_LOOP_FROM


func _build_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	# Drawn at 2x detail, so shown at half scale.
	_sprite.scale = Vector2.ONE / Game.ART_SCALE
	# Behind the trail, shockline and slash, which are drawn by this node.
	_sprite.show_behind_parent = true
	add_child(_sprite)
	_sprite.animation_looped.connect(_on_sprite_looped)
	_apply_blade_stage()
	_sprite.play("idle")
	Game.pieces_changed.connect(func(_count: int) -> void: _apply_blade_stage())


## The blade stage to draw right now: the real one, minus the tip while it's flying.
func _display_stage() -> String:
	var stage := Game.blade_stage()
	if _shock == Shock.FIRING or _shock == Shock.PULLING:
		return TIPLESS_STAGE.get(stage, stage)  # the tip is out on the line
	return stage


## Swaps in the animation set for however much of the blade Storm now holds,
## carrying on from the same animation and frame.
func _apply_blade_stage() -> void:
	var stage := _display_stage()
	if stage == _shown_stage:
		return
	_shown_stage = stage
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
		if not ResourceLoader.exists(path):
			continue
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
	_apply_blade_stage()
	_sprite.flip_h = facing < 0
	# Keep Storm's body on the node's origin, and his feet on the bottom edge of the frame.
	var size := int(_sprite.sprite_frames.get_frame_texture(_sprite.animation, 0).get_height())
	var body_x: float = BODY_X_BY_FRAME.get(size, size / 2.0)
	_sprite.offset = Vector2((size / 2.0 - body_x) * facing, -size / 2.0)
	_sprite.visible = not (_invuln > 0.0 and fmod(_invuln, 0.16) < 0.08)
	_sprite.position.x = -facing * WALL_POSE_BACK.get(_shown_stage, 0.0) if _wall_dir != 0 else 0.0

	# The spin art whirls around the middle of its frame (half a frame above the feet, in
	# world units a quarter of the art size); drop it so that lines up with the spin body.
	_sprite.position.y = size / 4.0 + SPIN_BODY.get_center().y if _spin_time > 0.0 else 0.0
	if _wall_dir != 0 and _spin_time <= 0.0:
		_sprite.position.y = WALL_POSE_DROP
	if _spin_time > 0.0:
		return  # started in _start_spin, plays through once
	_sprite.rotation = 0.0
	if _shock == Shock.PULLING and _sprite.sprite_frames.has_animation("pull"):
		# Flat out behind the blade like a hookshot, tilted along the line.
		_sprite.play("pull")
		_sprite.position.y = PULL_POSE_DROP
		var along := Vector2(absf(_shock_dir.x), _shock_dir.y)
		_sprite.rotation = clampf(along.angle(), -0.7, 0.7) * facing
		return
	if _shock in [Shock.AIMING, Shock.FIRING, Shock.PULLING]:
		# Aim, then hold the blade level while the tip flies.
		_sprite.play("point" if _sprite.sprite_frames.has_animation("point") else "idle")
		return
	if _is_small():
		# Sliding, or still tucked under a low ceiling: hold the low slide pose.
		if _sprite.animation != "slide":
			_sprite.play("slide")
			_sprite.frame = SLIDE_FIRST_FRAME
		elif _dash_time <= 0.0:
			_sprite.pause()  # tucked under a ceiling after the slide: hold still
		elif not _sprite.is_playing():
			_sprite.play()
		return
	if _drink_time > 0.0:
		_sprite.play("drink" if _sprite.sprite_frames.has_animation("drink") else "idle")
		return
	if _attack_anim > 0.0:
		return
	if _wall_dir != 0:
		_sprite.play("wall")
		return
	if _shock == Shock.HANGING and _sprite.sprite_frames.has_animation("hang"):
		# Hanging from the ring by the sword hooked through it; the art is placed so the
		# blade passes through the ring.
		_sprite.play("hang")
		_sprite.position = HANG_POSE_OFFSET * Vector2(facing, 1)
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
	if _drink_time > 0.0:
		_draw_flask()
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
		var color: Color = ember.color if ember.has("color") else COLOR_FIRE_CORE.lerp(COLOR_FIRE, 1.0 - life)
		draw_circle(ember.pos - global_position, 0.6 + life, Color(color, life))


	if _shock == Shock.AIMING:
		# Lightning gathering at the tip before it flies.
		var tip := _sword_point() - global_position
		var charge := clampf(_shock_time / SHOCK_AIM_TIME, 0.0, 1.0)
		draw_circle(tip, 2.0 + charge * 3.0, Color(COLOR_BOLT_GLOW, 0.3 + charge * 0.4))
		for i in 3:
			var spark := Vector2.from_angle(randf() * TAU) * (3.0 + charge * 4.0)
			draw_line(tip, tip + spark, COLOR_BOLT, 1.0)
	elif _shock == Shock.FIRING or _shock == Shock.PULLING:
		_draw_shockline(_sword_point() - global_position, _shock_tip - global_position)

	if _wave_time > 0.0 and _shown_stage != "bare":
		_draw_wave()  # the bare shard's swings carry their own plain slash in the art


## The swing's elemental wave: a crescent thrown out along the slash that widens as it fades.
## The hilt alone throws a thin steel arc; ice thickens it into a frozen crescent, fire wraps
## flame around its outer edge, lightning crackles along it.
func _draw_wave() -> void:
	var t := 1.0 - _wave_time / WAVE_TIME
	var fade := 1.0 - t
	var center := Vector2(0, _body.get_center().y)
	var angle := _slash_dir.angle()
	var radius := (Game.blade_reach() + 2.0) * (0.75 + 0.35 * t)
	var thick := 2.0 + 2.5 * Game.pieces
	var ice := Game.has_ability("dash")
	var fire := Game.has_ability("double_jump")
	var bolt := Game.has_ability("shockline")
	if fire:
		_draw_crescent(center, radius + thick * 0.5, thick * 0.9, angle, Color(COLOR_FIRE, 0.75 * fade))
		_draw_crescent(center, radius + thick * 0.2, thick * 0.5, angle, Color(COLOR_FIRE_CORE, 0.8 * fade))
	_draw_crescent(center, radius, thick, angle, Color(COLOR_WAVE_ICE if ice else COLOR_WAVE_STEEL, 0.85 * fade))
	_draw_crescent(center, radius - thick * 0.35, thick * 0.35, angle, Color(1, 1, 1, 0.7 * fade))
	if bolt:
		var zig := PackedVector2Array()
		for i in 13:
			var a := angle - WAVE_ARC + WAVE_ARC * 2.0 * i / 12.0
			zig.append(center + Vector2.from_angle(a) * (radius + randf_range(-thick, thick) * 0.6))
		draw_polyline(zig, Color(COLOR_WAVE_BOLT, fade), 1.5)
		draw_polyline(zig, Color(COLOR_BOLT, fade), 0.8)


## A crescent: thickest in the middle of the arc, tapering to points at both ends.
func _draw_crescent(center: Vector2, radius: float, thick: float, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var a := angle - WAVE_ARC + WAVE_ARC * 2.0 * i / steps
		points.append(center + Vector2.from_angle(a) * radius)
	for i in range(steps, -1, -1):
		var a := angle - WAVE_ARC + WAVE_ARC * 2.0 * i / steps
		var taper := sin(PI * i / steps)
		points.append(center + Vector2.from_angle(a) * (radius - thick * taper))
	draw_colored_polygon(points, color)


## Throws a few sparks of the blade's elements off the wave when a swing starts.
func _wave_sparks() -> void:
	var colors: Array[Color] = [COLOR_WAVE_ICE if Game.has_ability("dash") else COLOR_WAVE_STEEL]
	if Game.has_ability("double_jump"):
		colors.append(COLOR_FIRE)
	if Game.has_ability("shockline"):
		colors.append(COLOR_BOLT)
	var center := global_position + Vector2(0, _body.get_center().y)
	for i in 3 + 2 * Game.pieces:
		if _embers.size() >= MAX_EMBERS:
			break
		var a := _slash_dir.angle() + randf_range(-WAVE_ARC, WAVE_ARC)
		var dir := Vector2.from_angle(a)
		_embers.append({"pos": center + dir * Game.blade_reach(), "vel": dir * 60.0,
			"age": 0.0, "color": colors[i % colors.size()]})


## The shockline: the blade's lightning tip flying out ahead on a strand of barbed wire,
## two twisted wires with barbs along them and electricity crackling down the middle.
func _draw_shockline(from: Vector2, to: Vector2) -> void:
	var length := from.distance_to(to)
	if length < 1.0:
		return
	var dir := (to - from) / length
	var side := dir.orthogonal()
	draw_line(from, to, COLOR_BOLT_GLOW, 4.0)
	# Two strands twisted around each other.
	var strand_a := PackedVector2Array()
	var strand_b := PackedVector2Array()
	var t := 0.0
	while t <= length:
		var twist := sin(t / WIRE_TWIST * PI) * 1.2
		strand_a.append(from + dir * t + side * twist)
		strand_b.append(from + dir * t - side * twist)
		t += 1.5
	if strand_a.size() >= 2:
		draw_polyline(strand_a, COLOR_WIRE, 1.0)
		draw_polyline(strand_b, COLOR_WIRE, 1.0)
	# Barbs: little crossed spikes along the wire.
	t = WIRE_BARB_SPACING
	while t < length - 4.0:
		var p := from + dir * t
		draw_line(p - side * 2.5 - dir * 1.5, p + side * 2.5 + dir * 1.5, COLOR_WIRE, 1.0)
		draw_line(p + side * 2.5 - dir * 1.5, p - side * 2.5 + dir * 1.5, COLOR_WIRE, 1.0)
		t += WIRE_BARB_SPACING
	# A jagged spark of lightning running down the wire, redrawn every frame.
	var bolt := PackedVector2Array([from])
	t = 4.0
	while t < length:
		bolt.append(from + dir * t + side * randf_range(-1.5, 1.5))
		t += 4.0
	bolt.append(to)
	draw_polyline(bolt, COLOR_BOLT, 1.0)
	# The tip itself, drawn at the art's 2x detail, its broken end on the wire.
	var size := SHOCK_TIP.get_size() / Game.ART_SCALE
	draw_set_transform(to, dir.angle(), Vector2.ONE / Game.ART_SCALE)
	draw_texture(SHOCK_TIP, Vector2(-SHOCK_TIP.get_width() * 0.35, -SHOCK_TIP.get_height() / 2.0))
	draw_set_transform(Vector2.ZERO)
	draw_circle(to, size.y * 0.6, Color(COLOR_BOLT_GLOW, 0.25))
