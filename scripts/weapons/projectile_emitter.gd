class_name ProjectileEmitter
extends Node
## Standard ballistic pattern. Override get_directions for a different shot pattern.

signal projectile_requested(
	origin: Vector3, direction: Vector3, damage: float, speed: float, pierce: int
)
signal projectile_spawn_requested(
	origin: Vector3,
	direction: Vector3,
	damage: float,
	speed: float,
	pierce: int,
	context: DamageContext,
	scene: PackedScene
)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func emit_shot(
	origin: Vector3,
	heading: Vector3,
	damage: float,
	speed: float,
	pierce: int,
	pellets: int,
	spread: float,
	pellet_jitter: float,
	context: DamageContext = null,
	scene: PackedScene = null
) -> void:
	for direction in get_directions(heading, pellets, spread, pellet_jitter):
		projectile_requested.emit(origin, direction, damage, speed, pierce)
		projectile_spawn_requested.emit(origin, direction, damage, speed, pierce, context, scene)


func get_directions(
	heading: Vector3, pellets: int, spread: float, pellet_jitter: float
) -> Array[Vector3]:
	var directions: Array[Vector3] = []
	for pellet in range(maxi(1, pellets)):
		var angle: float = _rng.randf_range(-spread, spread)
		if pellets > 1:
			angle = lerpf(-spread, spread, float(pellet) / float(pellets - 1))
			angle += _rng.randf_range(-pellet_jitter, pellet_jitter)
		directions.append(heading.rotated(Vector3.UP, angle).normalized())
	return directions
