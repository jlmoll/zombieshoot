class_name EnemyFanAttack
extends EnemyAttack
## Aimed projectile fan, locked to the target position at telegraph start.

@export_range(1, 50) var projectile_count: int = 3
@export_range(0.0, 3.14) var spread: float = 0.17
@export_range(0.1, 500.0) var damage: float = 10.0
@export_range(0.1, 50.0) var projectile_speed: float = 6.5


func execute(
		source: Vector3, origin: Vector3, _target: Node3D,
		locked_target: Vector3, _phase: float, _enraged: bool
) -> void:
	var direction: Vector3 = locked_target - source
	direction.y = 0.0
	direction = direction.normalized()
	for index in range(projectile_count):
		var angle: float = 0.0
		if projectile_count > 1:
			angle = lerpf(-spread, spread, float(index) / float(projectile_count - 1))
		emit_projectile(origin, direction.rotated(Vector3.UP, angle),
			damage, projectile_speed)
