extends SceneTree
## Regression for authored forward axis, scene variants and independent components.

class DetourNavigation extends HordeNavigation:
	func get_direction(_from: Vector3, _to: Vector3) -> Vector3:
		return Vector3.BACK


var checks: int = 0
var failures: int = 0
var actors: Array[Zombie] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("ENEMIES: " + description)


func face_direction(visuals: ZombieVisuals) -> Vector3:
	var nose := visuals._model.find_child("Nose | stub", true, false) as Node3D
	var skull := visuals._model.find_child("Head | broad square skull", true, false) as Node3D
	var direction: Vector3 = nose.global_position - skull.global_position
	direction.y = 0.0
	return direction.normalized()


func run() -> void:
	for kind in ["walker", "runner", "brute", "spitter", "boss"]:
		var packed := load("res://scenes/enemies/%s.tscn" % kind) as PackedScene
		var enemy := packed.instantiate() as Zombie
		enemy.configure_wave(3)
		root.add_child(enemy)
		enemy.set_physics_process(false)
		actors.append(enemy)
		check(enemy.kind == kind and is_equal_approx(enemy.max_health, enemy.base_health * 1.21),
			"variant and wave scaling come from its authored scene")
		check(enemy.visuals._model.rotation.is_equal_approx(Vector3.ZERO),
			"imported model has no compensating 180-degree rotation")
		check(enemy.get_node("CollisionShape3D").shape.height >= 2.14 * enemy.visual_scale,
			"authored body scale keeps head inside hit capsule")
		var animation: AnimationPlayer = enemy.visuals._animation
		animation.play("Idle", 0.0)
		animation.seek(0.0, true)
		animation.pause()
		for heading: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			enemy.visuals.animate(1.0, enemy.speed, heading, heading, 0.0)
			check(face_direction(enemy.visuals).dot(heading) > 0.99,
				"actual nose and eyes face movement in every cardinal direction")
			check(animation.speed_scale > 0.0, "forward motion uses forward walk playback")
		check(not enemy.visuals.has_node("GeneratedVisuals"),
			"health and attack indicators are authored nodes")
	var walker: Zombie = actors[0]
	var runner: Zombie = actors[1]
	var spitter: Zombie = actors[3]
	var boss: Zombie = actors[4]
	check(walker.combat.attacks.is_empty() and runner.combat.attacks.is_empty(),
		"contact enemies need no ranged attack payloads")
	check(spitter.combat.attacks[0] is EnemyFanAttack and spitter.movement.keep_distance,
		"spitter composes ranged and standoff behaviors")
	check(boss.combat.attacks.size() == 2 and boss.combat.attacks[0] is EnemySlamAttack,
		"boss composes close impact and radial attack nodes in priority order")
	check(spitter.visuals.get_node("Body/VariantDetails/Details").scene_file_path != "",
		"variant decoration is a reusable authored scene")
	spitter.visuals.animate(1.0, spitter.speed, Vector3.LEFT, Vector3.RIGHT, 0.0)
	check(face_direction(spitter.visuals).dot(Vector3.RIGHT) > 0.99,
		"retreating spitter keeps its face toward its target")
	check(spitter.visuals._animation.speed_scale < 0.0,
		"retreating uses reverse walk playback rather than forward moonwalking")
	spitter.visuals.play_attack(0.65)
	check(spitter.visuals._animation.get_playing_speed() > 0.0,
		"attacking after retreat resets reverse animation speed")
	var independent := load("res://scenes/enemies/walker.tscn").instantiate() as Zombie
	root.add_child(independent)
	independent.set_physics_process(false)
	var unchanged_health: float = independent.health
	walker.take_damage(10.0)
	check(independent.health == unchanged_health, "health state is independent across instances")
	walker.radius = 0.7
	check(is_equal_approx(walker.get_node("CollisionShape3D").shape.radius, 0.7),
		"root radius property updates its collision shape")
	check(is_equal_approx(independent.get_node("CollisionShape3D").shape.radius, 0.43),
		"editing one collision shape never modifies another instance")
	walker.visuals.skin_color = Color.RED
	var original_skin := independent.visuals._model.find_child(
		"Head | broad square skull", true, false
	) as MeshInstance3D
	check(original_skin.get_active_material(0).albedo_color != Color.RED,
		"presentation palettes are local to each instance")
	var target := Node3D.new()
	root.add_child(target)
	target.position = Vector3(10, 0, 0)
	independent.target = target
	await physics_frame
	var before: Vector3 = independent.global_position
	independent._physics_process(0.3)
	var travel: Vector3 = independent.global_position - before
	check(travel.x > 0.0 and face_direction(independent.visuals).dot(travel.normalized()) > 0.99,
		"actor displacement and actual model face agree during pursuit")
	var detour := DetourNavigation.new()
	root.add_child(detour)
	detour.set_physics_process(false)
	independent.movement.navigation = detour
	before = independent.global_position
	independent._physics_process(0.3)
	travel = independent.global_position - before
	check(travel.z > 0.0 and face_direction(independent.visuals).dot(travel.normalized()) > 0.99,
		"pursuer faces the detour direction instead of looking sideways at its target")
	detour.queue_free()
	for enemy in actors:
		enemy.queue_free()
	independent.queue_free()
	target.queue_free()
	await process_frame
	await process_frame
	print("ENEMIES %s: %d checks, %d failures" % [
		"PASSED" if failures == 0 else "FAILED", checks, failures,
	])
	quit(0 if failures == 0 else 1)
