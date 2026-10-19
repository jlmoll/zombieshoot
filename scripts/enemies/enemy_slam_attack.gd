class_name EnemySlamAttack
extends EnemyAttack
## Close-range impact with a projectile ring; reuses the radial attack payload.

## Radio real de daño directo en metros desde la posición del enemigo hasta su objetivo.
## Es independiente del radio del aviso visual y de los proyectiles del anillo.
@export_range(0.1, 30.0) var impact_radius: float = 4.3
## Daño directo al objetivo si permanece dentro de impact_radius al terminar el aviso.
@export_range(0.1, 500.0) var impact_damage: float = 26.0
## Color de las partículas del golpe contra el suelo.
@export var impact_color := Color("e9a06a")
## Cantidad de partículas solicitadas; el servicio de efectos puede limitarla.
@export_range(0, 100) var particle_count: int = 28
## Ataque radial hijo que emite el anillo secundario. Sus parámetros ajustan ese anillo.
## Debe pertenecer a esta escena para superar la validación de contenido.
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
