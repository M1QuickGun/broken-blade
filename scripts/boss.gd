extends CharacterBody2D
## A boss: the Gate Warden guarding the frozen village, or the Frost Warden who holds the
## ice shard (fought twice; the rematch is "phase 2", faster and meaner).
##
## Between attacks it closes in on Storm, then picks one:
## - charge: crouches, then rushes along the floor; slamming into a wall stuns it.
## - leap: jumps at Storm and slams down, sending shockwaves along the floor both ways.
## - icicle rain (frost only): raises its sword and calls icicles down around Storm.
## The node's origin is at its feet.

signal defeated

const Effects := preload("res://scripts/effects.gd")
const LAYER_WORLD := 1
const LAYER_ENEMY := 4
const Projectile := preload("res://scripts/projectile.gd")

const GRAVITY := 900.0
const MAX_FALL := 420.0
## How far the arena's ceiling is from the top of the room; icicles start here.
const ICICLE_Y := 20.0

enum St { INTRO, IDLE, WALK, CHARGE_WINDUP, CHARGE, LEAP_WINDUP, LEAP, RAIN_WINDUP, RECOVER, DYING }

const COLOR_IRON := Color("2e3140")
const COLOR_IRON_LIGHT := Color("4a4f63")
const COLOR_EMBER := Color("ff8a3d")
const COLOR_FROST_CLOAK := Color("1d2c44")
const COLOR_FROST_ARMOR := Color("9fc7e0")
const COLOR_FROST_LIGHT := Color("e3f5ff")
const COLOR_FROST_EYES := Color("6ff3ff")

## Set by the room before it's added.
var boss_id := ""
var kind := "gate"
var phase := 1
var title := ""
var max_hp := 12

var hp := 0
var facing := -1

var _state := St.INTRO
var _timer := 1.2
var _flash := 0.0
var _landed := true
var _size := Vector2(26, 32)
var _time := 0.0


func _ready() -> void:
	hp = max_hp
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD
	if kind == "frost":
		_size = Vector2(22, 34)
	var shape := RectangleShape2D.new()
	shape.size = _size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -_size.y / 2)
	add_child(col)
	add_to_group("boss")
	add_to_group("shock_target")


func shock_point() -> Vector2:
	return global_position + Vector2(0, -_size.y / 2)


func _speed_scale() -> float:
	return 1.3 if phase >= 2 else 1.0


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_time += delta
	_flash -= delta
	_timer -= delta
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	var player := _player()
	match _state:
		St.INTRO:
			velocity.x = 0.0
			if _timer <= 0.0:
				_enter(St.IDLE)
		St.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			_face(player)
			if _timer <= 0.0:
				_enter(St.WALK)
		St.WALK:
			_face(player)
			velocity.x = facing * (55.0 if kind == "gate" else 65.0) * _speed_scale()
			var near := player and absf(player.global_position.x - global_position.x) < 70.0
			if near or _timer <= 0.0 or _facing_wall():
				_choose_attack(player)
		St.CHARGE_WINDUP:
			velocity.x = -facing * 20.0
			if _timer <= 0.0:
				_enter(St.CHARGE)
		St.CHARGE:
			velocity.x = facing * (280.0 if kind == "gate" else 300.0) * _speed_scale()
			if _facing_wall():
				velocity.x = -facing * 120.0
				velocity.y = -150.0
				_enter(St.RECOVER, 1.0)  # slammed into the wall: stunned
			elif _timer <= 0.0:
				_enter(St.RECOVER, 0.5)
		St.LEAP_WINDUP:
			velocity.x = 0.0
			if _timer <= 0.0:
				_leap(player)
		St.LEAP:
			if is_on_floor() and velocity.y >= 0.0 and _timer <= 0.0:
				_slam()
				_enter(St.RECOVER, 0.6)
		St.RAIN_WINDUP:
			velocity.x = 0.0
			if _timer <= 0.0:
				_rain(player)
				_enter(St.RECOVER, 0.5)
		St.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if _timer <= 0.0:
				_enter(St.IDLE)
		St.DYING:
			velocity.x = 0.0
			if _timer <= 0.0:
				defeated.emit()
				queue_free()
	move_and_slide()
	queue_redraw()


func _enter(state: St, time := -1.0) -> void:
	_state = state
	match state:
		St.IDLE:
			_timer = (0.7 if phase == 1 else 0.45) if time < 0.0 else time
		St.WALK:
			_timer = 1.1
		St.CHARGE_WINDUP:
			_timer = 0.5 / _speed_scale()
		St.CHARGE:
			_timer = 1.1
		St.LEAP_WINDUP:
			_timer = 0.35 / _speed_scale()
		St.RAIN_WINDUP:
			_timer = 0.6 / _speed_scale()
		_:
			_timer = time


func _choose_attack(player: Node2D) -> void:
	var options := ["charge", "leap"]
	if kind == "frost":
		options.append("rain")
	var far := player and absf(player.global_position.x - global_position.x) > 120.0
	var pick: String = options.pick_random()
	if far and randf() < 0.5:
		pick = "charge"
	match pick:
		"charge":
			_face(player)
			_enter(St.CHARGE_WINDUP)
		"leap":
			_enter(St.LEAP_WINDUP)
		"rain":
			_enter(St.RAIN_WINDUP)


func _leap(player: Node2D) -> void:
	_face(player)
	var dx := (player.global_position.x - global_position.x) if player else facing * 80.0
	velocity = Vector2(clampf(dx / 0.85, -220.0, 220.0) * _speed_scale(), -420.0)
	_enter(St.LEAP, 0.15)


## Landing from a leap: shockwaves run out along the floor both ways.
func _slam() -> void:
	var wave_kind := "frost_wave" if kind == "frost" else "dust_wave"
	var speed := 150.0 * _speed_scale()
	for dir in [-1, 1]:
		_spawn(wave_kind, global_position + Vector2(dir * (_size.x / 2 + 4), 0), Vector2(dir * speed, 0), 0.0, 1.3)
		if phase >= 2:
			_spawn(wave_kind, global_position + Vector2(dir * (_size.x / 2 + 4), 0), Vector2(dir * speed * 0.6, 0), 0.0, 1.8)


## Icicles fall around wherever Storm is standing.
func _rain(player: Node2D) -> void:
	var center := player.global_position.x if player else global_position.x
	var count := 3 if phase == 1 else 5
	for i in count:
		var x := center + (i - (count - 1) / 2.0) * 34.0 + randf_range(-8.0, 8.0)
		_spawn("icicle", Vector2(x, ICICLE_Y), Vector2.ZERO, 500.0, 2.5, i * 0.12)


func _spawn(p_kind: String, pos: Vector2, vel: Vector2, grav: float, p_life: float, delay := 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree():
			return
	var p := Projectile.new()
	p.kind = p_kind
	p.velocity = vel
	p.fall_accel = grav
	p.life = p_life
	p.position = pos
	get_parent().add_child(p)


func take_hit(damage: int, _from_dir: Vector2) -> void:
	if _state == St.INTRO or _state == St.DYING:
		return
	hp -= damage
	_flash = 0.1
	Sfx.play("hit_boss", -3.0)
	Effects.sparks(get_parent(), position + Vector2(0, -_size.y / 2), Color(0.85, 0.95, 1.0), 12)
	if hp <= 0:
		hp = 0
		Effects.slow_motion(get_tree())
		Game.defeated[boss_id] = true
		remove_from_group("shock_target")
		collision_layer = 0
		_enter(St.DYING, 1.0)


func _face(player: Node2D) -> void:
	if player:
		facing = 1 if player.global_position.x > global_position.x else -1


func _facing_wall() -> bool:
	return is_on_wall() and signf(get_wall_normal().x) == -facing


# --- Art (placeholder shapes until the bosses get sprites) ---

func _draw() -> void:
	var dying := _state == St.DYING
	var alpha := clampf(_timer, 0.0, 1.0) if dying else 1.0
	var tint := Color(1, 1, 1, alpha)
	if _flash > 0.0 or (dying and fmod(_time, 0.12) < 0.06):
		tint = Color(3, 3, 3, alpha)
	var windup := _state in [St.CHARGE_WINDUP, St.LEAP_WINDUP, St.RAIN_WINDUP]
	var crouch := 4.0 if _state in [St.CHARGE_WINDUP, St.LEAP_WINDUP] else 0.0
	if kind == "gate":
		_draw_gate_warden(tint, crouch, windup)
	else:
		_draw_frost_warden(tint, crouch, windup)


func _draw_gate_warden(tint: Color, crouch: float, windup: bool) -> void:
	var f := float(facing)
	var top := -_size.y + crouch
	var iron := COLOR_IRON * tint
	var light := COLOR_IRON_LIGHT * tint
	# Legs, torso, pauldrons, helm.
	draw_rect(Rect2(-9, -9, 7, 9), iron)
	draw_rect(Rect2(2, -9, 7, 9), iron)
	draw_rect(Rect2(-12, top + 10, 24, 14 - crouch * 0.5), iron)
	draw_rect(Rect2(-14, top + 9, 8, 6), light)
	draw_rect(Rect2(6, top + 9, 8, 6), light)
	draw_rect(Rect2(-7, top, 14, 11), light)
	var ember := COLOR_EMBER * Color(1, 1, 1, tint.a)
	draw_rect(Rect2(-5 + f * 1.0, top + 4, 10, 2), ember if not windup else Color(1.0, 0.9, 0.5, tint.a))
	# A tower shield held in front.
	var shield_x := f * 12.0 - 5.0
	draw_rect(Rect2(shield_x, top + 8, 10, 22), Color("3b3024") * tint)
	draw_rect(Rect2(shield_x + 1, top + 9, 8, 1), light)
	draw_circle(Vector2(shield_x + 5, top + 18), 1.5, ember)


func _draw_frost_warden(tint: Color, crouch: float, windup: bool) -> void:
	var f := float(facing)
	var top := -_size.y + crouch
	var sway := sin(_time * 3.0) * 1.5
	var cloak := COLOR_FROST_CLOAK * tint
	var armor := COLOR_FROST_ARMOR * tint
	var light := COLOR_FROST_LIGHT * tint
	# A tattered cloak streaming behind.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-f * 4, top + 8), Vector2(-f * 16 + sway, top + 22), Vector2(-f * 13 + sway, 0),
		Vector2(-f * 6, -4), Vector2(f * 4, top + 10),
	]), cloak)
	draw_rect(Rect2(-7, -10, 5, 10), cloak)
	draw_rect(Rect2(2, -10, 5, 10), cloak)
	draw_rect(Rect2(-8, top + 10, 16, 16 - crouch * 0.5), armor)
	draw_rect(Rect2(-6, top + 2, 12, 9), armor)
	# A crown of icicles.
	for i in 3:
		var x := -5.0 + i * 5.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 2, top + 3), Vector2(x, top - 5 - (2 if i == 1 else 0)), Vector2(x + 2, top + 3),
		]), light)
	var eyes := COLOR_FROST_EYES * Color(1, 1, 1, tint.a)
	draw_rect(Rect2(f * 2 - 1, top + 6, 2, 2), eyes)
	draw_rect(Rect2(f * 2 - 5 + (4 if f > 0 else 0), top + 6, 2, 2), eyes)
	# An ice greatsword: raised overhead while calling the icicles, held low otherwise.
	var hand := Vector2(f * 8, top + 16)
	var tip := hand + (Vector2(f * 4, -26) if windup else Vector2(f * 20, 8))
	draw_line(hand, tip, light, 3.0)
	draw_line(hand, tip, COLOR_FROST_EYES * Color(1, 1, 1, 0.6 * tint.a), 1.0)
