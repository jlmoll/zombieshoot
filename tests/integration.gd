extends SceneTree
## Run: Godot --headless --path . --fixed-fps 60 --script tests/integration.gd
## Exercises the actual scene and physics. No mocks or replacement save paths.

var world: Node3D
var checks: int = 0
var failures: int = 0
const SAVE_PATH: String = "user://dead_shift.cfg"
var _save_existed: bool = false
var _original_save: PackedByteArray = PackedByteArray()


func _preserve_save() -> bool:
	_save_existed = FileAccess.file_exists(SAVE_PATH)
	if not _save_existed:
		return true
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot preserve existing save; refusing to mutate user data: %s" % FileAccess.get_open_error())
		return false
	_original_save = file.get_buffer(file.get_length())
	return true


func _restore_save() -> void:
	if _save_existed:
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		_check(file != null, "existing user save can be restored")
		if file != null:
			file.store_buffer(_original_save)
			file.close()
			_check(FileAccess.get_file_as_bytes(SAVE_PATH) == _original_save, "existing user save restored byte for byte")
	elif FileAccess.file_exists(SAVE_PATH):
		_check(DirAccess.remove_absolute(SAVE_PATH) == OK, "test-created user save removed")


func _finish() -> void:
	paused = false
	if is_instance_valid(world):
		world.queue_free()
	# Flush queued scene nodes, particles and signal callables before engine exit.
	await process_frame
	await process_frame
	_restore_save()
	print("INTEGRATION %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("INTEGRATION: " + description)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
	await process_frame


func _fresh_run() -> void:
	world.start_run()
	world.session.waves.spawn_left = 999
	world.session.waves.spawn_clock = 10000.0
	world.session.player.invulnerability = 0.0
	await _frames(2)


func _clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		if enemy.get_parent() == world.session.enemies:
			enemy.queue_free()
	world.session.combat.clear_projectiles()
	await _frames(2)


func _stationary_enemy(kind: String, at: Vector3) -> Node3D:
	var enemy: Node3D = world.session.enemies.spawn(kind, at, world.session.waves.wave)
	enemy.set_physics_process(false)
	return enemy


func _run() -> void:
	if not _preserve_save():
		quit(1)
		return
	var scene_error: Error = change_scene_to_file("res://scenes/main.tscn")
	if scene_error != OK:
		push_error("Cannot load the real main scene: %s" % scene_error)
		quit(1)
		return
	await process_frame
	await process_frame
	world = current_scene as Node3D
	_check(world != null, "main scene becomes current_scene")
	if world == null:
		quit(1)
		return
	# Fixed-fps headless runs advance faster than the audio mixer. Keep procedural
	# sound generation loaded, but avoid starting real-time playback in this suite.
	world.audio.muted = true
	_check(world.mode == world.Mode.TITLE and paused, "title pauses the simulation")
	await _test_menu_focus()
	await _test_lifecycle_and_player()
	await _test_session_isolation()
	await _test_map_authoring()
	await _test_actor_isolation()
	await _test_deferred_wave_pause()
	await _test_projectile_physics()
	await _test_grenades()
	await _test_enemy_navigation_and_attacks()
	await _test_progression()
	await _test_invalid_content()
	await _finish()


func _test_menu_focus() -> void:
	world.hud.set_muted(world.audio.muted)
	var sound: Button = world.hud.menus.find_child("SoundButton", true, false) as Button
	sound.grab_focus()
	var muted_before: bool = world.audio.muted
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	enter = enter.duplicate()
	enter.pressed = false
	Input.parse_input_event(enter)
	await _frames(3)
	_check(world.mode == world.Mode.TITLE and world.audio.muted != muted_before, "Enter activates focused sound button without starting a run")
	world.audio.muted = true
	world.hud.set_muted(true)


func _test_lifecycle_and_player() -> void:
	await _fresh_run()
	_check(world.mode == world.Mode.PLAYING and not paused and world.session.waves.wave == 1, "start begins wave one")
	_check(world.session.player.health == 100.0 and world.session.player.weapon_controller.weapons.size() == 3, "fresh survivor has full health and three weapons")
	# Exercise the real input dispatch, including events sent by embedded windows.
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	_check(world.session.player.weapon_controller.selected_index == 1, "logical key event selects shotgun through viewport input")
	key.pressed = false
	Input.parse_input_event(key)
	key = InputEventKey.new()
	key.keycode = KEY_Q
	key.physical_keycode = KEY_Q
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	_check(world.session.player.weapon_controller.selected_index == 2, "physical key event cycles weapon through viewport input")
	key.pressed = false
	Input.parse_input_event(key)
	key = InputEventKey.new()
	key.keycode = KEY_1
	key.physical_keycode = KEY_TAB
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	_check(world.session.player.weapon_controller.selected_index == 0, "hotkey uses visible logical label when remapped scan code differs")
	key.pressed = false
	Input.parse_input_event(key)
	key = InputEventKey.new()
	key.keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	var start_position: Vector3 = world.session.player.position
	await _frames(10)
	key.pressed = false
	Input.parse_input_event(key)
	_check(world.session.player.position.x > start_position.x + 0.3 and world.session.player.position.z < start_position.z - 0.3, "logical movement key travels right relative to isometric camera")
	world.session.player.position = Vector3.ZERO
	world.session.player.select_weapon(0)
	await _frames(10)
	world.pause_run()
	var elapsed_before: float = world.session.elapsed
	await _frames(4)
	_check(paused and world.mode == world.Mode.PAUSED and world.session.elapsed == elapsed_before, "pause stops gameplay time")
	world.resume_run()
	_check(not paused and world.is_gameplay_active(), "resume restores gameplay")
	var player: Node3D = world.session.player
	player.take_damage(20.0)
	_check(player.health == 80.0, "damage subtracts health")
	player.take_damage(20.0)
	_check(player.health == 80.0, "damage invulnerability prevents stacked hits")
	player.heal(1000.0)
	_check(player.health == player.max_health, "healing clamps at maximum")
	player.invulnerability = 0.0
	player.aim_direction = Vector3.RIGHT
	player.try_dash()
	var base_dash_cooldown: float = player.dash_cooldown
	_check(player.dash_remaining > 0.0 and base_dash_cooldown > 0.0, "dash starts with cooldown")
	player.take_damage(50.0)
	_check(player.health == player.max_health, "dash grants invulnerability")
	player.try_dash()
	_check(player.dash_cooldown == base_dash_cooldown, "cooldown prevents repeated dashes")
	await _frames(75)
	_check(player.dash_remaining == 0.0 and player.dash_cooldown == 0.0, "dash and cooldown expire")
	player.position = Vector3.ZERO
	player.aim_direction = Vector3.RIGHT
	var ammo_before: int = player.weapon_controller.current_weapon.magazine.ammo
	player.try_shoot()
	_check(player.weapon_controller.current_weapon.magazine.ammo == ammo_before - 1 and not get_nodes_in_group("projectiles").is_empty(), "shoot consumes ammo and creates projectile")
	player.try_shoot()
	_check(player.weapon_controller.current_weapon.magazine.ammo == ammo_before - 1, "fire interval prevents extra immediate shot")
	player.select_weapon(1)
	_check(player.weapon_controller.current_weapon.magazine.capacity == 6 and player.weapon_controller.current_weapon.magazine.ammo == 6, "shotgun has independent magazine")
	player.select_weapon(0)
	_check(player.weapon_controller.current_weapon.magazine.ammo == ammo_before - 1, "weapon switch preserves ammo")
	player.start_reload()
	_check(player.weapon_controller.current_weapon.magazine.reloading, "manual reload starts")
	await _frames(70)
	_check(not player.weapon_controller.current_weapon.magazine.reloading and player.weapon_controller.current_weapon.magazine.ammo == player.weapon_controller.current_weapon.magazine.capacity, "reload completes and refills magazine")
	player.reset_state()
	player.take_damage(75.0)
	player.apply_upgrade("health")
	_check(player.max_health == 125.0 and player.health == 125.0, "health upgrade raises maximum and fully restores life as offered")
	player.apply_upgrade("damage")
	_check(is_equal_approx(player.weapon_controller.current_weapon.damage_multiplier, 1.25), "damage upgrade provides advertised 25 percent")
	player.apply_upgrade("speed")
	_check(is_equal_approx(player.speed_multiplier, 1.15), "speed upgrade provides advertised 15 percent")
	player.apply_upgrade("fire_rate")
	_check(is_equal_approx(player.weapon_controller.current_weapon.fire_rate_multiplier, 1.2), "fire-rate upgrade provides advertised 20 percent")
	player.apply_upgrade("reload")
	_check(is_equal_approx(player.weapon_controller.current_weapon.reload_multiplier, 0.8), "reload upgrade reduces reload duration 20 percent")
	player.apply_upgrade("dash")
	player.dash_cooldown = 0.0
	player.dash_remaining = 0.0
	player.try_dash()
	_check(player.dash_cooldown < base_dash_cooldown, "dash upgrade reduces recovery time")
	await _frames(75)
	player.position = Vector3(15.5, 0, 0)
	player.aim_direction = Vector3.RIGHT
	player.move_direction = Vector3.RIGHT
	player.try_dash()
	await _frames(20)
	_check(player.position.x <= 17.7 and player.position.x > 16.5, "dash collides with arena wall without tunnelling")
	player.position = Vector3.ZERO
	player.health = 30.0
	player.weapon_controller.current_weapon.magazine.ammo = 0
	world.session.pickups.spawn_pickup(Vector3.ZERO, "health")
	world.session.pickups.spawn_pickup(Vector3.ZERO, "ammo")
	await _frames(3)
	_check(player.health == 55.0 and player.weapon_controller.current_weapon.magazine.ammo == player.weapon_controller.current_weapon.magazine.capacity and world.session.pickups.get_child_count() == 0, "health and ammo pickups apply and disappear")
	print("Integration: survivor, weapons, upgrades, dash, pickups and pause checked")


func _test_session_isolation() -> void:
	await _fresh_run()
	var previous_session: Node3D = world.session
	var previous_player: Node3D = previous_session.player
	var arena: Node3D = world.arena
	var audio: Node = world.audio
	var save_data: Node = world.save_data
	var best_before: int = save_data.best_score
	var muted_before: bool = save_data.muted
	_check(previous_player.get_parent() == previous_session, "session scene owns survivor")
	_check(previous_session.waves.get_parent() == previous_session and previous_session.enemies.get_parent() == previous_session, "session owns wave scheduler and enemy population")
	_check(previous_session.combat.get_parent() == previous_session and previous_session.pickups.get_parent() == previous_session and previous_session.effects.get_parent() == previous_session, "session owns combat, pickups and effects")
	_check(previous_session.process_mode == Node.PROCESS_MODE_PAUSABLE, "session is a pausable simulation boundary")
	_check(world.arena.navigation.target == previous_player, "navigation target is injected from active session")
	_check(previous_session.enemies.player == previous_player and previous_session.waves.target == previous_player, "spawn and wave services receive active survivor")
	var old_enemy: Node3D = _stationary_enemy("walker", Vector3(10, 0, 5))
	_check(old_enemy.get_parent() == previous_session.enemies and old_enemy.target == previous_player, "spawner owns enemy and injects its target")
	_check(old_enemy.navigation == world.arena.navigation and old_enemy.visuals.get_parent() == old_enemy, "enemy navigation is injected while visuals remain actor-owned")
	previous_session.combat.spawn_player_bullet(Vector3(4, 0.8, 4), Vector3.RIGHT, 1.0, 1.0)
	var old_projectile: Node3D = previous_session.combat.get_node("Projectiles").get_child(0) as Node3D
	var old_grenade: Node3D = previous_session.combat.spawn_grenade(Vector3(4, 1, 4), Vector3.RIGHT)
	_check(old_grenade.get_parent() == previous_session.combat.get_node("Grenades"), "combat owns grenade in semantic container")
	previous_session.pickups.spawn_pickup(Vector3(12, 0, 12), "health")
	var old_pickup: Node3D = previous_session.pickups.get_child(0) as Node3D
	previous_session.effects.spawn_particles(Vector3(4, 1, 4), Color.WHITE, 3)
	var old_effect: Node3D = previous_session.effects.get_child(0) as Node3D
	world.start_run()
	world.session.waves.spawn_left = 999
	world.session.waves.spawn_clock = 10000.0
	await _frames(3)
	_check(not is_instance_valid(previous_session) and not is_instance_valid(previous_player), "restart frees previous session and survivor")
	_check(not is_instance_valid(old_enemy) and not is_instance_valid(old_projectile) and not is_instance_valid(old_grenade), "restart frees old enemies, projectiles and grenades")
	_check(not is_instance_valid(old_pickup) and not is_instance_valid(old_effect), "restart frees pickups and effects through session ownership")
	_check(get_nodes_in_group("enemies").is_empty() and get_nodes_in_group("projectiles").is_empty() and get_nodes_in_group("grenades").is_empty(), "no previous-run combat nodes remain in scene groups")
	_check(get_nodes_in_group("player").size() == 1 and get_nodes_in_group("player")[0] == world.session.player, "exactly one active survivor remains after restart")
	_check(world.arena != arena and world.arena.get_parent() == world.session and world.audio == audio and world.save_data == save_data, "restart replaces map and preserves audio and persistence services")
	_check(save_data.best_score == best_before and save_data.muted == muted_before, "restart preserves record and saved mute preference")
	_check(world.arena.navigation.target == world.session.player, "restart retargets shared navigation to new survivor")
	print("Integration: semantic ownership, dependency injection, restart cleanup and persistence isolation checked")


func _test_deferred_wave_pause() -> void:
	await _fresh_run()
	var waves: Node = world.session.waves
	waves.set_physics_process(false)
	waves.spawn_left = 0
	waves.wave_finished = false
	waves.advance(1.0 / 60.0)
	world.pause_run()
	await _frames(2)
	_check(world.mode == world.Mode.PAUSED and not waves.wave_finished, "pause defers completed wave without losing its notification")
	world.resume_run()
	waves.set_physics_process(true)
	await _frames(4)
	_check(world.mode == world.Mode.UPGRADES and paused, "resuming after deferred wave completion still opens upgrades")


func _test_actor_isolation() -> void:
	await _fresh_run()
	var isolated := Node3D.new()
	isolated.name = "IsolatedActors"
	isolated.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(isolated)
	var player_scene: PackedScene = load("res://scenes/actors/player.tscn") as PackedScene
	var enemy_scene: PackedScene = load("res://scenes/actors/enemy.tscn") as PackedScene
	var local_player: Node3D = player_scene.instantiate() as Node3D
	isolated.add_child(local_player)
	var local_enemy: Node3D = enemy_scene.instantiate() as Node3D
	local_enemy.configure_wave(1)
	local_enemy.target = local_player
	isolated.add_child(local_enemy)
	var shots: Array[int] = [0]
	var defeats: Array[int] = [0]
	local_player.bullet_requested.connect(func(_origin: Vector3, _direction: Vector3, _damage: float, _speed: float, _pierce: int) -> void: shots[0] += 1)
	local_enemy.defeated.connect(func(_enemy: Node3D) -> void: defeats[0] += 1)
	local_enemy.take_damage(18.0)
	local_enemy.configure_wave(2)
	_check(local_enemy.health == local_enemy.max_health and not local_enemy.visuals.get_node("Indicators/HealthBar").visible and is_equal_approx(local_enemy.visuals.get_node("Indicators/HealthBar/Fill").scale.x, 0.9), "reconfiguring same enemy type resets health presentation with health state")
	var score_before: int = world.session.score
	var kills_before: int = world.session.kills
	var bullets_before: int = world.session.combat.get_node("Projectiles").get_child_count()
	local_player.try_shoot()
	_check(shots[0] == 1 and local_player.weapon_controller.current_weapon.magazine.ammo == local_player.weapon_controller.current_weapon.magazine.capacity - 1, "isolated survivor emits shooting request without a game-root dependency")
	_check(world.session.combat.get_node("Projectiles").get_child_count() == bullets_before, "unconnected actor cannot spawn projectiles into unrelated session")
	local_enemy.take_damage(100000.0)
	local_enemy.take_damage(100000.0)
	_check(defeats[0] == 1, "isolated zombie emits one defeated signal without a game-root dependency")
	_check(world.session.score == score_before and world.session.kills == kills_before, "isolated actor death cannot award score to unrelated session")
	isolated.queue_free()
	await _frames(2)
	_check(get_nodes_in_group("player").size() == 1 and world.session.enemies.living_count() == 0, "isolated actor cleanup leaves active session unchanged")


func _test_projectile_physics() -> void:
	await _fresh_run()
	var player: Node3D = world.session.player
	player.set_physics_process(false)
	var enemy: Node3D = _stationary_enemy("walker", Vector3(4, 0, 0))
	await _frames(2)
	world.session.combat.spawn_player_bullet(Vector3(1, 0.8, 0), Vector3.RIGHT, 12.0, 80.0)
	await _frames(8)
	_check(is_equal_approx(enemy.health, enemy.max_health - 12.0), "swept friendly projectile hits enemy exactly once")
	_check(player.health == 100.0, "friendly projectile cannot harm survivor")
	await _clear_enemies()
	var first: Node3D = _stationary_enemy("walker", Vector3(4, 0, 2))
	var second: Node3D = _stationary_enemy("walker", Vector3(7, 0, 2))
	await _frames(2)
	world.session.combat.spawn_player_bullet(Vector3(1, 0.8, 2), Vector3.RIGHT, 10.0, 120.0, 1)
	await _frames(8)
	_check(first.health == first.max_health - 10.0 and second.health == second.max_health - 10.0, "penetration hits two bodies once each")
	await _clear_enemies()
	var covered: Node3D = _stationary_enemy("walker", Vector3(7, 0, -10))
	await _frames(2)
	world.session.combat.spawn_player_bullet(Vector3(7, 0.8, -4), Vector3.FORWARD, 99.0, 150.0)
	await _frames(8)
	_check(covered.health == covered.max_health and get_nodes_in_group("projectiles").is_empty(), "solid cover blocks and destroys fast projectile")
	await _clear_enemies()
	var ignored: Node3D = _stationary_enemy("walker", Vector3(2, 0, 0))
	await _frames(2)
	player.invulnerability = 0.0
	world.session.combat.spawn_enemy_bullet(Vector3(4, 0.8, 0), Vector3.LEFT, 9.0, 80.0)
	await _frames(8)
	_check(player.health == 91.0 and ignored.health == ignored.max_health, "hostile projectile ignores zombies and hits survivor")
	await _clear_enemies()
	var kills_before: int = world.session.kills
	for kind in ["walker", "runner", "brute", "spitter", "boss"]:
		var target: Node3D = _stationary_enemy(kind, Vector3(5, 0, -4))
		target.take_damage(100000.0, DamageContext.create(player, player, player.get_damage_team(), &"test"))
		target.take_damage(100000.0)
	_check(world.session.kills == kills_before + 5, "every archetype reports exactly one death")
	await _frames(2)
	_check(world.session.enemies.living_count() == 0, "dead archetypes leave active enemy population")
	print("Integration: projectile masks, continuous collisions, cover, penetration and death checked")


func _test_enemy_navigation_and_attacks() -> void:
	await _fresh_run()
	world.session.player.set_physics_process(false)
	world.session.player.position = Vector3(7, 0, -11)
	world.session.player.invulnerability = 1000.0
	world.arena.navigation.rebuild()
	var walker: Node3D = world.session.enemies.spawn("walker", Vector3(7, 0, -3), world.session.waves.wave)
	var crossed_cover: bool = false
	for step in range(75):
		await _frames(6)
		for rect: Rect2 in world.arena.navigation.obstacles:
			if rect.grow(-0.75).has_point(Vector2(walker.position.x, walker.position.z)):
				crossed_cover = true
	_check(not crossed_cover, "horde AI navigates around solid cover")
	_check(walker.position.distance_to(world.session.player.position) < 3.5, "horde flow navigation reaches survivor behind crate")
	await _clear_enemies()
	world.session.player.position = Vector3.ZERO
	world.arena.navigation.rebuild()
	var spitter: Node3D = world.session.enemies.spawn("spitter", Vector3(0, 0, -9), world.session.waves.wave)
	spitter.combat.cooldown_remaining = 0.0
	await _frames(5)
	_check(spitter.combat.windup_remaining > 0.0 and spitter.visuals.warning.visible, "spitter attack has visible windup")
	await _frames(45)
	_check(get_nodes_in_group("projectiles").size() >= 3, "spitter fires three-projectile fan after windup")
	await _clear_enemies()
	var boss: Node3D = world.session.enemies.spawn("boss", Vector3(0, 0, -10), world.session.waves.wave)
	boss.combat.cooldown_remaining = 0.0
	await _frames(5)
	_check(boss.combat.windup_remaining > 0.0 and boss.visuals.warning.visible, "boss attack has visible windup")
	await _frames(52)
	_check(get_nodes_in_group("projectiles").size() >= 10, "boss emits radial projectile pattern")
	await _clear_enemies()
	world.session.player.health = 100.0
	world.session.player.invulnerability = 0.0
	var slammer: Node3D = world.session.enemies.spawn("boss", Vector3(0, 0, -3), world.session.waves.wave)
	slammer.combat.cooldown_remaining = 0.0
	await _frames(5)
	_check(slammer.combat.current_attack.attack_id == &"slam" and slammer.visuals.warning.visible, "nearby boss telegraphs area slam")
	await _frames(60)
	_check(world.session.player.health == 74.0, "slam deals advertised area damage after windup")
	print("Integration: obstacle routing, telegraphs, ranged AI and boss patterns checked")


func _test_grenades() -> void:
	await _fresh_run()
	var player: Node3D = world.session.player
	_check(player.grenades == 2, "first wave grants two grenades")
	_check(world.hud.gameplay.grenades_label.text.contains("2 / 4"), "HUD displays grenade inventory and cap")
	player.controls.mouse_aim_active = false
	player.aim_direction = Vector3.RIGHT
	_stationary_enemy("walker", Vector3(9, 0, 0))
	_stationary_enemy("spitter", Vector3(9, 0, 2))
	var outside: Node3D = _stationary_enemy("walker", Vector3(15.5, 0, 0))
	var key := InputEventKey.new()
	key.keycode = KEY_G
	key.pressed = true
	Input.parse_input_event(key)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await _frames(2)
	_check(player.grenades == 1 and get_nodes_in_group("grenades").size() == 1, "G launches one grenade and consumes one charge")
	_check(not player.try_throw_grenade() and player.grenades == 1, "throw cooldown prevents accidental duplicate grenades")
	var grenade: Node3D = get_nodes_in_group("grenades")[0]
	await _frames(10)
	_check(grenade.position.x > 1.0 and grenade.position.y > 1.0, "grenade travels in an airborne arc")
	world.pause_run()
	var fuse_before: float = grenade.fuse_left
	var position_before: Vector3 = grenade.position
	await _frames(30)
	_check(grenade.fuse_left == fuse_before and grenade.position == position_before, "pause freezes grenade fuse and flight")
	_check(not player.try_throw_grenade(), "grenades cannot be thrown while paused")
	world.resume_run()
	await _frames(110)
	_check(world.session.kills == 2, "timed explosion kills multiple enemies in its radius")
	_check(outside.health == outside.max_health, "explosion leaves distant enemies unharmed")
	_check(player.health == player.max_health, "grenades do not cause self damage")
	_check(get_nodes_in_group("grenades").is_empty(), "exploded grenade cleans up after its visual effect")
	await _clear_enemies()
	var near: Node3D = _stationary_enemy("brute", Vector3(1, 0, 0))
	var direct: Node3D = world.session.combat.spawn_grenade(Vector3(0, 0.18, 0), Vector3.RIGHT)
	direct.detonate()
	var remaining_health: float = near.health
	direct.detonate()
	_check(near.health < near.max_health and near.health == remaining_health, "detonation damages each enemy only once")
	_check(player.health == player.max_health, "point-blank detonation remains safe for survivor")
	await _clear_enemies()
	var covered: Node3D = _stationary_enemy("walker", Vector3(7, 0, -9))
	await _frames(2)
	world.session.combat.detonate_grenade(Vector3(7, 0.18, -4), 160.0, 7.0)
	_check(covered.health == covered.max_health, "solid cover blocks grenade blast")
	var bouncing: Node3D = world.session.combat.spawn_grenade(Vector3(17.3, 0.95, 0), Vector3.RIGHT)
	await _frames(8)
	_check(bouncing.position.x < 17.8 and bouncing.velocity.x < 0, "grenade bounces from arena boundary")
	world.session.combat.clear_projectiles()
	await _frames(2)
	_check(get_nodes_in_group("grenades").is_empty(), "wave cleanup removes unexploded grenades")
	player.grenades = 0
	_check(not player.try_throw_grenade() and player.grenades == 0, "empty inventory cannot throw or become negative")
	for supply in [[0, 2], [1, 3], [3, 4], [4, 4]]:
		player.grenades = supply[0]
		world.session.waves.start_next_wave()
		_check(player.grenades == supply[1], "wave adds two grenades capped at four from inventory %d" % supply[0])
	await _fresh_run()
	_check(world.session.player.grenades == 2 and get_nodes_in_group("grenades").is_empty(), "restart resets stock to first-wave allowance and clears grenades")
	print("Integration: grenade input, flight, fuse, pause, blast, cover, cleanup and replenishment checked")


func _test_progression() -> void:
	world.start_run()
	world.session.player.set_physics_process(false)
	world.session.player.invulnerability = 1000.0
	await _frames(2)
	for expected_wave in range(1, 9):
		_check(world.session.waves.wave == expected_wave, "wave advances in sequence: %d" % expected_wave)
		_check(world.session.player.grenades == mini(4, expected_wave * 2), "actual wave transition replenishes grenades with a hard cap")
		while world.session.waves.spawn_left > 0:
			world.session.waves.spawn_next()
		var expected_enemies: int = 9 + expected_wave * 5 + (1 if expected_wave in [4, 8] else 0)
		_check(world.session.enemies.living_count() == expected_enemies, "wave %d schedules complete population including bosses" % expected_wave)
		world.session.combat.spawn_enemy_bullet(Vector3(16, 0.8, 16), Vector3.LEFT, 1.0, 1.0)
		for enemy in get_nodes_in_group("enemies"):
			if enemy.get_parent() == world.session.enemies:
				var player: Survivor = world.session.player
				enemy.take_damage(100000.0, DamageContext.create(player, player, player.get_damage_team(), &"test"))
		await _frames(4)
		_check(get_nodes_in_group("projectiles").is_empty(), "wave end clears hostile projectiles")
		if expected_wave < 8:
			_check(world.mode == world.Mode.UPGRADES and paused, "cleared wave pauses for upgrade choice")
			var damage_before: float = world.session.player.weapon_controller.current_weapon.damage_multiplier
			world.choose_upgrade("damage")
			_check(world.mode == world.Mode.PLAYING and not paused and world.session.player.weapon_controller.current_weapon.damage_multiplier > damage_before, "upgrade choice applies and resumes intermission")
			world.session.waves.intermission = 0.01
			await _frames(3)
	_check(world.mode == world.Mode.VICTORY and paused and world.session.waves.wave == 8, "eighth cleared wave ends in victory")
	_check(world.session.kills == 254 and world.session.score > 0, "complete run rewards all 254 scheduled enemies")
	world.start_run()
	await _frames(2)
	_check(world.mode == world.Mode.PLAYING and world.session.waves.wave == 1 and world.session.kills == 0 and world.session.player.health == 100.0, "restart creates clean survivor and score after victory")
	world.session.player.invulnerability = 0.0
	world.session.player.take_damage(10000.0)
	_check(world.mode == world.Mode.DEAD and paused, "fatal damage ends and pauses run")
	world.start_run()
	await _frames(2)
	_check(world.mode == world.Mode.PLAYING and not paused and world.session.player.health == 100.0 and world.session.score == 0, "restart after death resets run")
	print("Integration: all eight waves, upgrades, victory, death and restart checked")



func _test_map_authoring() -> void:
	await _fresh_run()
	var map: Arena = world.arena
	var nav: HordeNavigation = map.navigation
	var tiles := map.get_node("Ground/FloorTiles") as GridMap
	_check(tiles != null and tiles.mesh_library != null, "floor is an editor-paintable GridMap with a MeshLibrary")
	_check(tiles.get_used_cells().size() == 144 and map.get_node("Ground").get_child_count() == 2, "floor cells replace individual tile nodes")
	_check(tiles.get_cell_item(Vector3i(-6, 0, -6)) == 0 and tiles.get_cell_item(Vector3i(-6, 0, -5)) == 1, "GridMap preserves the original checkerboard layout")

	_check(not map.has_node("Markings") and not map.has_node("Perimeter"), "map has no loose markings or perimeter detail containers")
	_check(map.get_node("Props/HazardPanel1").scene_file_path.ends_with("hazard_panel.tscn"), "hazard panel is one reusable prop")
	_check(map.get_node("Props/HazardPanel1").get_child_count() == 0, "hazard stripes are merged into one mesh")
	_check(map.get_node("Props/SectorSign").scene_file_path.ends_with("sector_sign.tscn"), "sector sign is a complete editable prop")
	_check(map.get_node("Environment").scene_file_path.ends_with("map_environment.tscn"), "lighting is encapsulated in a reusable environment scene")
	var structure := map.get_node("Structure") as GridMap
	_check(structure != null and structure.mesh_library.get_item_list().size() == 5, "structure is paintable with collidable illuminated wall modules")
	structure.set_cell_item(Vector3i(1, 0, 1), 0)
	map.rebuild_navigation()
	_check(not nav.is_walkable(Vector3(4.5, 0, 2.6)), "navigation reads collision shapes from painted structure cells")
	structure.set_cell_item(Vector3i(1, 0, 1), -1)
	map.rebuild_navigation()
	_check(nav.is_walkable(Vector3(4.5, 0, 2.6)), "erasing structure cells frees their navigation footprint")
	var cover := map.get_node("Props/Barricade1") as Node3D
	_check(cover.scene_file_path.ends_with("barricade.tscn"), "map cover is an editable reusable scene instance")
	var old_center := cover.global_position
	_check(not nav.is_walkable(old_center), "navigation derives blocked cells from authored cover")
	cover.position = Vector3(4, 0.8, 4)
	cover.rotation.y = PI / 4.0
	map.rebuild_navigation()
	_check(nav.is_walkable(old_center), "moving cover frees its previous navigation footprint")
	_check(not nav.is_walkable(cover.global_position), "rotated cover blocks its new navigation footprint")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for zone: SpawnZone in map.spawn_container.get_children():
		zone.enabled = false
	var entrance := map.spawn_container.get_node("NorthEntrance") as SpawnZone
	entrance.enabled = true
	entrance.width = 0
	entrance.global_position = Vector3(4, 0, 0)
	entrance.minimum_distance = 8
	_check(map.choose_spawn("walker", 1, Vector3.ZERO, rng) == null, "spawn zones reject positions too close to survivor")
	entrance.minimum_distance = 0
	entrance.first_wave = 3
	_check(map.choose_spawn("walker", 2, Vector3.ZERO, rng) == null, "spawn zones respect activation wave")
	_check(map.choose_spawn("runner", 3, Vector3.ZERO, rng) == entrance.global_position, "spawn positions follow editor marker transforms")
	_check(map.choose_spawn("boss", 3, Vector3.ZERO, rng) == null, "spawn zones filter enemy kinds")
	var remaining: int = world.session.waves.spawn_left
	entrance.enabled = false
	world.session.waves.spawn_next()
	_check(world.session.waves.spawn_left == remaining, "unavailable entrances do not discard scheduled enemies")
	map.playable_area.shape = map.playable_area.shape.duplicate()
	map.playable_area.shape.size = Vector3(50, 2, 50)
	map.rebuild_navigation()
	_check(nav.is_walkable(Vector3(22, 0, 0)), "playable bounds are read from the editable shape")
	var grenade: Grenade = world.session.combat.spawn_grenade(Vector3(22, 2, 0), Vector3.RIGHT)
	grenade.set_physics_process(false)
	grenade.velocity = Vector3.ZERO
	grenade.set_physics_process(true)
	await _frames(1)
	grenade.set_physics_process(false)
	_check(grenade.global_position.x > 21.9, "grenades are not clamped to the old fixed arena size")
	grenade.global_position = Vector3(26, 2, 0)
	grenade.velocity = Vector3.RIGHT
	grenade.set_physics_process(true)
	await _frames(1)
	grenade.set_physics_process(false)
	_check(grenade.global_position.x < 25.0 and grenade.velocity.x < 0.0, "grenades bounce at the authored playable boundary")

	map.position = Vector3(50, 0, 30)
	map.rotation.y = PI / 4.0
	world.session.player.global_position = map.player_spawn.global_position
	map.rebuild_navigation()
	_check(nav.is_walkable(map.player_spawn.global_position), "navigation supports translated and rotated map roots")
	_check(not nav.is_walkable(cover.global_position), "collision footprints follow transformed map roots")
	await _fresh_run()
	_check(world.arena.get_node("Props/Barricade1").position == Vector3(-7, 0.8, -6), "restart restores authored map geometry")
	_check(world.session.player.global_position == world.arena.player_spawn.global_position, "survivor starts at map marker")
	print("Integration: editable geometry, rotated collisions, map bounds, spawn filtering and map reset checked")


func _test_invalid_content() -> void:
	var original: PackedScene = world.map_scene
	var invalid := PackedScene.new()
	var wrong_root := Node3D.new()
	_check(invalid.pack(wrong_root) == OK, "invalid map fixture packs")
	wrong_root.free()
	world.map_scene = invalid
	world.start_run()
	_check(world.mode == world.Mode.PAUSED and paused and world.session == null, "invalid map root stops visibly before actor initialization")
	world.map_scene = original
	world.start_run()
	_check(world.mode == world.Mode.PLAYING and world.session != null, "a valid restart recovers from configuration failure")
	world.session.enemies.enemy_scenes = world.session.enemies.enemy_scenes.duplicate()
	world.session.enemies.enemy_scenes.erase("walker")
	world.session.start()
	_check(world.mode == world.Mode.PAUSED and not world.session.waves.running, "missing enemy registration stops the run instead of stalling a wave")
