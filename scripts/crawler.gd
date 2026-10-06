extends CharacterBody2D
## The ground enemies. All of them walk the floor, turning at walls and ledges, and hurt to
## touch; each kind has its own trick:
## - "beetle" (the Foothills): a mossy beetle as big as Storm. It patrols, and when it spots
##   him ahead it braces, then charges; running into a wall stuns it.
## - "thrall" (the Frozen village): a villager the cold turned into a frozen husk. It shambles
##   after Storm when he's near and lunges when he's close.
## - "hatchling": the Guardian Centipede's young, dropped into its fight. Just crawls.
## - "grub" (the Foothills): a centipede larva that hides in the earth. When Storm comes near
##   the ground rumbles; it bursts out at him, crawls about for a while, then burrows again.
## - "knight" (the Last Stand, on the summit): a hollow knight, the empty armor of the royal
##   army, scorched down one side and storm-struck down the other. It advances behind its
##   shield (blows from the front glance off it), and close in it raises its sword and brings
##   it down hard; then it's slow to recover: hit it then, or from behind, or from above.
## - "toad" (the Foothills): a moss toad. It sits, then hops at Storm in arcs.
## - "hound" (the Frozen village): a frost hound. It runs him down, crouches, and leaps.
## - "husk" (the Fire slopes): a cinder husk. It shambles after him; close in its embers flare
##   and it bursts in fire a moment later (kill it first, or get clear).
## - "conductor" (the Lightning peaks): an iron walker with a lightning rod. Close in it
##   charges up, crackling, and sends shockwaves both ways along the floor: jump them.
## - "archer" (the Last Stand): a hollow archer. It keeps its distance, draws, and looses
##   arrows at him (the blade can cut them down).
## The node's origin is at its feet.

const Effects := preload("res://scripts/effects.gd")
const Projectile := preload("res://scripts/projectile.gd")
const LAYER_WORLD := 1
const LAYER_ENEMY := 4

const GRAVITY := 900.0
const MAX_FALL := 400.0
const KNOCKBACK_SPEED := 150.0
const KNOCKBACK_TIME := 0.15
const COLOR_DIRT := Color("3b352b")

## Per kind: body size (world units), drawn size, health, walking speed, sheet, frame size
## (art pixels) and animation speed. Sheets are horizontal strips facing right. "sink" sets
## art with thin legs a little into the ground so it doesn't look like it's hovering.
const KINDS := {
	"beetle": {"size": Vector2(28, 22), "draw": 36.0, "hp": 4, "speed": 28.0,
		"tex": preload("res://art/enemies/beetle.png"), "frame": 64, "fps": 7.0},
	"thrall": {"size": Vector2(14, 28), "draw": 36.0, "hp": 3, "speed": 18.0,
		"tex": preload("res://art/enemies/thrall.png"), "frame": 64, "fps": 6.0},
	"hatchling": {"size": Vector2(32, 24), "draw": 32.0, "hp": 3, "speed": 35.0, "sink": 4.0,
		"tex": preload("res://art/enemies/hatchling.png"), "frame": 32, "fps": 9.0},
	"grub": {"size": Vector2(28, 20), "draw": 28.0, "hp": 2, "speed": 45.0, "sink": 4.0,
		"tex": preload("res://art/enemies/hatchling.png"), "frame": 32, "fps": 12.0},
	"toad": {"size": Vector2(20, 16), "draw": 34.0, "hp": 2, "speed": 0.0,
		"tex": preload("res://art/enemies/toad.png"), "frame": 64, "fps": 10.0},
	"hound": {"size": Vector2(26, 18), "draw": 40.0, "hp": 3, "speed": 26.0,
		"tex": preload("res://art/enemies/hound.png"), "frame": 64, "fps": 9.0},
	"husk": {"size": Vector2(14, 28), "draw": 38.0, "hp": 2, "speed": 20.0,
		"tex": preload("res://art/enemies/husk.png"), "frame": 64, "fps": 6.0},
	"conductor": {"size": Vector2(22, 26), "draw": 42.0, "hp": 4, "speed": 16.0,
		"tex": preload("res://art/enemies/conductor.png"), "frame": 64, "fps": 6.0},
	"archer": {"size": Vector2(14, 30), "draw": 46.0, "hp": 3, "speed": 20.0,
		"tex": preload("res://art/enemies/archer.png"), "frame": 64, "fps": 6.0,
		"attack": preload("res://art/enemies/archer_attack.png")},
	"knight": {"size": Vector2(16, 30), "draw": 46.0, "hp": 5, "speed": 24.0,
		"tex": preload("res://art/enemies/knight.png"), "frame": 64, "fps": 6.0,
		"attack": preload("res://art/enemies/knight_attack.png")},
}
## The knight's sword: how far it reaches ahead, and its timing.
const KNIGHT_REACH := Vector2(34, 30)
const KNIGHT_WINDUP := 0.6
const KNIGHT_SWING := 0.2
const KNIGHT_RECOVER := 0.8

enum St { WALK, WINDUP, CHARGE, STUN, BURIED, RUMBLE, LEAP, DIG }

var kind := "beetle"
## How far it may walk (set by the room): it turns back before reaching a door.
var min_x := -INF
var max_x := INF
var hp := 3
var dir := -1

var _state := St.WALK
var _timer := 0.0
var _knockback := 0.0
var _flash := 0.0
var _anim := 0.0
var _info: Dictionary
var _cooldown := 0.0
## The knight's sword, live only as it comes down.
var _blade: Blade


## A knight's sword stroke: hurts to touch, nothing to strike.
class Blade extends Area2D:
	func take_hit(_damage: int, _from_dir: Vector2) -> void:
		pass


func _ready() -> void:
	_info = KINDS[kind]
	hp = _info.hp
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD
	var shape := RectangleShape2D.new()
	shape.size = _info.size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -_info.size.y / 2)
	add_child(col)
	if kind == "grub":
		_bury()
	else:
		add_to_group("shock_target")
	if kind == "knight":
		_blade = Blade.new()
		_blade.collision_layer = 0
		_blade.collision_mask = 0
		_blade.monitoring = false
		var blade_shape := RectangleShape2D.new()
		blade_shape.size = KNIGHT_REACH
		var blade_col := CollisionShape2D.new()
		blade_col.shape = blade_shape
		_blade.add_child(blade_col)
		add_child(_blade)


## Where the shockline latches on.
func shock_point() -> Vector2:
	return global_position + Vector2(0, -_info.size.y / 2)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_flash -= delta
	_anim += delta
	_knockback -= delta
	_timer -= delta
	_cooldown -= delta
	if _state != St.BURIED and _state != St.RUMBLE:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	var player := _player()
	var to := player.global_position - global_position if player else Vector2(9999, 0)
	if _knockback > 0.0 and _state != St.CHARGE:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	else:
		match kind:
			"beetle":
				_beetle(to)
			"thrall":
				_thrall(to)
			"grub":
				_grub(to)
			"knight":
				_knight(to)
			"toad":
				_toad(to)
			"hound":
				_hound(to)
			"husk":
				_husk(to)
			"conductor":
				_conductor(to)
			"archer":
				_archer(to)
			_:
				_patrol(_info.speed)
	move_and_slide()
	queue_redraw()


func _patrol(speed: float) -> void:
	if is_on_floor() and (_facing_wall() or not _ground_ahead() or _at_limit()):
		dir = -dir
	velocity.x = dir * speed


## Patrols; spotting Storm ahead, it braces, then charges until it hits something.
func _beetle(to: Vector2) -> void:
	match _state:
		St.WALK:
			_patrol(_info.speed)
			if _cooldown <= 0.0 and absf(to.x) < 110.0 and absf(to.y) < 24.0 and signf(to.x) == dir:
				_state = St.WINDUP
				_timer = 0.55
		St.WINDUP:
			velocity.x = -dir * 8.0  # rearing back
			if _timer <= 0.0:
				_state = St.CHARGE
				_timer = 1.0
		St.CHARGE:
			velocity.x = dir * 165.0
			if _facing_wall() or (is_on_floor() and not _ground_ahead()) or _at_limit() or _timer <= 0.0:
				_state = St.STUN
				_timer = 0.8 if _facing_wall() else 0.4
				velocity.x = 0.0
		St.STUN:
			velocity.x = 0.0
			if _timer <= 0.0:
				_state = St.WALK
				_cooldown = 1.0


## Shambles after Storm when he's near; lunges when he's close.
func _thrall(to: Vector2) -> void:
	var near := absf(to.x) < 130.0 and absf(to.y) < 40.0
	match _state:
		St.WALK:
			if near:
				dir = 1 if to.x > 0.0 else -1
				var blocked := is_on_floor() and (_facing_wall() or not _ground_ahead() or _at_limit())
				velocity.x = 0.0 if blocked else dir * 40.0
				if _cooldown <= 0.0 and absf(to.x) < 34.0:
					_state = St.WINDUP
					_timer = 0.35
			else:
				_patrol(_info.speed)
		St.WINDUP:
			velocity.x = 0.0
			if _timer <= 0.0:
				_state = St.CHARGE
				velocity = Vector2(dir * 120.0, -120.0)
				_timer = 0.4
		St.CHARGE:
			if _timer <= 0.0 and is_on_floor():
				_state = St.WALK
				_cooldown = 1.2


## Advances on Storm behind its shield; close in, raises its sword and brings it down.
func _knight(to: Vector2) -> void:
	var near := absf(to.x) < 170.0 and absf(to.y) < 50.0
	match _state:
		St.WALK:
			if near:
				dir = 1 if to.x > 0.0 else -1
				var blocked := is_on_floor() and (_facing_wall() or not _ground_ahead() or _at_limit())
				velocity.x = 0.0 if blocked or absf(to.x) < 26.0 else dir * _info.speed * 1.4
				if _cooldown <= 0.0 and absf(to.x) < 44.0:
					_state = St.WINDUP
					_timer = KNIGHT_WINDUP
					Sfx.play("swing", -10.0, 0.0)
			else:
				_patrol(_info.speed)
		St.WINDUP:
			velocity.x = 0.0
			if _timer <= 0.0:
				_state = St.CHARGE
				_timer = KNIGHT_SWING
				velocity.x = dir * 60.0
				Sfx.play("swing", -2.0)
		St.CHARGE:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * get_physics_process_delta_time())
			if _timer <= 0.0:
				_state = St.STUN
				_timer = KNIGHT_RECOVER
				Sfx.play("slam", -12.0)
		St.STUN:
			velocity.x = 0.0
			if _timer <= 0.0:
				_state = St.WALK
				_cooldown = 0.9
	if _blade:
		var swinging := _state == St.CHARGE
		_blade.collision_layer = LAYER_ENEMY if swinging else 0
		_blade.position = Vector2(dir * (_info.size.x / 2.0 + KNIGHT_REACH.x / 2.0 - 4.0), -_info.size.y / 2.0)


## Sits; now and then hops at Storm in an arc.
func _toad(to: Vector2) -> void:
	var near := absf(to.x) < 170.0 and absf(to.y) < 60.0
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * get_physics_process_delta_time())
		if near:
			dir = 1 if to.x > 0.0 else -1
		if _cooldown <= 0.0:
			_cooldown = randf_range(0.9, 1.4)
			var reach := clampf(absf(to.x) * 1.4, 60.0, 130.0) if near else 50.0
			if not near:
				dir = -dir if (_facing_wall() or _at_limit()) else dir
			velocity = Vector2(dir * reach, -250.0)
			Sfx.play("jump", -14.0, 0.3)


## Runs Storm down when he's near; close in, crouches, and leaps at him.
func _hound(to: Vector2) -> void:
	var near := absf(to.x) < 200.0 and absf(to.y) < 50.0
	match _state:
		St.WALK:
			if near:
				dir = 1 if to.x > 0.0 else -1
				var blocked := is_on_floor() and (_facing_wall() or not _ground_ahead() or _at_limit())
				velocity.x = 0.0 if blocked else dir * 120.0
				if _cooldown <= 0.0 and absf(to.x) < 70.0 and is_on_floor():
					_state = St.WINDUP
					_timer = 0.25
			else:
				_patrol(_info.speed)
		St.WINDUP:
			velocity.x = 0.0
			if _timer <= 0.0:
				_state = St.LEAP
				velocity = Vector2(dir * 190.0, -210.0)
				Sfx.play("swing", -10.0, 0.2)
		St.LEAP:
			if is_on_floor() and velocity.y >= 0.0:
				_state = St.WALK
				_cooldown = 1.2


## Shambles after Storm; close in, its embers flare and it bursts.
func _husk(to: Vector2) -> void:
	var near := absf(to.x) < 150.0 and absf(to.y) < 40.0
	match _state:
		St.WALK:
			if near:
				dir = 1 if to.x > 0.0 else -1
				var blocked := is_on_floor() and (_facing_wall() or not _ground_ahead() or _at_limit())
				velocity.x = 0.0 if blocked else dir * 34.0
				if absf(to.x) < 30.0:
					_state = St.WINDUP
					_timer = 0.9
					Sfx.play("crackle", -6.0)
			else:
				_patrol(_info.speed)
		St.WINDUP:
			velocity.x = 0.0
			if fmod(_anim, 0.1) < get_physics_process_delta_time():
				Effects.sparks(get_parent(), global_position + Vector2(randf_range(-6, 6), -18), Color(1, 0.55, 0.2), 2, 60.0)
			if _timer <= 0.0:
				_burst()


## Bursting in a ball of fire that hurts all around it, and gone.
func _burst() -> void:
	var blast := Projectile.new()
	blast.kind = "burst"
	blast.life = 0.3
	blast.position = global_position + Vector2(0, -12)
	get_parent().add_child(blast)
	Sfx.play("burst", -4.0)
	Effects.sparks(get_parent(), global_position + Vector2(0, -12), Color(1, 0.55, 0.2), 16, 160.0)
	queue_free()


## Close in, charges up crackling and sends shockwaves both ways along the floor.
func _conductor(to: Vector2) -> void:
	var near := absf(to.x) < 120.0 and absf(to.y) < 50.0
	match _state:
		St.WALK:
			_patrol(_info.speed)
			if near and _cooldown <= 0.0 and is_on_floor():
				dir = 1 if to.x > 0.0 else -1
				_state = St.WINDUP
				_timer = 0.8
				Sfx.play("shock_charge", -6.0)
		St.WINDUP:
			velocity.x = 0.0
			if fmod(_anim, 0.06) < get_physics_process_delta_time():
				Effects.sparks(get_parent(), global_position + Vector2(randf_range(-8, 8), -_info.size.y - 6), Color(0.85, 0.75, 1.0), 1, 70.0)
			if _timer <= 0.0:
				Sfx.play("zap", -4.0)
				for side in [-1, 1]:
					var wave := Projectile.new()
					wave.kind = "spark_wave"
					wave.velocity = Vector2(side * 170.0, 0)
					wave.life = 2.5
					wave.position = global_position + Vector2(side * 14.0, 0)
					get_parent().add_child(wave)
				_state = St.STUN
				_timer = 0.9
		St.STUN:
			velocity.x = 0.0
			if _timer <= 0.0:
				_state = St.WALK
				_cooldown = 1.8


## Keeps its distance; draws and looses arrows at Storm.
func _archer(to: Vector2) -> void:
	var near := absf(to.x) < 280.0 and absf(to.y) < 120.0
	match _state:
		St.WALK:
			if near:
				dir = 1 if to.x > 0.0 else -1
				# Backing off if he's close.
				var away := -dir
				var can_back := not (is_on_floor() and (_at_limit_dir(away) or not _ground_at(away)))
				velocity.x = away * 36.0 if absf(to.x) < 110.0 and can_back else 0.0
				if _cooldown <= 0.0:
					_state = St.WINDUP
					_timer = 0.8
			else:
				_patrol(_info.speed)
		St.WINDUP:
			velocity.x = 0.0
			dir = 1 if to.x > 0.0 else -1
			if _timer <= 0.0:
				var from := global_position + Vector2(dir * 10.0, -_info.size.y * 0.6)
				var aim := (global_position + to - from).normalized()
				var arrow := Projectile.new()
				arrow.kind = "arrow"
				arrow.velocity = aim * 240.0
				arrow.fall_accel = 60.0
				arrow.life = 2.5
				arrow.position = from
				get_parent().add_child(arrow)
				Sfx.play("swing", -6.0, 0.2)
				_state = St.STUN
				_timer = 0.5
		St.STUN:
			velocity.x = 0.0
			if _timer <= 0.0:
				_state = St.WALK
				_cooldown = 1.6


func _at_limit_dir(d: int) -> bool:
	return (d < 0 and global_position.x <= min_x) or (d > 0 and global_position.x >= max_x)


func _ground_at(d: int) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position + Vector2(d * (_info.size.x / 2 + 2), 4)
	q.collision_mask = LAYER_WORLD
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


## Waits buried; rumbles when Storm comes near, bursts out at him, crawls, burrows again.
func _grub(to: Vector2) -> void:
	match _state:
		St.BURIED:
			velocity = Vector2.ZERO
			if _cooldown <= 0.0 and absf(to.x) < 80.0 and absf(to.y) < 40.0:
				_state = St.RUMBLE
				_timer = 0.7
		St.RUMBLE:
			velocity = Vector2.ZERO
			if fmod(_anim, 0.08) < get_physics_process_delta_time():
				_spray()
			if _timer <= 0.0:
				dir = 1 if to.x > 0.0 else -1
				collision_layer = LAYER_ENEMY
				add_to_group("shock_target")
				for i in 3:
					_spray()
				velocity = Vector2(dir * 90.0, -260.0)
				_state = St.LEAP
				Sfx.play("burst", -10.0)
		St.LEAP:
			if is_on_floor() and velocity.y >= 0.0:
				_state = St.WALK
				_timer = 2.5
		St.WALK:
			_patrol(_info.speed)
			if _timer <= 0.0 and is_on_floor():
				_state = St.DIG
				_timer = 0.5
				velocity.x = 0.0
		St.DIG:
			velocity.x = 0.0
			if fmod(_anim, 0.1) < get_physics_process_delta_time():
				_spray()
			if _timer <= 0.0:
				_bury()


func _bury() -> void:
	_state = St.BURIED
	collision_layer = 0
	remove_from_group("shock_target")
	_cooldown = 1.5


func _spray() -> void:
	var room := get_parent()
	if room and room.has_method("_spawn_debris"):
		room._spawn_debris(global_position + Vector2(randf_range(-8, 8), -2), COLOR_DIRT)


func take_hit(damage: int, from_dir: Vector2) -> void:
	if _state == St.BURIED or _state == St.RUMBLE:
		return
	if kind == "knight" and _state == St.WALK and from_dir.x * dir < 0.0:
		# Struck from the front while it advances: the blow glances off its shield.
		Sfx.play("hit", -8.0, 0.0)
		Sfx.play("shatter", -18.0, 0.3)
		Effects.sparks(get_parent(), global_position + Vector2(dir * 10.0, -_info.size.y / 2), Color(1, 1, 0.9), 6, 120.0)
		_flash = 0.05
		return
	hp -= damage
	_flash = 0.1
	var middle := global_position + Vector2(0, -_info.size.y / 2)
	Sfx.play("hit", -4.0)
	Effects.sparks(get_parent(), middle, Color(1, 0.95, 0.8))
	if hp <= 0:
		Sfx.play("enemy_die", -4.0)
		var dust := Color(0.45, 0.5, 0.4)
		if kind == "thrall":
			dust = Color(0.75, 0.9, 1.0)
		elif kind == "knight" or kind == "archer" or kind == "conductor":
			dust = Color(0.5, 0.5, 0.55)
		elif kind == "husk":
			dust = Color(0.3, 0.25, 0.22)
		elif kind == "hound":
			dust = Color(0.75, 0.9, 1.0)
		Effects.puff(get_parent(), middle, dust)
		queue_free()
		return
	if from_dir.x != 0.0 and _state != St.CHARGE:
		velocity.x = from_dir.x * KNOCKBACK_SPEED
		_knockback = KNOCKBACK_TIME


func _at_limit() -> bool:
	return (dir < 0 and global_position.x <= min_x) or (dir > 0 and global_position.x >= max_x)


func _facing_wall() -> bool:
	return is_on_wall() and signf(get_wall_normal().x) == -dir


func _ground_ahead() -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position + Vector2(dir * (_info.size.x / 2 + 2), 4)
	q.collision_mask = LAYER_WORLD
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


func _draw() -> void:
	if _state == St.BURIED:
		return
	if _state == St.RUMBLE or _state == St.DIG:
		# A swelling mound of earth where it's about to come out (or going back in).
		var grow := clampf(1.0 - _timer / 0.7, 0.2, 1.0) if _state == St.RUMBLE else clampf(_timer / 0.5, 0.0, 1.0)
		var pts := PackedVector2Array()
		for i in 9:
			var a := PI * i / 8.0
			pts.append(Vector2(-cos(a) * (6.0 + 8.0 * grow) + randf_range(-0.5, 0.5), -sin(a) * (2.0 + 4.0 * grow)))
		draw_colored_polygon(pts, COLOR_DIRT)
		if _state == St.RUMBLE:
			return
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	if _state == St.WINDUP and fmod(_anim, 0.16) < 0.08:
		tint = Color(1.5, 1.1, 0.9)
	var tex: Texture2D = _info.tex
	var frame_px: int = _info.frame
	var frames := tex.get_width() / frame_px
	var fps: float = _info.fps * (2.0 if _state == St.CHARGE else 0.0 if _state == St.STUN else 1.0)
	var frame := int(_anim * fps) % frames
	var stretch := Vector2.ONE
	if kind == "toad" and not is_on_floor():
		# Stretched out long through its hop.
		frame = 0
		stretch = Vector2(1.15, 0.9) if velocity.y < 0.0 else Vector2(0.95, 1.08)
	if kind == "husk" and _state == St.WINDUP:
		# The embers flaring faster and faster before it bursts.
		tint = Color(2.0, 1.2, 0.6) if fmod(_anim, maxf(0.05, _timer * 0.25)) < maxf(0.025, _timer * 0.12) else tint
	if kind == "conductor" and _state == St.WINDUP:
		tint = Color(1.6, 1.4, 2.0) if fmod(_anim, 0.1) < 0.05 else tint
	if kind == "archer" and _state in [St.WINDUP, St.STUN]:
		tex = _info.attack
		frames = tex.get_width() / frame_px
		frame = mini(int((1.0 - _timer / 0.8) * (frames - 1)), frames - 2) if _state == St.WINDUP else frames - 1
	if kind == "knight" and _state in [St.WINDUP, St.CHARGE, St.STUN]:
		# Raising the sword through the wind-up, bringing it down, then holding there.
		tex = _info.attack
		frames = tex.get_width() / frame_px
		var half := frames / 2
		if _state == St.WINDUP:
			frame = mini(int((1.0 - _timer / KNIGHT_WINDUP) * half), half - 1)
		elif _state == St.CHARGE:
			frame = half + mini(int((1.0 - _timer / KNIGHT_SWING) * (frames - half)), frames - half - 1)
		else:
			frame = frames - 1
	var side: float = _info.draw
	var shake := Vector2(randf_range(-1, 1), 0) if _state == St.WINDUP else Vector2.ZERO
	shake.y += _info.get("sink", 0.0)
	draw_set_transform(shake, 0.0, Vector2(1 if dir > 0 else -1, 1) * stretch)
	draw_texture_rect_region(tex, Rect2(-side / 2.0, -side, side, side),
		Rect2(frame * frame_px, 0, frame_px, frame_px), tint)
	draw_set_transform(Vector2.ZERO)
