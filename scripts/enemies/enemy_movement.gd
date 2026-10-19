class_name EnemyMovement
extends Node
## Shared pursuit, optional standoff movement and separation from an injected roster.

@export_range(0.01, 2.0) var navigation_interval: float = 0.22
@export_range(0.0, 1.0) var navigation_jitter: float = 0.08
@export var keep_distance: bool = false
@export_range(0.0, 30.0) var retreat_distance: float = 4.7
@export_range(0.0, 30.0) var orbit_distance: float = 7.0
@export_range(0.0, 5.0) var orbit_frequency: float = 0.55
@export_range(0.0, 2.0) var separation_margin: float = 0.12
@export_range(0.0, 10.0) var separation_strength: float = 3.8
@export_range(0.0, 10.0) var maximum_separation: float = 3.0
var navigation: HordeNavigation
var neighbors: Callable
var separation := Vector3.ZERO
var _navigation_remaining: float = 0.0
var _direction := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_navigation_remaining = _rng.randf() * navigation_interval


func get_direction(delta: float, actor: Zombie, target_position: Vector3, phase: float) -> Vector3:
	var difference: Vector3 = target_position - actor.global_position
	difference.y = 0.0
	var heading := difference.normalized()
	_navigation_remaining -= delta
	if _navigation_remaining <= 0.0:
		_navigation_remaining = navigation_interval + _rng.randf() * navigation_jitter
		_direction = heading
		if is_instance_valid(navigation):
			_direction = navigation.get_direction(actor.global_position, target_position)
		_direction.y = 0.0
		_direction = _direction.normalized()
		_update_separation(actor)
	if keep_distance:
		if difference.length() < retreat_distance:
			return -heading
		if difference.length() < orbit_distance:
			return Vector3(-heading.z, 0, heading.x) * sin(phase * orbit_frequency)
	return _direction


func _update_separation(actor: Zombie) -> void:
	separation = Vector3.ZERO
	if not neighbors.is_valid():
		return
	for other: Zombie in neighbors.call():
		if not is_instance_valid(other) or other == actor or other.dead:
			continue
		var gap: Vector3 = actor.global_position - other.global_position
		gap.y = 0.0
		var spacing: float = actor.radius + other.radius + separation_margin
		var distance: float = gap.length()
		if distance < spacing and distance > 0.01:
			separation += gap / distance * (spacing - distance) * separation_strength
	separation = separation.limit_length(maximum_separation)
