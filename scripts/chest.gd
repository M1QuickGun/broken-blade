extends Area2D
## The chest at the end of a trial: touch it and it bursts open, spilling its crowns (and, in
## the hardest trials, a mask of the old guard). Once open it stays open. The node's origin
## is at its base.

signal opened(text: String)

const Coin := preload("res://scripts/coin.gd")
const COLOR_WOOD := Color("5a3d28")
const COLOR_WOOD_DARK := Color("3a2618")
const COLOR_IRON := Color("8a8f9c")
const COLOR_GOLD := Color(0.95, 0.78, 0.36)

## Set by the room: which trial this is (Rooms.TRIALS).
var trial := ""
var _open := false
var _time := 0.0
var _lid := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 14)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -7)
	add_child(col)
	_open = Game.collected.has(_id())
	_lid = 1.0 if _open else 0.0
	body_entered.connect(_on_body_entered)


func _id() -> String:
	return "chest:" + trial


func _on_body_entered(_body: Node2D) -> void:
	if _open:
		return
	_open = true
	var info: Dictionary = load("res://scripts/rooms.gd").TRIALS.get(trial, {})
	Game.collected[_id()] = true
	Sfx.play("pickup", -2.0, 0.0)
	Sfx.play("burst", -10.0, 0.0)
	Coin.drop(get_parent(), position + Vector2(0, -12), info.get("crowns", 100))
	if info.get("mask", false):
		Game.add_mask("trial:" + trial)
	Game.save_game()
	opened.emit("%s: done.%s" % [info.get("title", "The trial"), " A mask of the old guard was inside." if info.get("mask", false) else ""])


func _process(delta: float) -> void:
	_time += delta
	if _open:
		_lid = move_toward(_lid, 1.0, delta * 4.0)
	queue_redraw()


func _draw() -> void:
	if not _open:
		# A glint, so it reads as the prize.
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		draw_circle(Vector2(0, -8), 12.0, Color(COLOR_GOLD, 0.08 + 0.08 * pulse))
	draw_rect(Rect2(-9, -10, 18, 10), COLOR_WOOD)
	draw_rect(Rect2(-9, -2, 18, 2), COLOR_WOOD_DARK)
	draw_rect(Rect2(-8, -10, 2, 10), COLOR_IRON)
	draw_rect(Rect2(6, -10, 2, 10), COLOR_IRON)
	if _lid > 0.0:
		# The lid swung back, gold glinting inside.
		draw_rect(Rect2(-8, -11, 16, 2), COLOR_GOLD)
		draw_colored_polygon(PackedVector2Array([Vector2(-9, -10), Vector2(9, -10), Vector2(9, -10 - 7.0 * _lid),
			Vector2(-9, -10 - 7.0 * _lid)]), COLOR_WOOD_DARK)
	else:
		draw_rect(Rect2(-9, -15, 18, 5), COLOR_WOOD)
		draw_rect(Rect2(-9, -15, 18, 1), COLOR_WOOD_DARK.lightened(0.2))
		draw_rect(Rect2(-1.5, -12, 3, 4), COLOR_GOLD)
