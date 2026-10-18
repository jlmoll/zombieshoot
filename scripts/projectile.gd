class_name Bullet
extends Node3D
## Swept rays prevent tunnelling even at high projectile speed or low framerates.

signal impact_requested(at: Vector3, color: Color, count: int)

var direction := Vector3.FORWARD
var damage: float = 10.0
var speed: float = 30.0
var friendly: bool = true
var pierce: int = 0
var lifetime: float = 2.5
var _excluded: Array[RID] = []
var _configured: bool = false
var _visual: MeshInstance3D


func configure(origin: Vector3, heading: Vector3, hit_damage: float, travel_speed: float, is_friendly: bool = true, penetration: int = 0) -> void:
	position = origin
	direction = heading.normalized()
	damage = hit_damage
	speed = travel_speed
	friendly = is_friendly
	pierce = penetration
	_configured = true
	if direction.length_squared() > 0.001:
		rotation.y = atan2(direction.x, direction.z)
	if is_instance_valid(_visual):
		_apply_material()


func _ready() -> void:
	_visual = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.045 if friendly else 0.13
	mesh.height = 0.4 if friendly else 0.28
	_visual.mesh = mesh
	_visual.rotation.x = PI * 0.5
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)
	_apply_material()


func _apply_material() -> void:
	var material := StandardMaterial3D.new()
	var color := Color(1.0, 0.83, 0.3) if friendly else Color(1.0, 0.24, 0.4)
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	_visual.material_override = material


func _physics_process(delta: float) -> void:
	if not _configured:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var start: Vector3 = global_position
	var end: Vector3 = start + direction * speed * delta
	var mask: int = GameRules.WALL_LAYER | (GameRules.ENEMY_LAYER if friendly else GameRules.PLAYER_LAYER)
	# Repeat after penetration, excluding each struck body exactly once.
	for attempt: int in range(16):
		var query := PhysicsRayQueryParameters3D.create(start, end, mask, _excluded)
		query.hit_from_inside = true
		var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			global_position = end
			return
		var collider: Object = result["collider"] as Object
		var impact: Vector3 = result["position"]
		global_position = impact
		if collider != null and collider.has_method("take_damage"):
			collider.call("take_damage", damage)
			_impact(impact, Color(0.8, 1.0, 0.35) if friendly else Color(1.0, 0.3, 0.25), 3)
			if pierce > 0 and friendly:
				pierce -= 1
				var body_rid: RID = result["rid"]
				_excluded.append(body_rid)
				start = impact + direction * 0.001
				continue
		else:
			_impact(impact, Color(1.0, 0.77, 0.36), 3)
		queue_free()
		return
	global_position = end


func _impact(point: Vector3, color: Color, count: int) -> void:
	impact_requested.emit(point, color, count)
