extends "res://tests/combat/projectiles.gd"
## Real physics contacts, using the existing damage receiver fixture.

func run() -> void:
	var saw := load("res://scenes/weapons/chainsaw.tscn").instantiate() as Weapon
	root.add_child(saw)
	var front := receiver(Vector3(0, 0.75, 1), DamageContext.Team.ENEMY)
	var behind := receiver(Vector3(0, 0.75, -1), DamageContext.Team.ENEMY)
	var far := receiver(Vector3(0, 0.75, 3), DamageContext.Team.ENEMY)
	var ally := receiver(Vector3(0.2, 0.75, 1), DamageContext.Team.PLAYER)
	saw.wielder = ally
	await frames(2)
	check(saw.try_fire(Vector3.BACK, Vector3.ZERO), "chainsaw activates")
	check(front.hits == 1 and front.health == 84, "front contact takes one cut")
	check(behind.hits == 0 and far.hits == 0 and ally.hits == 0, "range, facing and allies respected")
	check(front.last_context.get_instigator() == ally, "kill attribution retained")
	check(not saw.try_fire(Vector3.BACK, Vector3.ZERO), "cadence prevents duplicate cuts")
	saw.advance(0.11)
	saw.damage_multiplier = 2.0
	saw.try_fire(Vector3.BACK, Vector3.ZERO)
	check(front.hits == 2 and front.health == 52, "held attack repeats and applies damage perks")
	check(not saw.start_reload() and saw.magazine.ammo == saw.magazine.capacity, "no ammo consumption or reload")
	check(not saw.presentation.flash.visible, "no firearm flash")
	var wall := StaticBody3D.new()
	wall.collision_layer = GameRules.WALL_LAYER
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 2, 0.1)
	collision.shape = shape
	wall.add_child(collision)
	root.add_child(wall)
	wall.position = Vector3(0, 0.75, 0.5)
	await frames(2)
	saw.advance(0.11)
	saw.try_fire(Vector3.BACK, Vector3.ZERO)
	check(front.hits == 2, "walls block contact damage")
	paused = true
	saw.advance(0.11)
	check(not saw.try_fire(Vector3.BACK, Vector3.ZERO), "pause blocks attacks")
	paused = false
	for node in [saw, wall, front, behind, far, ally]:
		node.queue_free()
	await process_frame
	await process_frame
	print("CHAINSAW %s: %d checks" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)
