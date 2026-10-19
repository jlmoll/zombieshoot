extends SceneTree
## Perk parameters drive receivers; authored content remains shared and unchanged.

var checks: int = 0
var failures: int = 0
var death_events: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("PERKS: " + description)


func run() -> void:
	var SCENE := preload("res://scenes/actors/player.tscn")
	var first := SCENE.instantiate() as Survivor
	var second := SCENE.instantiate() as Survivor
	root.add_child(first)
	root.add_child(second)
	first.set_physics_process(false)
	second.set_physics_process(false)
	var damage: PerkDefinition = PerkCatalog.find("damage")
	first.apply_perk(damage)
	first.apply_perk(damage)
	first.apply_upgrade("speed")
	first.apply_upgrade("movement")
	check(
		is_equal_approx(first.weapon_controller.current_weapon.damage_multiplier, 1.5625),
		"repeated damage perks accumulate in equipment state"
	)
	check(
		is_equal_approx(first.speed_multiplier, 1.3225),
		"legacy aliases use the same authored movement definition"
	)
	check(
		(
			second.speed_multiplier == 1.0
			and second.weapon_controller.current_weapon.damage_multiplier == 1.0
		),
		"perk effects do not leak to another survivor"
	)
	check(
		damage.damage_multiplier == 1.25,
		"applying a shared definition never mutates its parameters"
	)
	first.take_damage(40.0)
	first.apply_upgrade("health")
	check(
		first.max_health == 125.0 and first.health == 125.0,
		"maximum-health perk restores the survivor after increasing capacity"
	)
	var custom := PerkDefinition.new()
	custom.id = &"custom_parameters"
	custom.move_speed_multiplier = 1.4
	custom.dash_cooldown_multiplier = 0.5
	custom.max_health_bonus = 10.0
	custom.damage_multiplier = 2.0
	custom.magazine_multiplier = 1.5
	custom.refill_ammo = true
	first.apply_perk(custom)
	check(
		(
			is_equal_approx(first.speed_multiplier, 1.3225 * 1.4)
			and first.dash_multiplier == 0.5
			and first.max_health == 135.0
		),
		"custom definitions apply parameters without a hardcoded perk ID"
	)
	check(
		(
			first.weapon_controller.current_weapon.magazine.capacity == 18
			and first.weapon_controller.current_weapon.magazine.ammo == 18
		),
		"equipment applies authored magazine and refill parameters"
	)
	first.reset_state()
	check(
		(
			first.health == 100.0
			and first.max_health == 100.0
			and first.speed_multiplier == 1.0
			and first.dash_multiplier == 1.0
			and first.weapon_controller.current_weapon.damage_multiplier == 1.0
			and first.weapon_controller.current_weapon.magazine.capacity == 12
		),
		"restart clears actor and equipment effects together"
	)
	var hostile := DamageContext.create(second, second, DamageContext.Team.ENEMY, &"test")
	first.died.connect(func(): death_events += 1)
	first.take_damage(200.0, hostile)
	first.take_damage(200.0, hostile)
	first.heal(100.0)
	check(
		first.health == 0.0 and death_events == 1 and first.last_damage_context == hostile,
		"actor preserves accepted damage attribution and presents one death"
	)
	first.reset_state()
	var friendly := DamageContext.create(second, second, DamageContext.Team.PLAYER, &"test")
	first.take_damage(20.0, friendly)
	check(
		first.health == 100.0 and first.last_damage_context == null,
		"team checks reject friendly damage without recording an impact"
	)
	check(
		GameRules.upgrades.size() == 6 and GameRules.upgrades[0] == damage.get_choice(),
		"the UI reads identities and descriptions from the same perk definitions"
	)
	first.queue_free()
	second.queue_free()
	await process_frame
	await process_frame
	print(
		(
			"PERKS %s: %d checks, %d failures"
			% [
				"PASSED" if failures == 0 else "FAILED",
				checks,
				failures,
			]
		)
	)
	quit(0 if failures == 0 else 1)
