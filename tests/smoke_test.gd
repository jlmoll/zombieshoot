extends Node
## Optional CLI smoke runner. Production orchestration contains no test logic.


func run(game: Game) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game.start_run()
	await get_tree().process_frame
	var session: RunSession = game.session
	assert(is_instance_valid(session.player) and session.player.health > 0)
	for kind in ["walker", "runner", "brute", "spitter", "boss"]:
		var enemy: Zombie = session.enemies.spawn(kind, Vector3(5, 0, -4), session.waves.wave)
		enemy.take_damage(100000)
	await get_tree().process_frame
	assert(session.kills == 5, "Enemy kill callback fires once per archetype")
	session.combat.spawn_player_bullet(Vector3(0, 0.7, 0), Vector3.RIGHT, 10, 20)
	session.combat.spawn_enemy_bullet(Vector3(8, 0.7, 0), Vector3.LEFT, 10, 8)
	session.player.take_damage(20)
	session.player.heal(10)
	for upgrade in GameRules.UPGRADES:
		session.player.apply_upgrade(upgrade.id)
	session.pickups.spawn_pickup(Vector3.ZERO, "health")
	session.pickups.spawn_pickup(Vector3.ZERO, "ammo")
	await get_tree().create_timer(0.6).timeout
	game.pause_run()
	assert(get_tree().paused)
	game.resume_run()
	assert(not get_tree().paused)
	print("SMOKE TEST PASSED: arena, five enemies, projectiles, damage, healing, upgrades, pickups, pause")
	get_tree().quit(0)
