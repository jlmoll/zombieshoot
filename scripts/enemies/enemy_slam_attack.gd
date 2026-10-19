class_name EnemySlamAttack
extends EnemyAttack
## Close-range impact with a projectile ring; reuses the radial attack payload.

@export_range(0.1, 30.0) var impact_radius: float = 4.3
@export_range(0.1, 500.0) var impact_damage: float = 26.0
@export var impact_color := Color("e9a06a")
@export_range(0, 100) var particle_count: int = 28
@export var ring: EnemyRadialAttack


func execute(
	source: Vector3,
	origin: Vector3,
	target: Node3D,
	locked_target: Vector3,
	phase: float,
	_enraged: bool
) -> void:
	particles_requested.emit(source + Vector3.UP * 0.1, impact_color, particle_count)
	if is_instance_valid(target) and source.distance_to(target.global_position) < impact_radius:
		var context := make_damage_context()
		if target.has_method("take_damage") and context.can_damage(target):
			target.take_damage(
				impact_damage,
				context.for_hit(target.global_position, target.global_position - source)
			)
	if ring != null:
		ring.execute(source, origin, target, locked_target, phase, false)
