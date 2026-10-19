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

## Identificador incluido en el contexto de daño para reconocer qué ataque causó el impacto.
@export var attack_id: StringName = &"attack"
## Escena Bullet utilizada por los ataques que emiten proyectiles.
## La escena define su aspecto; el ataque proporciona daño, velocidad y portador.
@export var projectile_scene: PackedScene = preload("res://scenes/projectiles/enemy_bullet.tscn")
## Distancia mínima al objetivo, en metros, para iniciar el ataque. El límite está incluido.
@export_range(0.0, 50.0) var minimum_distance: float = 0.0
## Distancia máxima al objetivo, en metros, para iniciar el ataque. El límite queda excluido.
@export_range(0.0, 1000.0) var maximum_distance: float = 15.0
## Segundos de preparación y aviso visual antes de ejecutar el ataque.
@export_range(0.01, 5.0) var windup_duration: float = 0.65
## Segundos mínimos entre inicios de ataque. Se cuenta desde el comienzo del aviso,
## por lo que incluye el tiempo de preparación de windup_duration.
@export_range(0.01, 20.0) var cooldown: float = 2.7
## Radio en metros del aviso visual. No cambia el alcance real del daño del ataque.
@export_range(0.0, 20.0) var warning_radius: float = 1.3
## Multiplica el radio del aviso por visual_scale del enemigo; no modifica el daño.
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
