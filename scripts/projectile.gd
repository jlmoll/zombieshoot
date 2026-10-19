@tool
class_name Bullet
extends Node3D
## Scene-authored visuals; swept world-space rays prevent high-speed tunnelling.

signal impact_requested(at: Vector3, color: Color, count: int)

@export_range(0.1, 1000.0) var damage: float = 10.0
@export_range(0.1, 200.0) var speed: float = 30.0
@export_range(0, 100) var pierce: int = 0
@export_range(0.01, 30.0) var lifetime: float = 2.5
@export_flags_3d_physics
var hit_mask: int = GameRules.WALL_LAYER | GameRules.ENEMY_LAYER | GameRules.PLAYER_LAYER
@export var impact_color := Color(0.8, 1.0, 0.35)
var direction := Vector3.FORWARD
var damage_context: DamageContext
var _excluded: Array[RID] = []
var _configured: bool = false


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _configured:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var start: Vector3 = global_position
	var end: Vector3 = start + direction * speed * delta
	# Excluding skipped allies and pierced bodies makes every body hit at most once.
	while true:
		var query := PhysicsRayQueryParameters3D.create(start, end, hit_mask, _excluded)
		query.hit_from_inside = true
		var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			global_position = end
			return
		var collider := result["collider"] as Node
		var impact: Vector3 = result["position"]
		global_position = impact
		if collider != null and collider.has_method("take_damage"):
			if not damage_context.can_damage(collider):
				_excluded.append(result["rid"])
				continue
			collider.call("take_damage", damage, damage_context.for_hit(impact, direction))
			impact_requested.emit(impact, impact_color, 3)
			if pierce > 0:
				pierce -= 1
				_excluded.append(result["rid"])
				continue
		else:
			impact_requested.emit(impact, Color(1.0, 0.77, 0.36), 3)
		queue_free()
		return


func configure(
	origin: Vector3,
	heading: Vector3,
	hit_damage: float,
	travel_speed: float,
	context: DamageContext = null,
	penetration: int = 0
) -> void:
	# Creation services add the scene first: every origin and heading is global.
	global_position = origin
	direction = heading.normalized()
	damage = hit_damage
	speed = travel_speed
	damage_context = context if context != null else DamageContext.new()
	pierce = penetration
	_excluded.clear()
	var instigator := damage_context.get_instigator() as CollisionObject3D
	if instigator != null and not damage_context.friendly_fire:
		_excluded.append(instigator.get_rid())
	_configured = true
	if direction.length_squared() > 0.001:
		global_rotation.y = atan2(direction.x, direction.z)
	reset_physics_interpolation()


func get_configuration_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var visual := get_node_or_null("Visual") as MeshInstance3D
	if visual == null or visual.mesh == null:
		errors.append("Projectile scene needs a Visual MeshInstance3D with a mesh.")
	if damage <= 0.0 or speed <= 0.0 or lifetime <= 0.0 or pierce < 0 or hit_mask == 0:
		errors.append("Projectile damage, speed, lifetime and collision mask must be positive.")
	return errors


func _get_configuration_warnings() -> PackedStringArray:
	return get_configuration_errors()
