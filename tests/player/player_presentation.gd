extends SceneTree
## Exercise actual scene, imported animation and shot origins without changing user saves.
var checks: int = 0
var failures: int = 0
var shots: Array[Vector3] = []


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)


func capture_shot(
	origin: Vector3, _direction: Vector3, _damage: float, _speed: float, _pierce: int
) -> void:
	shots.append(origin)


func run() -> void:
	var player: Survivor = load("res://scenes/actors/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var v: SurvivorVisuals = player.visuals
	var ap: AnimationPlayer = v._animation
	for clip in ["Idle", "Walk", "Aim", "Dash", "Reload", "Death"]:
		check(ap.has_animation(clip), "Player must import " + clip)
	for clip in ["Idle", "Walk", "Aim"]:
		check(
			ap.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, "Looping locomotion " + clip
		)
	check(is_equal_approx(v._model.scale.y, 0.9), "Technician retains compact game scale")
	v.animate(0.1, Vector3.FORWARD, 6.4, 0.0, 0.0, Vector3.RIGHT)
	check(ap.current_animation == "Walk", "Movement plays walk")
	check(
		v._lower_body.global_basis.z.normalized().dot(Vector3.RIGHT) > 0.99,
		"Legs face travel independently of aim"
	)
	check(
		v._upper_body.global_basis.z.normalized().dot(Vector3.FORWARD) > 0.99,
		"Torso remains aimed during strafe"
	)
	v.animate(0.1, Vector3.FORWARD, 6.4, 0.0, 0.0, Vector3.BACK)
	check(ap.speed_scale < 0.0, "Backpedal reverses gait without turning away")
	v.animate(0.1, Vector3.FORWARD, 0.0, 0.0, 0.0)
	check(
		ap.current_animation == "Idle" and ap.speed_scale > 0,
		"Stopping restores idle and forward playback"
	)
	v.animate(0.1, Vector3.FORWARD, 0.0, 0.0, 0.0, Vector3.ZERO, true, 0.5)
	check(ap.current_animation == "Reload", "Reload state selects authored clip")
	check(
		absf(ap.current_animation_position - ap.get_animation("Reload").length * 0.5) < 0.01,
		"Reload follows actual ammo progress"
	)
	v.animate(0.1, Vector3.FORWARD, 22.0, 0.0, 0.15, Vector3.FORWARD)
	check(ap.current_animation == "Dash" and v.visible, "Dash uses authored pose and stays visible")
	v.reset_pose()
	player.bullet_requested.connect(capture_shot)
	for weapon in range(3):
		player.select_weapon(weapon)
		player.weapon_controller.advance(1.0)
		player.aim_direction = Vector3.RIGHT
		v.set_aim(player.aim_direction)
		var muzzle: Vector3 = (
			player.weapon_controller.current_weapon.presentation.get_muzzle_position()
		)
		shots.clear()
		player.try_shoot()
		check(
			shots.size() == player.weapon_controller.weapons[weapon].pellets,
			"Weapon %d keeps pellet count" % weapon
		)
		for origin: Vector3 in shots:
			check(origin.distance_to(muzzle) < 0.001, "Projectiles originate at rendered muzzle")
		check(
			player.weapon_controller.current_weapon.presentation.flash.visible,
			"Shot shows muzzle flash"
		)
		check(player.weapon_controller.weapons[weapon].visible, "Selected weapon appears")
	v.reset_pose()
	v._animation.advance(0.0)
	var initial_height: float = v._model.find_child("Head_Pivot", true, false).global_position.y
	player.invulnerability = 0.0
	player.take_damage(99999.0)
	check(v._dying and ap.current_animation == "Death", "Fatal damage starts death")
	paused = true
	await create_timer(0.85, true).timeout
	var fallen_height: float = v._model.find_child("Head_Pivot", true, false).global_position.y
	check(
		fallen_height < initial_height * 0.6, "Death finishes even when game over pauses gameplay"
	)
	paused = false
	player.reset_state()
	check(
		not v._dying and v.process_mode == Node.PROCESS_MODE_INHERIT and v.visible,
		"Restart restores normal visual lifecycle"
	)
	player.queue_free()
	await process_frame
	print(
		(
			"PLAYER PRESENTATION %s: %d checks, %d failures"
			% ["PASSED" if failures == 0 else "FAILED", checks, failures]
		)
	)
	quit(0 if failures == 0 else 1)
