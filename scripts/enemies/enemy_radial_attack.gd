class_name EnemyRadialAttack
extends EnemyAttack
## Reusable radial projectile pattern with an optional enraged density.

## Número de proyectiles repartidos por todo el círculo en el patrón normal.
@export_range(1, 100) var projectile_count: int = 12
## Número de proyectiles del patrón radial cuando el enemigo tiene menos del 50 % de vida.
## El anillo secundario del golpe Slam utiliza siempre projectile_count.
@export_range(1, 100) var enraged_count: int = 18
## Daño de cada proyectil del anillo.
@export_range(0.1, 500.0) var damage: float = 13.0
## Velocidad de los proyectiles en metros por segundo.
@export_range(0.1, 50.0) var projectile_speed: float = 5.0
## Multiplicador de la fase temporal que orienta el patrón radial entre ataques.
## Con 0, el primer proyectil siempre apunta hacia el eje global +X.
@export_range(0.0, 5.0) var rotation_rate: float = 0.6
## Intensidad de sacudida de cámara solicitada al emitir el anillo: de 0 a 1.
@export_range(0.0, 1.0) var trauma: float = 0.16


func execute(
	_source: Vector3,
	origin: Vector3,
	_target: Node3D,
	_locked_target: Vector3,
	phase: float,
	enraged: bool
) -> void:
	var count: int = enraged_count if enraged else projectile_count
	for index in range(count):
		var angle: float = TAU * float(index) / float(count) + phase * rotation_rate
		emit_projectile(origin, Vector3(cos(angle), 0, sin(angle)), damage, projectile_speed)
	trauma_requested.emit(trauma)
