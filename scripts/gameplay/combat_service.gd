class_name CombatService
extends Node3D
## Owns projectiles and resolves explosions against the injected enemy roster.

const BULLET_SCRIPT = preload("res://scripts/projectile.gd")
const GRENADE_SCRIPT = preload("res://scripts/grenade.gd")

@onready var projectiles: Node3D = $Projectiles
@onready var grenades: Node3D = $Grenades
var enemies: EnemySpawner
var effects: ImpactEffects
var audio: GameAudio
var camera_rig: IsometricCameraRig


func spawn_player_bullet(origin: Vector3, direction: Vector3, damage: float, speed: float, pierce: int = 0) -> void:
	_spawn_bullet(origin, direction, damage, speed, true, pierce)


func spawn_enemy_bullet(origin: Vector3, direction: Vector3, damage: float, speed: float) -> void:
	_spawn_bullet(origin, direction, damage, speed, false, 0)


func _spawn_bullet(origin: Vector3, direction: Vector3, damage: float, speed: float, friendly: bool, pierce: int) -> void:
	var bullet: Bullet = BULLET_SCRIPT.new()
	bullet.name = "PlayerBullet" if friendly else "EnemyBullet"
	bullet.configure(origin, direction, damage, speed, friendly, pierce)
	bullet.impact_requested.connect(effects.spawn_particles)
	projectiles.add_child(bullet, true)
	bullet.add_to_group("projectiles")


func spawn_grenade(origin: Vector3, direction: Vector3, distance: float = 9.0) -> Grenade:
	var grenade: Grenade = GRENADE_SCRIPT.new()
	grenade.name = "Grenade"
	grenade.configure(origin, direction, distance)
	grenade.detonated.connect(detonate_grenade)
	grenades.add_child(grenade, true)
	return grenade


func detonate_grenade(at: Vector3, damage: float, radius: float) -> void:
	if get_tree().paused:
		return
	var center := Vector3(at.x, maxf(0.35, at.y), at.z)
	for enemy: Zombie in enemies.get_children():
		if enemy.dead:
			continue
		var target: Vector3 = enemy.global_position + Vector3.UP * 0.6
		var distance: float = Vector2(target.x - center.x, target.z - center.z).length()
		if distance > radius:
			continue
		var query := PhysicsRayQueryParameters3D.create(center, target, GameRules.WALL_LAYER)
		query.hit_from_inside = true
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			enemy.take_damage(damage * lerpf(1.0, 0.7, distance / radius))
	effects.spawn_particles(center, Color("ffc16c"), 12)
	camera_rig.add_trauma(0.65)
	audio.play_sound("explosion")


func clear_projectiles() -> void:
	for container: Node3D in [projectiles, grenades]:
		for projectile in container.get_children():
			projectile.queue_free()
