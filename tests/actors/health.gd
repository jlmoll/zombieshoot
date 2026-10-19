extends SceneTree
## Real actors retain immunity and presentation while sharing health state.

var checks: int = 0
var failures: int = 0
var player_deaths: int = 0
var enemy_deaths: int = 0
var player_changes: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("ACTOR HEALTH: " + description)


func run() -> void:
	const PLAYER_SCENE = preload("res://scenes/actors/player.tscn")
	var first := PLAYER_SCENE.instantiate() as Survivor
	var second := PLAYER_SCENE.instantiate() as Survivor
	var enemy := preload("res://scenes/enemies/walker.tscn").instantiate() as Zombie
	enemy.configure_wave(4)
	check(
		is_equal_approx(enemy.health, enemy.base_health * 1.315),
		"enemy health can be configured before the actor enters the tree"
	)
	root.add_child(first)
	root.add_child(second)
	root.add_child(enemy)
	first.set_physics_process(false)
	second.set_physics_process(false)
	enemy.set_physics_process(false)
	first.health_component.health_changed.connect(
		func(_current: float, _maximum: float): player_changes += 1
	)
	first.died.connect(func(): player_deaths += 1)
	enemy.defeated.connect(func(_actor: Node3D): enemy_deaths += 1)
	var hostile := DamageContext.create(enemy, enemy, DamageContext.Team.ENEMY, &"contact")
	first.take_damage(20.0, hostile)
	first.take_damage(20.0, hostile)
	check(
		first.health == 80.0 and player_changes == 1 and first.last_damage_context == hostile,
		"actor immunity rejects stacked hits before they reach the health component"
	)
	check(second.health == 100.0, "damage to one survivor leaves another scene instance unchanged")
	first.heal(200.0)
	check(
		first.health == 100.0 and player_changes == 2,
		"survivor healing uses the common maximum and emits one change"
	)
	first.reset_state()
	first.try_dash()
	first.take_damage(50.0, hostile)
	check(
		first.health == 100.0 and first.last_damage_context == null,
		"dash invulnerability remains an actor responsibility"
	)
	first.reset_state()
	first.take_damage(500.0, hostile)
	first.take_damage(500.0, hostile)
	first.heal(100.0)
	first.grenades = 1
	check(
		first.health == 0.0 and player_deaths == 1 and not first.try_throw_grenade(),
		"a depleted survivor emits one death and cannot heal or act"
	)
	first.reset_state()
	first.take_damage(10.0, hostile)
	check(
		first.health == 90.0 and player_deaths == 1,
		"reset restores actor controls, health state and damage reception"
	)
	var shot := DamageContext.create(first, first, DamageContext.Team.PLAYER, &"pistol")
	var impact: DamageContext = shot.for_hit(enemy.global_position, Vector3.RIGHT)
	enemy.take_damage(5000.0, impact)
	enemy.take_damage(5000.0, impact)
	enemy.heal(5000.0)
	check(
		(
			enemy.dead
			and enemy.health == 0.0
			and enemy_deaths == 1
			and enemy.last_damage_context == impact
			and enemy.collision_layer == 0
		),
		"enemy depletion preserves attribution and presents one defeat"
	)
	check(
		not enemy.visuals.get_node("Indicators/HealthBar").visible,
		"damage and healing cannot show a health bar after death presentation"
	)
	first.queue_free()
	second.queue_free()
	enemy.queue_free()
	await process_frame
	await process_frame
	print(
		(
			"ACTOR HEALTH %s: %d checks, %d failures"
			% [
				"PASSED" if failures == 0 else "FAILED",
				checks,
				failures,
			]
		)
	)
	quit(0 if failures == 0 else 1)
