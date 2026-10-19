extends SceneTree
## Standalone weapon contracts: no Game, RunSession, audio or player required.

var checks: int = 0
var failures: int = 0
var shots: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("WEAPONS: " + description)


func capture(
		origin: Vector3, direction: Vector3, damage: float, speed: float, pierce: int
) -> void:
	shots.append({
		"origin": origin, "direction": direction, "damage": damage,
		"speed": speed, "pierce": pierce,
	})


func make_weapon(path: String) -> Weapon:
	var weapon := load(path).instantiate() as Weapon
	root.add_child(weapon)
	weapon.projectile_requested.connect(capture)
	return weapon


func run() -> void:
	var first := make_weapon("res://scenes/weapons/pistol.tscn")
	var second := make_weapon("res://scenes/weapons/pistol.tscn")
	var shotgun := make_weapon("res://scenes/weapons/shotgun.tscn")
	await physics_frame
	first.global_position = Vector3(4, 0, 3)
	first.rotation.y = PI * 0.5
	shots.clear()
	var origin: Vector3 = first.presentation.get_muzzle_position()
	check(first.try_fire(Vector3.RIGHT, first.global_position), "weapon fires without a player")
	check(shots.size() == 1 and shots[0].origin.is_equal_approx(origin),
		"projectile origin follows the weapon's transformed muzzle")
	check(shots[0].damage == 30.0 and shots[0].speed == 36.0,
		"authored scene properties configure the projectile")
	check(first.magazine.ammo == 11 and second.magazine.ammo == 12,
		"two instances of the same scene have independent magazines")
	check(not first.try_fire(Vector3.RIGHT, first.global_position),
		"weapon enforces cadence without a controller")
	check(first.start_reload(), "partially empty weapon can reload")
	first.advance(0.4)
	check(first.magazine.reloading and first.magazine.ammo == 11,
		"reload does not refill early")
	first.magazine.cancel_reload()
	first.advance(2.0)
	check(first.magazine.ammo == 11, "cancelled reload never grants ammunition")
	first.start_reload()
	first.advance(0.91)
	check(first.magazine.ammo == 12 and not first.magazine.reloading,
		"completed reload refills only its own magazine")
	shots.clear()
	shotgun.damage = 23.0
	shotgun.penetration = 2
	shotgun.presentation.muzzle.position = Vector3(0.2, 0.1, 0.8)
	check(shotgun.try_fire(Vector3.FORWARD, shotgun.global_position),
		"shotgun uses the same Weapon contract")
	check(shots.size() == 7 and shotgun.magazine.ammo == 5,
		"spread consumes one cartridge while emitting seven pellets")
	for shot in shots:
		check(shot.damage == 23.0 and shot.pierce == 2,
			"instance configuration applies to every pellet")
		check(shot.origin.is_equal_approx(shotgun.presentation.get_muzzle_position()),
			"custom muzzle position controls every pellet origin")
		check(is_equal_approx(shot.direction.length(), 1.0), "pellet direction is normalized")
	check(shotgun.presentation.flash.visible, "weapon owns its muzzle flash")
	shotgun.advance(0.1)
	check(not shotgun.presentation.flash.visible, "flash duration expires with weapon time")
	var actor := load("res://scenes/actors/player.tscn").instantiate() as Survivor
	root.add_child(actor)
	actor.set_physics_process(false)
	var controller: WeaponController = actor.weapon_controller
	var pistol: Weapon = controller.current_weapon
	check(pistol.get_parent() == actor.visuals.get_weapon_socket(),
		"entire weapon including its model is mounted on the animated socket")
	check(controller.try_fire(Vector3.RIGHT, actor.global_position), "equipped weapon fires")
	controller.start_reload()
	controller.select_weapon(1)
	check(not pistol.magazine.reloading and pistol.magazine.ammo == 11,
		"switching cancels reload without losing or refilling ammunition")
	check(not controller.try_fire(Vector3.RIGHT, actor.global_position),
		"switching cannot bypass the previous weapon cadence")
	controller.advance(0.23)
	check(controller.try_fire(Vector3.RIGHT, actor.global_position),
		"new weapon fires after switch and cadence lockout expire")
	controller.apply_upgrade("damage")
	controller.apply_upgrade("reload")
	controller.apply_upgrade("magazine")
	controller.apply_upgrade("pierce")
	check(pistol.damage == 30.0 and pistol.magazine_capacity == 12,
		"upgrades never mutate the scene's base configuration")
	check(pistol.damage_multiplier == 1.25 and pistol.magazine.capacity == 15,
		"upgrades affect owned weapon state")
	check(second.magazine.capacity == 12 and second.damage_multiplier == 1.0,
		"upgrades do not leak to another instance")
	controller.reset()
	check(controller.selected_index == 0 and pistol.magazine.capacity == 12,
		"reset restores authored loadout and magazine capacity")
	check(pistol.damage_multiplier == 1.0 and pistol.penetration_bonus == 0,
		"reset removes transient modifiers")
	paused = true
	check(not first.try_fire(Vector3.RIGHT, first.global_position), "paused weapon cannot fire")
	check(not first.start_reload(), "paused weapon cannot start reloading")
	paused = false
	for node in [first, second, shotgun, actor]:
		node.queue_free()
	await process_frame
	await process_frame
	print("WEAPONS %s: %d checks, %d failures" % [
		"PASSED" if failures == 0 else "FAILED", checks, failures,
	])
	quit(0 if failures == 0 else 1)
