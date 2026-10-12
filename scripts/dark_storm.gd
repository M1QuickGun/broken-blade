extends CharacterBody2D
## Dark Storm (the hall of mirrors, off the lift shaft): something the evil made out of what
## the blade remembers of its bearer. It has Storm's shape, his blade and every trick he's
## learned, in black glass and violet light. Nothing to win but the fight. In turn:
## - Slash: it runs at him and swings, twice if he's still close.
## - Dash: it crouches (a flash at its feet), then slides along the floor at him: jump it.
## - Plunge: it leaps over him and drives the blade straight down where he stands.
## - Spin: from the air, a ring of black fire bursts out around it.
## - Shockline: it points the blade, a thin line showing where, and zips along it.
## - Mirror: for a few seconds it copies whatever Storm does, a beat after him.
## Below half health it chains them faster, sends its reflections out of the walls at him (one
## blow breaks them), and once drinks a flask of its own: strike it to spill it. Beaten, it
## shatters into glass. Its hall is pale silver glass, the two of them reflected in the floor.

signal defeated
signal engaged

const Effects := preload("res://scripts/effects.gd")

const SHEETS := {
	"idle": preload("res://art/storm/full/idle.png"),
	"run": preload("res://art/storm/full/run.png"),
	"attack": preload("res://art/storm/full/attack.png"),
	"attack2": preload("res://art/storm/full/attack2.png"),
	"attack_down": preload("res://art/storm/full/attack_down.png"),
	"jump": preload("res://art/storm/full/jump.png"),
	"slide": preload("res://art/storm/full/slide.png"),
	"spin": preload("res://art/storm/full/spin.png"),
	"point": preload("res://art/storm/full/point.png"),
}
const FPS := {"idle": 6.0, "run": 14.0, "attack": 26.0, "attack2": 26.0, "attack_down": 26.0,
	"jump": 0.0, "slide": 20.0, "spin": 26.0, "point": 24.0}
## Storm's body sits this far across a 96 px frame (see player.gd's BODY_X_BY_FRAME).
const BODY_X := 37.0
const ART_SCALE := 2.0

const LAYER_WORLD := 1
const LAYER_ENEMY := 4
const BODY := Vector2(10, 22)
const GRAVITY := 1100.0
const RUN := 150.0
const JUMP := -360.0
const DASH := 330.0
const ZIP := 520.0
const SLASH_REACH := Vector2(34, 26)
const SPIN_RADIUS := 52.0
const PATTERN := ["slash", "mirror", "dash", "plunge", "slash", "shockline", "spin", "mirror", "dash", "plunge"]
const PATTERN_HARD := ["mirror", "reflections", "slash", "dash", "plunge", "reflections", "shockline", "spin", "slash"]
## Mirroring: how long, and how long after Storm it copies each move.
const MIRROR_TIME := 3.5
const MIRROR_DELAY := 0.35
const DRINK_TIME := 1.1
const DRINK_HEAL := 14
const COLOR_BODY := Color(0.28, 0.22, 0.38)
const COLOR_GLOW := Color(0.72, 0.45, 1.0)
const COLOR_HOT := Color(0.95, 0.85, 1.0)

enum St { DORMANT, WAKE, IDLE, RUN, SLASH, DASH_WINDUP, DASH, LEAP, PLUNGE, SPIN, AIM, ZIP, RECOVER, SHATTER,
	MIRROR, DRINK }

var boss_id := ""
var kind := "dark_storm"
var phase := 1
var title := ""
var max_hp := 52
var hp := 0

var _state := St.DORMANT
var _timer := 0.0
var _state_time := 1.0
var _time := 0.0
var _flash := 0.0
var _move := 0
var _dir := -1
var _pace := 1.0
var _combo := 0
var _anim := "idle"
var _anim_time := 0.0
var _aim := Vector2.RIGHT
var _trail: Array[Dictionary] = []
var _body: Hitbox
var _blade: Hitbox
var _done := false
## Moves of Storm's to copy: [action, when].
var _echo: Array = []
var _drank := false
## While mirroring: until when (it goes back to copying after each move it copies).
var _mirror_until := 0.0
## The floor it stands on, for the reflections in it.
var _floor_y := 0.0
var _ghost_time := 0.0


## Its reflection, stepping out of the wall and dashing across: one blow breaks it.
class Reflection extends Area2D:
	var boss: Node
	var speed := 260.0
	var life := 2.2
	var damage := 1

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		monitoring = false
		var shape := RectangleShape2D.new()
		shape.size = Vector2(12, 22)
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = Vector2(0, -11)
		add_child(col)

	func _physics_process(delta: float) -> void:
		position.x += speed * delta
		life -= delta
		if life <= 0.0:
			queue_free()
		queue_redraw()

	func take_hit(_amount: int, _from: Vector2) -> void:
		Sfx.play("shatter", -6.0, 0.2)
		load("res://scripts/effects.gd").sparks(get_parent(), global_position + Vector2(0, -11), Color(0.85, 0.85, 1.0), 10, 120.0)
		queue_free()

	func _draw() -> void:
		boss.draw_reflection(self, signf(speed))


## A shard of the broken mirror, tumbling away.
class GlassShard extends Node2D:
	var velocity := Vector2.ZERO
	var spin := 0.0
	var life := 1.2
	var size := 4.0

	func _process(delta: float) -> void:
		velocity.y += 500.0 * delta
		position += velocity * delta
		rotation += spin * delta
		life -= delta
		if life <= 0.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(life / 0.5, 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-size, size * 0.6), Vector2(size * 0.8, size), Vector2(0, -size)]),
			Color(0.85, 0.85, 1.0, 0.8 * a))
		draw_line(Vector2(0, -size), Vector2(size * 0.8, size), Color(1, 1, 1, a), 1.0)


class Hitbox extends Area2D:
	var boss: Node
	var weak := false

	func take_hit(damage: int, from_dir: Vector2) -> void:
		if weak:
			boss.take_hit(damage, from_dir)


func _ready() -> void:
	hp = max_hp
	collision_layer = 0
	collision_mask = LAYER_WORLD
	var shape := RectangleShape2D.new()
	shape.size = BODY
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -BODY.y / 2.0)
	add_child(col)
	_body = _make_box(BODY + Vector2(4, 2), true)
	_body.position = Vector2(0, -BODY.y / 2.0)
	_blade = _make_box(SLASH_REACH, false)


func _make_box(size: Vector2, weak: bool) -> Hitbox:
	var box := Hitbox.new()
	box.boss = self
	box.weak = weak
	box.collision_layer = 0
	box.collision_mask = 0
	box.monitoring = false
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	box.add_child(col)
	add_child(box)
	return box


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func shock_point() -> Vector2:
	return global_position + Vector2(0, -BODY.y / 2.0)


func reward_point() -> Vector2:
	return global_position + Vector2(0, -8)


func take_hit(damage: int, from_dir: Vector2) -> void:
	if _state in [St.DORMANT, St.WAKE, St.SHATTER]:
		return
	if _state == St.DRINK:
		# Struck mid-drink: the flask spills.
		Sfx.play("shatter", -4.0, 0.0)
		Effects.sparks(get_parent(), shock_point(), Color("9fe6ff"), 12, 120.0)
		_enter(St.RECOVER, 0.8)
	hp -= damage
	_flash = 0.12
	Sfx.play("hit_boss", -3.0)
	Effects.sparks(get_parent(), shock_point(), COLOR_GLOW, 10)
	if hp <= max_hp / 2:
		_pace = 0.72
		if not _drank and hp > 0 and _state != St.DRINK:
			_drank = true
			_enter(St.DRINK, DRINK_TIME)
			Sfx.play("flask", -6.0, 0.0)
			return
	if hp <= 0:
		hp = 0
		Effects.slow_motion(get_tree())
		remove_from_group("boss")
		remove_from_group("shock_target")
		_enter(St.SHATTER, 1.4)
		return
	# Struck mid-swing it keeps going; otherwise it's knocked back a step.
	if _state in [St.IDLE, St.RUN, St.RECOVER] and from_dir.x != 0.0:
		velocity.x = from_dir.x * 120.0


func _enter(state: St, time := 0.0) -> void:
	if state in [St.DASH_WINDUP, St.AIM]:
		Sfx.play("warn", -6.0, 0.0)  # its biggest blows ring a warning first
	_state = state
	if state not in [St.WAKE, St.SHATTER]:
		time *= _pace
	_timer = time
	_state_time = maxf(time, 0.001)


func _play(anim: String) -> void:
	if _anim != anim:
		_anim = anim
		_anim_time = 0.0


func _next_attack() -> String:
	var pattern: Array = PATTERN_HARD if hp <= max_hp / 2 else PATTERN
	var attack: String = pattern[_move % pattern.size()]
	_move += 1
	return attack


func _face(p: Vector2) -> void:
	if absf(p.x - global_position.x) > 4.0:
		_dir = 1 if p.x > global_position.x else -1


func _physics_process(delta: float) -> void:
	_time += delta
	_anim_time += delta
	_flash -= delta
	_timer -= delta
	var player := _player()
	var p := player.global_position if player else global_position
	var grounded := is_on_floor()
	if _state not in [St.ZIP, St.DASH]:
		velocity.y = minf(velocity.y + GRAVITY * delta, 500.0)
	match _state:
		St.DORMANT:
			_play("idle")
			velocity.x = 0.0
			if absf(p.x - global_position.x) < 160.0 and absf(p.y - global_position.y) < 80.0:
				engaged.emit()
				add_to_group("boss")
				add_to_group("shock_target")
				Sfx.play("roar", -6.0, 0.3)
				_enter(St.WAKE, 1.4)
		St.WAKE:
			_face(p)
			_play("point")
			if _timer <= 0.0:
				_enter(St.IDLE, 0.4)
		St.IDLE:
			_play("idle")
			_face(p)
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _timer <= 0.0 and grounded:
				match _next_attack():
					"mirror":
						_echo.clear()
						_mirror_until = _time + MIRROR_TIME
						_enter(St.MIRROR, MIRROR_TIME)
						Sfx.play("shock_charge", -10.0, 0.3)
					"reflections":
						_send_reflections(p)
						_enter(St.RECOVER, 1.0)
					"slash":
						_combo = 0
						_enter(St.RUN, 1.6)
					"dash":
						_enter(St.DASH_WINDUP, 0.45)
						Sfx.play("swing", -12.0, 0.0)
					"plunge":
						velocity = Vector2(clampf((p.x - global_position.x) * 1.6, -260.0, 260.0), JUMP)
						_play("jump")
						_enter(St.LEAP, 1.4)
					"spin":
						velocity = Vector2(0, JUMP * 0.9)
						_play("jump")
						_enter(St.LEAP, 0.35)
						_combo = -1  # (spin when the leap tops out)
					"shockline":
						_aim = Vector2(_dir, 0)
						_play("point")
						_enter(St.AIM, 0.55)
						Sfx.play("shock_charge", -6.0, 0.0)
		St.RUN:
			_play("run")
			_face(p)
			velocity.x = _dir * RUN / _pace
			if absf(p.x - global_position.x) < SLASH_REACH.x * 0.9 or _timer <= 0.0:
				velocity.x = 0.0
				_swing()
		St.SLASH:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if _timer <= 0.0:
				if _combo == 0 and absf(p.x - global_position.x) < SLASH_REACH.x * 1.3:
					_combo = 1
					_face(p)
					_swing()
				else:
					_enter(St.RECOVER, 0.5)
		St.DASH_WINDUP:
			_play("slide")
			_anim_time = 0.0
			velocity.x = 0.0
			_face(p)
			if _timer <= 0.0:
				_enter(St.DASH, 0.4)
				Sfx.play("slide", -4.0)
		St.DASH:
			_play("slide")
			velocity = Vector2(_dir * DASH, 0.0)
			_trail_point()
			if _timer <= 0.0 or is_on_wall():
				_enter(St.RECOVER, 0.5)
		St.LEAP:
			if _combo == -1 and _timer <= 0.0:
				_combo = 0
				_enter(St.SPIN, 0.35)
				velocity.y = -120.0
				Sfx.play("spin", -3.0)
			elif _combo != -1 and velocity.y > 0.0 and absf(p.x - global_position.x) < 14.0:
				# Over him: the blade straight down.
				velocity = Vector2(0, 460.0)
				_play("attack_down")
				_enter(St.PLUNGE, 1.0)
				Sfx.play("swing", -2.0)
			elif grounded and _timer < _state_time - 0.2:
				_enter(St.RECOVER, 0.4)
		St.PLUNGE:
			_trail_point()
			if grounded:
				Sfx.play("slam", -6.0)
				Effects.puff(get_parent(), position, COLOR_BODY, 8, 70.0)
				_enter(St.RECOVER, 0.6)
		St.SPIN:
			_play("spin")
			if _timer <= 0.0:
				_enter(St.RECOVER, 0.5)
		St.AIM:
			velocity.x = 0.0
			_face(p)
			_aim = Vector2(_dir, 0)
			if _timer <= 0.0:
				_enter(St.ZIP, 0.6)
				Sfx.play("shock_fire", -4.0)
		St.ZIP:
			velocity = _aim * ZIP
			_trail_point()
			if is_on_wall() or _timer <= 0.0:
				velocity = Vector2.ZERO
				_enter(St.RECOVER, 0.6)
		St.MIRROR:
			# Copying Storm's every move, a beat after him.
			_face(p)
			_play("idle")
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			for action in ["attack", "dash", "jump", "shockline"]:
				if Input.is_action_just_pressed(action):
					_echo.append([action, _time + MIRROR_DELAY])
			if not _echo.is_empty() and _time >= _echo[0][1]:
				var action: String = _echo.pop_front()[0]
				match action:
					"attack":
						_combo = 1
						_swing()
					"dash":
						velocity = Vector2(_dir * DASH, 0.0)
						_play("slide")
					"jump":
						if grounded:
							velocity.y = JUMP
					"shockline":
						_aim = Vector2(_dir, 0)
						_enter(St.ZIP, 0.4)
			if _state == St.MIRROR and _timer <= 0.0:
				_mirror_until = 0.0
				_enter(St.RECOVER, 0.5)
		St.DRINK:
			velocity.x = 0.0
			_play("idle")
			if _timer <= 0.0:
				hp = mini(max_hp, hp + DRINK_HEAL)
				Sfx.play("rest", -6.0, 0.0)
				_enter(St.RECOVER, 0.4)
		St.RECOVER:
			_play("idle")
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _timer <= 0.0:
				if _time < _mirror_until:
					_enter(St.MIRROR, _mirror_until - _time)  # back to copying him
				else:
					_enter(St.IDLE, 0.35)
		St.SHATTER:
			velocity = Vector2.ZERO
			if _timer <= 0.0 and not _done:
				_done = true
				Sfx.play("shatter", 0.0, 0.0)
				Effects.sparks(get_parent(), shock_point(), COLOR_GLOW, 30, 180.0)
				Effects.sparks(get_parent(), shock_point(), COLOR_HOT, 14, 120.0)
				Effects.puff(get_parent(), shock_point(), COLOR_BODY, 20, 100.0)
				for k in 22:
					var shard := GlassShard.new()
					shard.position = position + Vector2(randf_range(-6, 6), randf_range(-22, -2))
					shard.velocity = Vector2.from_angle(randf() * TAU) * randf_range(80, 260) + Vector2(0, -120)
					shard.spin = randf_range(-12, 12)
					shard.size = randf_range(2.5, 6.0)
					get_parent().add_child(shard)
				Game.defeated[boss_id] = true
				defeated.emit()
				visible = false
	if is_on_floor():
		_floor_y = global_position.y
	_ghost_time -= delta
	if _ghost_time <= 0.0 and _state not in [St.DORMANT, St.SHATTER]:
		_ghost_time = 0.09
		_trail.append({"pos": position, "at": _time, "anim": _anim, "frame": _frame(), "dir": _dir})
	move_and_slide()
	_update_boxes()
	_trail = _trail.filter(func(t: Dictionary) -> bool: return _time - t.at < 0.3)
	queue_redraw()


## Its reflections step out of the walls on either side and dash across at Storm's height.
func _send_reflections(p: Vector2) -> void:
	var room := get_parent()
	for side in [-1, 1]:
		var r := Reflection.new()
		r.boss = self
		r.speed = -side * 260.0
		r.position = Vector2(16.0 if side < 0 else room.size_px.x - 16.0, global_position.y)
		room.add_child(r)
	Sfx.play("shatter", -10.0, 0.4)


## Draws a reflection (for the Reflection nodes): its running frame, pale and see-through.
func draw_reflection(node: Node2D, facing: float) -> void:
	var tex: Texture2D = SHEETS["run"]
	var size := float(tex.get_height())
	var w := size / ART_SCALE
	var frame := int(_time * 14.0) % (tex.get_width() / int(size))
	node.draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	node.draw_texture_rect_region(tex, Rect2(-BODY_X / ART_SCALE, -w, w, w), Rect2(frame * size, 0, size, size),
		Color(0.8, 0.82, 1.0, 0.55))
	node.draw_set_transform(Vector2.ZERO)


func _swing() -> void:
	_play("attack" if _combo == 0 else "attack2")
	_enter(St.SLASH, 0.3)
	Sfx.play("swing", -3.0)


func _trail_point() -> void:
	if _trail.is_empty() or _time - _trail[-1].at > 0.04:
		_trail.append({"pos": position, "at": _time, "anim": _anim, "frame": _frame(), "dir": _dir})


func _update_boxes() -> void:
	var fighting := _state not in [St.DORMANT, St.WAKE, St.SHATTER]
	_body.collision_layer = LAYER_ENEMY if fighting else 0
	var live := false
	var shape: RectangleShape2D = _blade.get_child(0).shape
	if _state == St.SLASH and _timer > _state_time * 0.3:
		live = true
		shape.size = SLASH_REACH
		_blade.position = Vector2(_dir * (SLASH_REACH.x / 2.0 + 2.0), -BODY.y / 2.0)
	elif _state == St.PLUNGE:
		live = true
		shape.size = Vector2(16, 24)
		_blade.position = Vector2(0, 4)
	elif _state == St.SPIN:
		live = true
		var r := SPIN_RADIUS * clampf(1.0 - _timer / _state_time, 0.3, 1.0)
		shape.size = Vector2(r * 1.6, r * 1.6)
		_blade.position = Vector2(0, -BODY.y / 2.0)
	_blade.collision_layer = LAYER_ENEMY if live else 0


func _frame() -> int:
	var tex: Texture2D = SHEETS[_anim]
	var frames := tex.get_width() / tex.get_height()
	if _anim == "jump":
		return 4 if velocity.y < -60.0 else (6 if velocity.y < 80.0 else mini(8, frames - 1))
	var f := int(_anim_time * FPS[_anim])
	if _anim in ["idle", "run", "slide"]:
		return f % frames
	return mini(f, frames - 1)


func _draw_storm(at: Vector2, anim: String, frame: int, facing: int, color: Color, upside_down := false) -> void:
	var tex: Texture2D = SHEETS[anim]
	var size := float(tex.get_height())
	var w := size / ART_SCALE
	draw_set_transform(at, 0.0, Vector2(facing, -1.0 if upside_down else 1.0))
	draw_texture_rect_region(tex, Rect2(-BODY_X / ART_SCALE, -w, w, w), Rect2(frame * size, 0, size, size), color)
	draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	# Afterimages where it dashed and zipped.
	for t in _trail:
		var fade: float = 1.0 - (_time - t.at) / 0.3
		_draw_storm(t.pos - position, t.anim, t.frame, t.dir, Color(COLOR_GLOW, 0.25 * fade))
	if _state == St.DASH_WINDUP:
		var g := clampf(1.0 - _timer / _state_time, 0.0, 1.0)
		draw_circle(Vector2(0, -2), 6.0 + 8.0 * g, Color(COLOR_GLOW, 0.2 + 0.3 * g))
	if _state == St.AIM:
		var g := clampf(1.0 - _timer / _state_time, 0.0, 1.0)
		if fmod(_time, 0.1) < 0.06 or g > 0.8:
			draw_line(Vector2(0, -BODY.y / 2.0), Vector2(_dir * 400.0, -BODY.y / 2.0), Color(COLOR_GLOW, 0.2 + 0.5 * g), 1.0)
	if _state == St.SPIN:
		var r := SPIN_RADIUS * clampf(1.0 - _timer / _state_time, 0.3, 1.0)
		var fade := clampf(_timer / _state_time * 1.5, 0.0, 1.0)
		draw_arc(Vector2(0, -BODY.y / 2.0), r, 0.0, TAU, 40, Color(COLOR_GLOW, 0.35 * fade), 7.0)
		draw_arc(Vector2(0, -BODY.y / 2.0), r, 0.0, TAU, 40, Color(COLOR_HOT, 0.8 * fade), 2.0)
	if _state == St.SHATTER:
		# Cracking like glass before it goes.
		var g := clampf(1.0 - _timer / _state_time, 0.0, 1.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for k in int(2 + g * 8):
			var from := Vector2(rng.randf_range(-5, 5), rng.randf_range(-20, -2))
			draw_line(from, from + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4, 12) * g, COLOR_HOT, 1.0)
	var tint := Color(3, 3, 3) if _flash > 0.0 else COLOR_BODY
	if _state == St.DRINK:
		draw_circle(Vector2(6.0 * _dir, -12.0), 6.0 + 2.0 * sin(_time * 12.0), Color(0.6, 0.9, 1.0, 0.5))
	if _state == St.MIRROR and fmod(_time, 0.3) < 0.15:
		tint = Color(0.55, 0.45, 0.75)
	# The two of them reflected in the glass floor.
	_draw_storm(Vector2(0, 2.0 * (_floor_y - global_position.y)), _anim, _frame(), _dir, Color(COLOR_GLOW, 0.32), true)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.get("_sprite"):
		var sprite: AnimatedSprite2D = player._sprite
		var frames := sprite.sprite_frames
		if frames and frames.has_animation(sprite.animation):
			var ptex := frames.get_frame_texture(sprite.animation, sprite.frame)
			var at := player.global_position - global_position + Vector2(0, 2.0 * (_floor_y - player.global_position.y))
			var sz := Vector2(ptex.get_size()) / ART_SCALE
			draw_set_transform(at, 0.0, Vector2(-1.0 if sprite.flip_h else 1.0, -1.0))
			draw_texture_rect(ptex, Rect2(Vector2(-sz.x / 2.0, -sz.y), sz), false, Color(0.85, 0.85, 1.0, 0.3))
			draw_set_transform(Vector2.ZERO)
	# A pale edge around the dark body, then the body.
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		_draw_storm(o, _anim, _frame(), _dir, Color(0.9, 0.82, 1.0, 0.7))
	_draw_storm(Vector2.ZERO, _anim, _frame(), _dir, tint)
