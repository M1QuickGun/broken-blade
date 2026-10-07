extends SceneTree
## A quick check that the game still holds together: builds every room, then lets every boss
## and elite fight a stand-in Storm for a while (and finishes each off), and reports what
## each one did. Saving is off in headless runs, so the player's saves are never touched.
##
##     godot --headless --path . -s tools/smoke_test.gd
##
## Watch the output for SCRIPT ERROR lines; the summary at the end says what ran.

const FIGHT_SECONDS := 12


class StandIn extends Node2D:
	var facing := 1
	var velocity := Vector2.ZERO

	func _ready() -> void:
		add_to_group("player")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var Room = load("res://scripts/room.gd")
	var Rooms = load("res://scripts/rooms.gd")
	var built := 0
	for name in Rooms.LAYOUTS:
		var room: Node2D = Room.new()
		root.add_child(room)
		room.build(name)
		room.free()
		built += 1
	print("rooms built: %d / %d" % [built, Rooms.LAYOUTS.size()])

	var fights := []
	for name in Rooms.BOSSES:
		fights.append(name)
	for name in Rooms.ELITES:
		fights.append(name)
	for name in fights:
		var room: Node2D = Room.new()
		root.add_child(room)
		room.build(name)
		var foe: Node2D = null
		for c in room.get_children():
			if c.has_signal("defeated") or (c.get("elite") is String and c.elite != ""):
				foe = c
		if foe == null:
			print("%-16s no foe found" % name)
			room.free()
			continue
		var stand_in := StandIn.new()
		stand_in.position = foe.position + Vector2(-70, 0)
		room.add_child(stand_in)
		var states := {}
		for i in 60 * FIGHT_SECONDS:
			await physics_frame
			if not is_instance_valid(foe):
				break
			stand_in.position.x = foe.position.x - 60.0 + sin(i * 0.02) * 50.0
			states[foe.get("_state")] = true
		var finished := false
		if is_instance_valid(foe):
			foe.hp = 1
			foe.take_hit(2, Vector2.RIGHT)
			finished = foe.get("hp") <= 0 or not is_instance_valid(foe)
		print("%-16s %d states seen, finished off: %s" % [name, states.size(), finished])
		room.free()
	print("smoke test done")
	quit()
