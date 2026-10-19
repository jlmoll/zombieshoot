extends RefCounted
## System tests: real content, public scheduling API and bounded failure.


static func run(tree: SceneTree) -> bool:
	var campaign: WaveCampaign = load("res://assets/waves/default_campaign.tres")
	assert(campaign.get_configuration_errors().is_empty())
	assert(campaign.waves.size() == 8)
	var serial: int = 0
	for index in range(campaign.waves.size()):
		var number := index + 1
		var wave := campaign.waves[index]
		assert(wave.enemy_count == 9 + number * 5)
		assert(is_equal_approx(wave.initial_delay, 1.6))
		assert(is_equal_approx(wave.spawn_interval, maxf(0.16, 0.8 - number * 0.065)))
		assert((not wave.boss_kind.is_empty()) == (number == 4 or number == 8))
		for offset in range(wave.enemy_count):
			serial += 1
			var expected := "walker"
			if number >= 2 and serial % 4 == 0:
				expected = "runner"
			if number >= 3 and serial % 7 == 0:
				expected = "spitter"
			if number >= 3 and serial % 9 == 0:
				expected = "brute"
			assert(wave.get_enemy_kind(serial) == expected, "Global serial composition must be preserved")
	var arena := load("res://scenes/world/arena.tscn").instantiate() as Arena
	tree.root.add_child(arena)
	arena.navigation.set_target(arena.player_spawn)
	var spawner := EnemySpawner.new()
	assert(ContentValidator.validate_campaign(campaign, arena, spawner.enemy_scenes).is_empty())
	var director := WaveDirector.new()
	director.campaign = campaign.duplicate(true)
	director.campaign.waves[0].blocked_spawn_timeout = 0.25
	director.map = arena
	director.target = arena.player_spawn
	director.enemy_scenes = spawner.enemy_scenes
	director.count_enemies = func() -> int: return 0
	tree.root.add_child(director)
	director.set_physics_process(false)
	var spawned: Array[String] = []
	var failures: Array[PackedStringArray] = []
	director.enemy_spawn_requested.connect(
		func(kind: String, _point: Vector3, _wave: int) -> void: spawned.append(kind))
	director.configuration_failed.connect(func(errors: PackedStringArray) -> void: failures.append(errors))
	director.start()
	director.advance(1.5)
	assert(spawned.is_empty(), "Initial delay must elapse before first spawn")
	director.advance(0.11)
	assert(spawned.size() == 1)
	director.advance(0.7)
	assert(spawned.size() == 1)
	director.advance(0.04)
	assert(spawned.size() == 2)
	for zone in arena.spawn_container.get_children():
		if zone is SpawnZone:
			zone.minimum_distance = 10000.0
	director.advance(1.0)
	assert(not director.running and failures.size() == 1, "Impossible distance rules must fail in bounded time")
	director.free()
	spawner.free()
	arena.free()
	return true
