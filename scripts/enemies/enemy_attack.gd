class_name EnemyAttack
extends Node
## Base attack contract. Inherited attack nodes implement only their payload.

signal projectile_requested(origin: Vector3, direction: Vector3, damage: float, speed: float)
signal particles_requested(at: Vector3, color: Color, count: int)
signal trauma_requested(amount: float)

@export var attack_id: StringName = &"attack"
@export_range(0.0, 50.0) var minimum_distance: float = 0.0
@export_range(0.0, 1000.0) var maximum_distance: float = 15.0
@export_range(0.01, 5.0) var windup_duration: float = 0.65
@export_range(0.01, 20.0) var cooldown: float = 2.7
@export_range(0.0, 20.0) var warning_radius: float = 1.3
@export var scale_warning_with_model: bool = true


func can_start(distance: float) -> bool:
	return distance >= minimum_distance and distance < maximum_distance


func execute(
		_source: Vector3, _origin: Vector3, _target: Node3D,
		_locked_target: Vector3, _phase: float, _enraged: bool
) -> void:
	pass
