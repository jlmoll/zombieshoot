class_name EnemyAttack
extends Node
## Base attack contract. Inherited attack nodes implement only their payload.

signal projectile_requested(origin: Vector3, direction: Vector3, damage: float, speed: float)
signal projectile_spawn_requested(
	origin: Vector3,
	direction: Vector3,
	damage: float,
	speed: float,
	pierce: int,
	context: DamageContext,
	scene: PackedScene
)
signal particles_requested(at: Vector3, color: Color, count: int)
signal trauma_requested(amount: float)

@export var attack_id: StringName = &"attack"
@export var projectile_scene: PackedScene = preload("res://scenes/projectiles/enemy_bullet.tscn")
@export_range(0.0, 50.0) var minimum_distance: float = 0.0
@export_range(0.0, 1000.0) var maximum_distance: float = 15.0
@export_range(0.01, 5.0) var windup_duration: float = 0.65
@export_range(0.01, 20.0) var cooldown: float = 2.7
@export_range(0.0, 20.0) var warning_radius: float = 1.3
@export var scale_warning_with_model: bool = true
var carrier: Node


func make_damage_context() -> DamageContext:
	var team: DamageContext.Team = DamageContext.Team.ENEMY
	if is_instance_valid(carrier) and carrier.has_method("get_damage_team"):
		team = carrier.get_damage_team()
	return DamageContext.create(self, carrier, team, attack_id)


func emit_projectile(origin: Vector3, direction: Vector3, damage: float, speed: float) -> void:
	projectile_requested.emit(origin, direction, damage, speed)
	projectile_spawn_requested.emit(
		origin, direction, damage, speed, 0, make_damage_context(), projectile_scene
	)


func can_start(distance: float) -> bool:
	return distance >= minimum_distance and distance < maximum_distance


func execute(
	_source: Vector3,
	_origin: Vector3,
	_target: Node3D,
	_locked_target: Vector3,
	_phase: float,
	_enraged: bool
) -> void:
	pass
