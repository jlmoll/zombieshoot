extends Node
## Optional CLI smoke runner. Production orchestration contains no test logic.


func run(game: Game) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game.audio.muted = true
	game.start_run()
	await get_tree().process_frame
	var session: RunSession = game.session
	assert(is_instance_valid(session.player) and session.player.health > 0)
	for kind in ["walker", "runner", "brute", "spitter", "boss"]:
		var enemy: Zombie = session.enemies.spawn(kind, Vector3(5, 0, -4), session.waves.wave)
		var player: Survivor = session.player
		enemy.take_damage(
			100000, DamageContext.create(player, player, player.get_damage_team(), &"smoke")
		)
	await get_tree().process_frame
	assert(session.kills == 5, "Enemy kill callback fires once per archetype")
	session.combat.spawn_player_bullet(Vector3(0, 0.7, 0), Vector3.RIGHT, 10, 20)
	session.combat.spawn_enemy_bullet(Vector3(8, 0.7, 0), Vector3.LEFT, 10, 8)
	session.player.take_damage(20)
	session.player.heal(10)
	for upgrade in GameRules.upgrades:
		session.player.apply_upgrade(upgrade.id)
	session.pickups.spawn_pickup(Vector3.ZERO, "health")
	session.pickups.spawn_pickup(Vector3.ZERO, "ammo")
	await get_tree().create_timer(0.6).timeout
	game.pause_run()
	assert(get_tree().paused)
	game.resume_run()
	assert(not get_tree().paused)
	print(
		"SMOKE TEST PASSED: arena, five enemies, projectiles, damage, healing, upgrades, pickups, pause"
	)
	var tree: SceneTree = get_tree()
	reparent(tree.root)
	game.queue_free()
	await tree.process_frame
	await tree.process_frame
	tree.quit(0)
