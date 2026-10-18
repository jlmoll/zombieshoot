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
	world._start_run()
	world.spawn_left = 999
	world.spawn_clock = 10000.0
	world.player.invulnerability = 0.0
	await _frames(2)


func _clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	world._clear_projectiles()
	await _frames(2)


func _stationary_enemy(kind: String, at: Vector3) -> Node3D:
	var enemy: Node3D = world._spawn_enemy(kind, at)
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
	world.muted = true
	_check(world.mode == "title" and paused, "title pauses the simulation")
	await _test_lifecycle_and_player()
	await _test_projectile_physics()
	await _test_grenades()
	await _test_enemy_navigation_and_attacks()
	await _test_progression()
	await _finish()


func _test_lifecycle_and_player() -> void:
	await _fresh_run()
	_check(world.mode == "playing" and not paused and world.wave == 1, "start begins wave one")
	_check(world.player.health == 100.0 and world.player.weapons.size() == 3, "fresh survivor has full health and three weapons")
	# Exercise the real input dispatch, including events sent by embedded windows.
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	_check(world.player.weapon_index == 1, "logical key event selects shotgun through viewport input")
	key.pressed = false
	Input.parse_input_event(key)
	key = InputEventKey.new()
	key.keycode = KEY_Q
	key.physical_keycode = KEY_Q
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	_check(world.player.weapon_index == 2, "physical key event cycles weapon through viewport input")
	key.pressed = false
	Input.parse_input_event(key)
	key = InputEventKey.new()
	key.keycode = KEY_1
	key.physical_keycode = KEY_TAB
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	_check(world.player.weapon_index == 0, "hotkey uses visible logical label when remapped scan code differs")
	key.pressed = false
	Input.parse_input_event(key)
	key = InputEventKey.new()
	key.keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	var start_position: Vector3 = world.player.position
	await _frames(10)
	key.pressed = false
	Input.parse_input_event(key)
	_check(world.player.position.x > start_position.x + 0.3 and world.player.position.z < start_position.z - 0.3, "logical movement key travels right relative to isometric camera")
	world.player.position = Vector3.ZERO
	world.player.select_weapon(0)
	await _frames(10)
	world._pause()
	var elapsed_before: float = world.elapsed
	await _frames(4)
	_check(paused and world.mode == "paused" and world.elapsed == elapsed_before, "pause stops gameplay time")
	world._resume()
	_check(not paused and world.is_gameplay_active(), "resume restores gameplay")
	var player: Node3D = world.player
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
	var ammo_before: int = player.ammo
	player.try_shoot()
	_check(player.ammo == ammo_before - 1 and not get_nodes_in_group("projectiles").is_empty(), "shoot consumes ammo and creates projectile")
	player.try_shoot()
	_check(player.ammo == ammo_before - 1, "fire interval prevents extra immediate shot")
	player.select_weapon(1)
	_check(player.magazine_size == 6 and player.ammo == 6, "shotgun has independent magazine")
	player.select_weapon(0)
	_check(player.ammo == ammo_before - 1, "weapon switch preserves ammo")
	player.start_reload()
	_check(player.reloading, "manual reload starts")
	await _frames(70)
	_check(not player.reloading and player.ammo == player.magazine_size, "reload completes and refills magazine")
	player.reset_state()
	player.take_damage(75.0)
	player.apply_upgrade("health")
	_check(player.max_health == 125.0 and player.health == 125.0, "health upgrade raises maximum and fully restores life as offered")
	player.apply_upgrade("damage")
	_check(is_equal_approx(player.damage_multiplier, 1.25), "damage upgrade provides advertised 25 percent")
	player.apply_upgrade("speed")
	_check(is_equal_approx(player.speed_multiplier, 1.15), "speed upgrade provides advertised 15 percent")
	player.apply_upgrade("fire_rate")
	_check(is_equal_approx(player.fire_rate_multiplier, 1.2), "fire-rate upgrade provides advertised 20 percent")
	player.apply_upgrade("reload")
	_check(is_equal_approx(player.reload_multiplier, 0.8), "reload upgrade reduces reload duration 20 percent")
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
	player.ammo = 0
	world._spawn_drop(Vector3.ZERO, "health")
	world._spawn_drop(Vector3.ZERO, "ammo")
	await _frames(3)
	_check(player.health == 55.0 and player.ammo == player.magazine_size and world.drops.is_empty(), "health and ammo pickups apply and disappear")
	print("Integration: survivor, weapons, upgrades, dash, pickups and pause checked")


func _test_projectile_physics() -> void:
	await _fresh_run()
	var player: Node3D = world.player
	player.set_physics_process(false)
	var enemy: Node3D = _stationary_enemy("walker", Vector3(4, 0, 0))
	await _frames(2)
	world.spawn_player_bullet(Vector3(1, 0.8, 0), Vector3.RIGHT, 12.0, 80.0)
	await _frames(8)
	_check(is_equal_approx(enemy.health, enemy.max_health - 12.0), "swept friendly projectile hits enemy exactly once")
	_check(player.health == 100.0, "friendly projectile cannot harm survivor")
	await _clear_enemies()
	var first: Node3D = _stationary_enemy("walker", Vector3(4, 0, 2))
	var second: Node3D = _stationary_enemy("walker", Vector3(7, 0, 2))
	await _frames(2)
	world.spawn_player_bullet(Vector3(1, 0.8, 2), Vector3.RIGHT, 10.0, 120.0, 1)
	await _frames(8)
	_check(first.health == first.max_health - 10.0 and second.health == second.max_health - 10.0, "penetration hits two bodies once each")
	await _clear_enemies()
	var covered: Node3D = _stationary_enemy("walker", Vector3(7, 0, -10))
	await _frames(2)
	world.spawn_player_bullet(Vector3(7, 0.8, -4), Vector3.FORWARD, 99.0, 150.0)
	await _frames(8)
	_check(covered.health == covered.max_health and get_nodes_in_group("projectiles").is_empty(), "solid cover blocks and destroys fast projectile")
	await _clear_enemies()
	var ignored: Node3D = _stationary_enemy("walker", Vector3(2, 0, 0))
	await _frames(2)
	player.invulnerability = 0.0
	world.spawn_enemy_bullet(Vector3(4, 0.8, 0), Vector3.LEFT, 9.0, 80.0)
	await _frames(8)
	_check(player.health == 91.0 and ignored.health == ignored.max_health, "hostile projectile ignores zombies and hits survivor")
	await _clear_enemies()
	var kills_before: int = world.kills
	for kind in ["walker", "runner", "brute", "spitter", "boss"]:
		var target: Node3D = _stationary_enemy(kind, Vector3(5, 0, -4))
		target.take_damage(100000.0)
		target.take_damage(100000.0)
	_check(world.kills == kills_before + 5, "every archetype reports exactly one death")
	await _frames(2)
	_check(world._living_enemies() == 0, "dead archetypes leave active enemy population")
	print("Integration: projectile masks, continuous collisions, cover, penetration and death checked")


func _test_enemy_navigation_and_attacks() -> void:
	await _fresh_run()
	world.player.set_physics_process(false)
	world.player.position = Vector3(7, 0, -11)
	world.player.invulnerability = 1000.0
	world._build_flow()
	var walker: Node3D = world._spawn_enemy("walker", Vector3(7, 0, -3))
	var crossed_cover: bool = false
	for step in range(75):
		await _frames(6)
		for rect: Rect2 in world.obstacles:
			if rect.grow(-0.75).has_point(Vector2(walker.position.x, walker.position.z)):
				crossed_cover = true
	_check(not crossed_cover, "horde AI navigates around solid cover")
	_check(walker.position.distance_to(world.player.position) < 3.5, "horde flow navigation reaches survivor behind crate")
	await _clear_enemies()
	world.player.position = Vector3.ZERO
	world._build_flow()
	var spitter: Node3D = world._spawn_enemy("spitter", Vector3(0, 0, -9))
	spitter._attack_cooldown = 0.0
	await _frames(5)
	_check(spitter._windup > 0.0 and spitter._warning.visible, "spitter attack has visible windup")
	await _frames(45)
	_check(get_nodes_in_group("projectiles").size() >= 3, "spitter fires three-projectile fan after windup")
	await _clear_enemies()
	var boss: Node3D = world._spawn_enemy("boss", Vector3(0, 0, -10))
	boss._attack_cooldown = 0.0
	await _frames(5)
	_check(boss._windup > 0.0 and boss._warning.visible, "boss attack has visible windup")
	await _frames(52)
	_check(get_nodes_in_group("projectiles").size() >= 10, "boss emits radial projectile pattern")
	await _clear_enemies()
	world.player.health = 100.0
	world.player.invulnerability = 0.0
	var slammer: Node3D = world._spawn_enemy("boss", Vector3(0, 0, -3))
	slammer._attack_cooldown = 0.0
	await _frames(5)
	_check(slammer._attack == "slam" and slammer._warning.visible, "nearby boss telegraphs area slam")
	await _frames(60)
	_check(world.player.health == 74.0, "slam deals advertised area damage after windup")
	print("Integration: obstacle routing, telegraphs, ranged AI and boss patterns checked")


func _test_grenades() -> void:
	await _fresh_run()
	var player: Node3D = world.player
	_check(player.grenades == 2, "first wave grants two grenades")
	_check(world.hud._grenades.text.contains("2 / 4"), "HUD displays grenade inventory and cap")
	player._mouse_active = false
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
	world._pause()
	var fuse_before: float = grenade.fuse_left
	var position_before: Vector3 = grenade.position
	await _frames(30)
	_check(grenade.fuse_left == fuse_before and grenade.position == position_before, "pause freezes grenade fuse and flight")
	_check(not player.try_throw_grenade(), "grenades cannot be thrown while paused")
	world._resume()
	await _frames(110)
	_check(world.kills == 2, "timed explosion kills multiple enemies in its radius")
	_check(outside.health == outside.max_health, "explosion leaves distant enemies unharmed")
	_check(player.health == player.max_health, "grenades do not cause self damage")
	_check(get_nodes_in_group("grenades").is_empty(), "exploded grenade cleans up after its visual effect")
	await _clear_enemies()
	var near: Node3D = _stationary_enemy("brute", Vector3(1, 0, 0))
	var direct: Node3D = world.spawn_grenade(Vector3(0, 0.18, 0), Vector3.RIGHT)
	direct.detonate()
	var remaining_health: float = near.health
	direct.detonate()
	_check(near.health < near.max_health and near.health == remaining_health, "detonation damages each enemy only once")
	_check(player.health == player.max_health, "point-blank detonation remains safe for survivor")
	await _clear_enemies()
	var covered: Node3D = _stationary_enemy("walker", Vector3(7, 0, -9))
	await _frames(2)
	world.detonate_grenade(Vector3(7, 0.18, -4), 160.0, 7.0)
	_check(covered.health == covered.max_health, "solid cover blocks grenade blast")
	var bouncing: Node3D = world.spawn_grenade(Vector3(17.3, 0.95, 0), Vector3.RIGHT)
	await _frames(8)
	_check(bouncing.position.x < 17.8 and bouncing.velocity.x < 0, "grenade bounces from arena boundary")
	world._clear_projectiles()
	await _frames(2)
	_check(get_nodes_in_group("grenades").is_empty(), "wave cleanup removes unexploded grenades")
	player.grenades = 0
	player._grenade_left = 0.0
	_check(not player.try_throw_grenade() and player.grenades == 0, "empty inventory cannot throw or become negative")
	for supply in [[0, 2], [1, 3], [3, 4], [4, 4]]:
		player.grenades = supply[0]
		world._start_wave()
		_check(player.grenades == supply[1], "wave adds two grenades capped at four from inventory %d" % supply[0])
	await _fresh_run()
	_check(world.player.grenades == 2 and get_nodes_in_group("grenades").is_empty(), "restart resets stock to first-wave allowance and clears grenades")
	print("Integration: grenade input, flight, fuse, pause, blast, cover, cleanup and replenishment checked")


func _test_progression() -> void:
	world._start_run()
	world.player.set_physics_process(false)
	world.player.invulnerability = 1000.0
	await _frames(2)
	for expected_wave in range(1, 9):
		_check(world.wave == expected_wave, "wave advances in sequence: %d" % expected_wave)
		_check(world.player.grenades == mini(4, expected_wave * 2), "actual wave transition replenishes grenades with a hard cap")
		while world.spawn_left > 0:
			world._spawn_next()
		var expected_enemies: int = 9 + expected_wave * 5 + (1 if expected_wave in [4, 8] else 0)
		_check(world._living_enemies() == expected_enemies, "wave %d schedules complete population including bosses" % expected_wave)
		world.spawn_enemy_bullet(Vector3(16, 0.8, 16), Vector3.LEFT, 1.0, 1.0)
		for enemy in get_nodes_in_group("enemies"):
			if enemy.get_parent() == world.runtime:
				enemy.take_damage(100000.0)
		await _frames(4)
		_check(get_nodes_in_group("projectiles").is_empty(), "wave end clears hostile projectiles")
		if expected_wave < 8:
			_check(world.mode == "upgrades" and paused, "cleared wave pauses for upgrade choice")
			var damage_before: float = world.player.damage_multiplier
			world._choose_upgrade("damage")
			_check(world.mode == "playing" and not paused and world.player.damage_multiplier > damage_before, "upgrade choice applies and resumes intermission")
			world.intermission = 0.01
			await _frames(3)
	_check(world.mode == "victory" and paused and world.wave == 8, "eighth cleared wave ends in victory")
	_check(world.kills == 254 and world.score > 0, "complete run rewards all 254 scheduled enemies")
	world._start_run()
	await _frames(2)
	_check(world.mode == "playing" and world.wave == 1 and world.kills == 0 and world.player.health == 100.0, "restart creates clean survivor and score after victory")
	world.player.invulnerability = 0.0
	world.player.take_damage(10000.0)
	_check(world.mode == "dead" and paused, "fatal damage ends and pauses run")
	world._start_run()
	await _frames(2)
	_check(world.mode == "playing" and not paused and world.player.health == 100.0 and world.score == 0, "restart after death resets run")
	print("Integration: all eight waves, upgrades, victory, death and restart checked")
