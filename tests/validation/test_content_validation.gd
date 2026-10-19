extends RefCounted
## Invalid editor content and global-coordinate map contracts.


static func run(tree: SceneTree) -> bool:
	const GRENADE_SCENE = preload("res://scenes/projectiles/grenade.tscn")
	var empty_campaign := WaveCampaign.new()
	assert(not empty_campaign.get_configuration_errors().is_empty())
	var missing_definition := WaveCampaign.new()
	missing_definition.waves.append(null)
	assert(not missing_definition.get_configuration_errors().is_empty())
	var invalid_rule := WaveSpawnRule.new()
	invalid_rule.every_nth_spawn = 0
	assert(not invalid_rule.get_configuration_errors().is_empty())
	var bare_attack := EnemyAttack.new()
	assert(not ContentValidator.validate_attack(bare_attack).is_empty())
	bare_attack.free()
	var slam := EnemySlamAttack.new()
	assert(not ContentValidator.validate_attack(slam).is_empty())
	slam.free()
	var invalid_enemy := Zombie.new()
	assert(ContentValidator.validate_enemy(invalid_enemy).size() >= 4)
	invalid_enemy.free()
	var incomplete_ranged := load("res://scenes/enemies/spitter.tscn").instantiate() as Zombie
	for attack in incomplete_ranged.combat.get_children():
		attack.free()
	assert(_contains(ContentValidator.validate_enemy(incomplete_ranged), "no ranged attack"))
	incomplete_ranged.free()
	assert(not ContentValidator.validate_projectile_scene(null).is_empty())
	assert(not (ContentValidator.validate_projectile_scene(GRENADE_SCENE).is_empty()))
	assert(ContentValidator.validate_grenade_scene(GRENADE_SCENE).is_empty())
	var arena := load("res://scenes/world/arena.tscn").instantiate() as Arena
	var transformed_parent := Node3D.new()
	transformed_parent.position = Vector3(75.0, 0.0, -41.0)
	transformed_parent.rotation.y = 0.61
	tree.root.add_child(transformed_parent)
	transformed_parent.add_child(arena)
	arena.navigation.set_target(arena.player_spawn)
	var spawner := EnemySpawner.new()
	var campaign: WaveCampaign = load("res://assets/waves/default_campaign.tres")
	assert(ContentValidator.validate_enemy_scenes(spawner.enemy_scenes).is_empty())
	assert(ContentValidator.validate_campaign(campaign, arena, spawner.enemy_scenes).is_empty())
	var detached_session := Game.RUN_SCENE.instantiate()
	assert(ContentValidator.validate_run(arena, detached_session).is_empty())
	detached_session.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 231
	var point: Variant = arena.choose_spawn("walker", 1, arena.player_spawn.global_position, rng)
	assert(point != null and arena.navigation.can_reach_target(point))
	assert(
		point.distance_to(arena.player_spawn.global_position) < 40.0,
		"Spawn points and navigation use global coordinates under transformed maps"
	)
	var zone := SpawnZone.new()
	zone.width = 0.0
	arena.spawn_container.add_child(zone)
	zone.position = Vector3(3.0, 0.0, 4.0)
	assert(zone.sample(rng).is_equal_approx(zone.global_position))
	var missing_registry: Dictionary[String, PackedScene] = spawner.enemy_scenes.duplicate()
	missing_registry.erase("spitter")
	var missing_errors := ContentValidator.validate_campaign(campaign, arena, missing_registry)
	assert(_contains(missing_errors, "no registered scene"))
	for entry in arena.spawn_container.get_children():
		if entry is SpawnZone:
			entry.enabled = false
	var disabled_errors := ContentValidator.validate_campaign(campaign, arena, spawner.enemy_scenes)
	assert(_contains(disabled_errors, "no enabled entrance"))
	spawner.free()
	transformed_parent.free()
	return true


static func _contains(errors: PackedStringArray, expected: String) -> bool:
	for error in errors:
		if expected in error:
			return true
	return false
