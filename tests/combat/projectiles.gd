extends SceneTree
## Physical regressions for scene spawning, team filtering, attribution and global coordinates.

class DamageReceiver extends StaticBody3D:
	var team: DamageContext.Team = DamageContext.Team.ENEMY
	var health: float = 100.0
	var hits: int = 0
	var last_context: DamageContext

	func get_damage_team() -> DamageContext.Team:
		return team

	func take_damage(amount: float, context: DamageContext = null) -> void:
		health -= amount
		hits += 1
		last_context = context


var checks: int = 0
var failures: int = 0
var service: CombatService
var actors: Array[DamageReceiver] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("COMBAT: " + description)


func frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func receiver(at: Vector3, team: DamageContext.Team) -> DamageReceiver:
	var actor := DamageReceiver.new()
	actor.team = team
	actor.collision_layer = GameRules.PLAYER_LAYER if team == DamageContext.Team.PLAYER else GameRules.ENEMY_LAYER
	actor.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	collision.shape = shape
	actor.add_child(collision)
	root.add_child(actor)
	actor.global_position = at
	actors.append(actor)
	return actor


func run() -> void:
	service = CombatService.new()
	for child_name in ["Projectiles", "Grenades"]:
		var container := Node3D.new()
		container.name = child_name
		service.add_child(container)
	root.add_child(service)
	service.position = Vector3(30, 9, -20)
	service.rotation.y = PI * 0.37
	service.scale = Vector3.ONE * 1.7

	var carrier := receiver(Vector3(0, 1, 0), DamageContext.Team.PLAYER)
	var ally := receiver(Vector3(1, 1, 0), DamageContext.Team.PLAYER)
	var first := receiver(Vector3(2, 1, 0), DamageContext.Team.ENEMY)
	var second := receiver(Vector3(3, 1, 0), DamageContext.Team.ENEMY)
	var third := receiver(Vector3(4, 1, 0), DamageContext.Team.ENEMY)
	var weapon := Node.new()
	carrier.add_child(weapon)
	var context := DamageContext.create(weapon, carrier, DamageContext.Team.PLAYER, &"piercing")
	await frames(2)
	var bullet := service.spawn_projectile(Vector3(0, 1, 0), Vector3.RIGHT, 11, 120,
		1, context, CombatService.PLAYER_BULLET_SCENE)
	check(bullet.global_position.is_equal_approx(Vector3(0, 1, 0)),
		"projectile origin is global under translated, rotated and scaled service")
	check(bullet.scene_file_path.ends_with("player_bullet.tscn") and bullet.get_child_count() == 1,
		"projectile instantiates its complete authored scene")
	await frames(6)
	check(carrier.hits == 0 and ally.hits == 0, "player shots skip carrier and allies")
	check(first.hits == 1 and second.hits == 1 and third.hits == 0,
		"swept penetration hits exactly two enemies once at high speed")
	check(first.last_context.get_instigator() == carrier and first.last_context.get_source() == weapon,
		"impact preserves distinct source weapon and actual carrier")
	check(first.last_context.attack_id == &"piercing"
		and first.last_context.hit_direction.is_equal_approx(Vector3.RIGHT)
		and absf(first.last_context.hit_position.x - 1.7) < 0.02,
		"impact captures attack identity, contact point and world direction")
	check(first.last_context != second.last_context,
		"each penetration receives its own impact context")

	var hostile := receiver(Vector3(0, 1, 5), DamageContext.Team.ENEMY)
	var hostile_ally := receiver(Vector3(1, 1, 5), DamageContext.Team.ENEMY)
	var survivor := receiver(Vector3(2, 1, 5), DamageContext.Team.PLAYER)
	await frames(2)
	service.spawn_projectile(Vector3(0, 1, 5), Vector3.RIGHT, 9, 120, 0,
		DamageContext.create(hostile, hostile, DamageContext.Team.ENEMY, &"spit"),
		CombatService.ENEMY_BULLET_SCENE)
	await frames(5)
	check(hostile.hits == 0 and hostile_ally.hits == 0 and survivor.hits == 1,
		"hostile shots skip their team and strike the player team")
	check(survivor.last_context.get_instigator() == hostile,
		"hostile impacts attribute damage to their real enemy")

	var friendly_target := receiver(Vector3(1, 1, 10), DamageContext.Team.PLAYER)
	var friendly_context := DamageContext.create(weapon, carrier, DamageContext.Team.PLAYER, &"friendly")
	friendly_context.friendly_fire = true
	await frames(2)
	service.spawn_projectile(Vector3(0, 1, 10), Vector3.RIGHT, 7, 120, 0,
		friendly_context, CombatService.PLAYER_BULLET_SCENE)
	await frames(5)
	check(friendly_target.hits == 1, "friendly fire requires explicit context opt-in")

	var cover := StaticBody3D.new()
	cover.collision_layer = GameRules.WALL_LAYER
	var cover_collision := CollisionShape3D.new()
	var cover_shape := BoxShape3D.new()
	cover_shape.size = Vector3(0.1, 2, 2)
	cover_collision.shape = cover_shape
	cover.add_child(cover_collision)
	root.add_child(cover)
	cover.position = Vector3(1, 1, 15)
	var covered := receiver(Vector3(2, 1, 15), DamageContext.Team.ENEMY)
	await frames(2)
	service.spawn_projectile(Vector3(0, 1, 15), Vector3.RIGHT, 99, 120, 10,
		context, CombatService.PLAYER_BULLET_SCENE)
	await frames(5)
	check(covered.hits == 0, "walls stop high-speed shots even with penetration")

	var blast_target := receiver(Vector3(1, 0.6, 20), DamageContext.Team.ENEMY)
	var blast_ally := receiver(Vector3(1, 0.6, 21), DamageContext.Team.PLAYER)
	service.damage_targets.assign([blast_target, blast_ally])
	await frames(2)
	var grenade := service.spawn_grenade(Vector3(0, 0.18, 20), Vector3.RIGHT, 1.5, context)
	grenade.damage = 60.0
	grenade.blast_radius = 3.0
	check(grenade.global_position.is_equal_approx(Vector3(0, 0.18, 20)),
		"grenade origin is global under transformed and scaled parent")
	check(grenade.get_node("CollisionShape3D").shape is SphereShape3D,
		"grenade has an authored physical collider")
	grenade.detonate()
	grenade.detonate()
	check(blast_target.hits == 1 and blast_ally.hits == 0,
		"grenade damages each target once, respects teams and uses configured radius")
	check(blast_target.health < 60.0 and blast_target.health > 40.0
		and blast_target.last_context.get_instigator() == carrier,
		"explosion uses configured damage with falloff and source attribution")

	var flying := service.spawn_grenade(Vector3(0, 0.18, 30), Vector3.RIGHT, 1.5, context)
	var other := service.spawn_grenade(Vector3(0, 0.18, 35), Vector3.RIGHT, 1.5, context)
	flying.fuse_left = 10.0
	other.fuse_left = 10.0
	check(flying.get_node("Ring").material_override != other.get_node("Ring").material_override,
		"grenades own independent warning materials")
	await frames(65)
	check(flying.global_position.y >= flying.floor_height - 0.001
		and flying.global_position.y < 0.5 and flying.global_position.x > 1.0,
		"flight and floor bounce use world coordinates under parent rotation and scale")
	check(absf(flying.get_node("Ring").global_position.y - 0.04) < 0.001,
		"warning ring stays on the global floor")

	var orphan := Node.new()
	var orphan_context := DamageContext.create(orphan, orphan, DamageContext.Team.PLAYER, &"orphan")
	orphan.free()
	check(orphan_context.get_source() == null and orphan_context.get_instigator() == null,
		"damage provenance safely expires when its actor is freed")
	check(orphan_context.team == DamageContext.Team.PLAYER,
		"team remains stable after its carrier is freed")

	var firearm := load("res://scenes/weapons/shotgun.tscn").instantiate() as Weapon
	firearm.wielder = carrier
	firearm.projectile_scene = CombatService.ENEMY_BULLET_SCENE
	var emitted: Array[Dictionary] = []
	firearm.projectile_spawn_requested.connect(func(
			_origin: Vector3, _direction: Vector3, _damage: float, _speed: float,
			_pierce: int, shot_context: DamageContext, shot_scene: PackedScene
	) -> void:
		emitted.append({"context": shot_context, "scene": shot_scene})
	)
	root.add_child(firearm)
	firearm.global_position = Vector3(50, 1, 0)
	check(firearm.try_fire(Vector3.RIGHT, firearm.global_position) and emitted.size() == 7,
		"authored shotgun emits one context-bearing request per pellet")
	check(emitted[0].context.get_instigator() == carrier
		and emitted[0].context.get_source() == firearm
		and emitted[0].context.attack_id == firearm.weapon_id,
		"weapon supplies its real wielder and identity to the projectile service")
	check(emitted[0].scene == CombatService.ENEMY_BULLET_SCENE
		and emitted[0].context.team == DamageContext.Team.PLAYER,
		"weapon projectile scene is configurable independently of damage team")

	var attack := EnemyFanAttack.new()
	attack.carrier = hostile
	attack.attack_id = &"physical_fan"
	attack.projectile_count = 2
	attack.projectile_scene = CombatService.PLAYER_BULLET_SCENE
	emitted.clear()
	attack.projectile_spawn_requested.connect(func(
			_origin: Vector3, _direction: Vector3, _damage: float, _speed: float,
			_pierce: int, shot_context: DamageContext, shot_scene: PackedScene
	) -> void:
		emitted.append({"context": shot_context, "scene": shot_scene})
	)
	root.add_child(attack)
	attack.execute(Vector3.ZERO, Vector3.UP, carrier, Vector3.RIGHT, 0.0, false)
	check(emitted.size() == 2 and emitted[0].context.get_instigator() == hostile
		and emitted[0].context.get_source() == attack,
		"enemy fan propagates its actual carrier and attack source")
	check(emitted[0].scene == CombatService.PLAYER_BULLET_SCENE
		and emitted[0].context.team == DamageContext.Team.ENEMY,
		"enemy attacks configure projectile scenes independently of damage team")
	firearm.queue_free()
	attack.queue_free()
	service.queue_free()
	cover.queue_free()
	for actor in actors:
		actor.queue_free()
	await process_frame
	await process_frame
	print("COMBAT %s: %d checks, %d failures" % [
		"PASSED" if failures == 0 else "FAILED", checks, failures,
	])
	quit(0 if failures == 0 else 1)
