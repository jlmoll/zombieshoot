class_name CombatService
extends Node3D
## Spawns authored scenes at global coordinates and resolves team-aware explosions.

const PLAYER_BULLET_SCENE := preload("res://scenes/projectiles/player_bullet.tscn")
const ENEMY_BULLET_SCENE := preload("res://scenes/projectiles/enemy_bullet.tscn")
const GRENADE_SCENE := preload("res://scenes/projectiles/grenade.tscn")
@export var grenade_scene: PackedScene = GRENADE_SCENE
var playable_area: CollisionShape3D
var enemies: EnemySpawner
var effects: ImpactEffects
var audio: GameAudio
var camera_rig: IsometricCameraRig
var damage_targets: Array[Node3D] = []
@onready var projectiles: Node3D = $Projectiles
@onready var grenades: Node3D = $Grenades


func spawn_player_bullet(
	origin: Vector3, direction: Vector3, damage: float, speed: float, pierce: int = 0
) -> void:
	spawn_projectile(
		origin,
		direction,
		damage,
		speed,
		pierce,
		DamageContext.create(null, null, DamageContext.Team.PLAYER),
		PLAYER_BULLET_SCENE
	)


func spawn_enemy_bullet(origin: Vector3, direction: Vector3, damage: float, speed: float) -> void:
	spawn_projectile(
		origin,
		direction,
		damage,
		speed,
		0,
		DamageContext.create(null, null, DamageContext.Team.ENEMY),
		ENEMY_BULLET_SCENE
	)


func spawn_projectile(
	origin: Vector3,
	direction: Vector3,
	damage: float,
	speed: float,
	pierce: int,
	context: DamageContext,
	scene: PackedScene = PLAYER_BULLET_SCENE
) -> Bullet:
	if scene == null:
		push_error("Cannot spawn a projectile without a PackedScene.")
		return null
	var instance := scene.instantiate()
	if instance is not Bullet:
		push_error("Projectile scene root must extend Bullet: " + scene.resource_path)
		instance.free()
		return null
	var bullet := instance as Bullet
	var errors := bullet.get_configuration_errors()
	if not errors.is_empty():
		push_error("Invalid projectile scene: " + "; ".join(errors))
		bullet.free()
		return null
	projectiles.add_child(bullet, true)
	bullet.configure(origin, direction, damage, speed, context, pierce)
	if is_instance_valid(effects):
		bullet.impact_requested.connect(effects.spawn_particles)
	return bullet


func spawn_grenade(
	origin: Vector3,
	direction: Vector3,
	distance: float = 9.0,
	context: DamageContext = null,
	scene: PackedScene = null
) -> Grenade:
	var packed: PackedScene = scene if scene != null else grenade_scene
	if packed == null:
		push_error("Cannot spawn a grenade without a PackedScene.")
		return null
	var instance := packed.instantiate()
	if instance is not Grenade:
		push_error("Grenade scene root must extend Grenade: " + packed.resource_path)
		instance.free()
		return null
	var grenade := instance as Grenade
	var errors := grenade.get_configuration_errors()
	if not errors.is_empty():
		push_error("Invalid grenade scene: " + "; ".join(errors))
		grenade.free()
		return null
	grenade.playable_area = playable_area
	grenades.add_child(grenade, true)
	var provenance: DamageContext = (
		context
		if context != null
		else DamageContext.create(null, null, DamageContext.Team.PLAYER, &"grenade")
	)
	grenade.configure(origin, direction, distance, provenance)
	grenade.blast_requested.connect(detonate_grenade)
	return grenade


func detonate_grenade(
	at: Vector3, damage: float, radius: float, context: DamageContext = null
) -> void:
	if get_tree().paused or radius <= 0.0:
		return
	var provenance: DamageContext = (
		context
		if context != null
		else DamageContext.create(null, null, DamageContext.Team.PLAYER, &"grenade")
	)
	var center := Vector3(at.x, maxf(0.35, at.y), at.z)
	var candidates: Array[Node] = []
	if is_instance_valid(enemies):
		candidates.append_array(enemies.get_children())
	for target in damage_targets:
		if is_instance_valid(target) and target not in candidates:
			candidates.append(target)
	for candidate in candidates:
		var actor := candidate as Node3D
		if actor == null or not actor.has_method("take_damage") or not provenance.can_damage(actor):
			continue
		var target: Vector3 = actor.global_position + Vector3.UP * 0.6
		var distance: float = Vector2(target.x - center.x, target.z - center.z).length()
		if distance > radius:
			continue
		var query := PhysicsRayQueryParameters3D.create(center, target, GameRules.WALL_LAYER)
		query.hit_from_inside = true
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			actor.call(
				"take_damage",
				damage * lerpf(1.0, 0.7, distance / radius),
				provenance.for_hit(target, target - center)
			)
	if is_instance_valid(effects):
		effects.spawn_particles(center, Color("ffc16c"), 12)
	if is_instance_valid(camera_rig):
		camera_rig.add_trauma(0.65)
	if is_instance_valid(audio):
		audio.play_sound("explosion")


func clear_projectiles() -> void:
	for container: Node3D in [projectiles, grenades]:
		for projectile in container.get_children():
			projectile.queue_free()
