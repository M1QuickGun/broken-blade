extends Node2D
## A crown: a coin of the old kingdom. Enemies drop them, pots hold them, bosses leave a
## pile. They spill out, bounce and settle on the ground; when Storm comes near they fly to
## him and are his. Gathered with Coin.drop(parent, at, count).

const LAYER_WORLD := 1
const GRAVITY := 700.0
## How near Storm must be for coins to come to him, and how fast they fly.
const PULL := 48.0
const FLY := 260.0
const LIFE := 30.0
const COLOR_GOLD := Color(0.95, 0.78, 0.36)
const COLOR_GOLD_DARK := Color(0.62, 0.44, 0.18)
const COLOR_GOLD_SHINE := Color(1.0, 0.96, 0.8)

## How many crowns this one is worth (big piles drop some heavier coins).
var value := 1
var velocity := Vector2.ZERO

var _time := 0.0
var _resting := false
var _flying := false


## Spills `count` crowns' worth of coins at `at` (in `parent`'s coordinates).
static func drop(parent: Node, at: Vector2, count: int) -> void:
	var script: Script = load("res://scripts/coin.gd")
	while count > 0:
		var coin: Node2D = script.new()
		coin.value = 5 if count >= 15 else 1
		count -= coin.value
		coin.position = at + Vector2(randf_range(-4, 4), randf_range(-4, 0))
		coin.velocity = Vector2(randf_range(-80, 80), randf_range(-220, -120))
		parent.add_child.call_deferred(coin)


func _physics_process(delta: float) -> void:
	_time += delta
	if _time > LIFE:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and _time > 0.35:
		var to := player.global_position + Vector2(0, -12) - global_position
		if _flying or to.length() < PULL:
			_flying = true
			if to.length() < 8.0:
				Game.add_crowns(value)
				Sfx.play("pickup", -16.0, 0.3)
				queue_free()
				return
			global_position += to.normalized() * minf(FLY * delta, to.length())
			queue_redraw()
			return
	if not _resting:
		velocity.y += GRAVITY * delta
		var step := velocity * delta
		var space := get_world_2d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, global_position + step + Vector2(0, 2), LAYER_WORLD))
		if hit:
			global_position = hit.position - Vector2(0, 2) - step.normalized() * 0.5
			if hit.normal.y < -0.5:
				# Off the floor: a little bounce, then still.
				velocity = Vector2(velocity.x * 0.4, -velocity.y * 0.3)
				if absf(velocity.y) < 40.0:
					_resting = true
			else:
				velocity.x = -velocity.x * 0.5
		else:
			global_position += step
	queue_redraw()


func _draw() -> void:
	# A coin spinning: its width swings as it turns; a glint now and then.
	var turn := absf(cos(_time * 5.0 + get_instance_id()))
	var r := 2.5 if value == 1 else 3.5
	var fade := clampf((LIFE - _time) / 3.0, 0.0, 1.0)
	if _time > LIFE - 3.0 and fmod(_time, 0.2) < 0.1:
		return  # blinking out
	draw_rect(Rect2(-r * turn - 0.5, -r, (r * turn + 0.5) * 2.0, r * 2.0), Color(COLOR_GOLD_DARK, fade))
	draw_rect(Rect2(-r * turn, -r + 0.5, r * turn * 2.0, r * 2.0 - 1.0), Color(COLOR_GOLD, fade))
	if fmod(_time + get_instance_id() * 0.13, 1.6) < 0.12:
		draw_rect(Rect2(-0.5, -r - 1.5, 1, 1), COLOR_GOLD_SHINE)
