@tool
class_name Grenade
extends CharacterBody3D
## Timed bouncing scene. Positions, velocity and floor height use world coordinates.

signal detonated(at: Vector3, damage: float, radius: float)
signal blast_requested(at: Vector3, damage: float, radius: float, context: DamageContext)

@export_range(0.01, 30.0) var fuse_duration: float = 1.2
@export_range(0.1, 50.0) var blast_radius: float = 4.2
@export_range(0.1, 10000.0) var damage: float = 160.0
@export_range(0.0, 100.0) var gravity: float = 18.0
@export_range(0.0, 1.0) var wall_bounce: float = 0.45
@export var floor_height: float = 0.18
var fuse_left: float = 1.2
var exploded: bool = false
var damage_context: DamageContext
var playable_area: CollisionShape3D
@onready var _model: MeshInstance3D = $Model
@onready var _ring: MeshInstance3D = $Ring
@onready var _ring_material: StandardMaterial3D = _ring.material_override


func _ready() -> void:
	fuse_left = fuse_duration
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_ring.scale = Vector3(blast_radius, 0.12, blast_radius)
	_update_ring()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or exploded:
		return
	fuse_left -= delta
	velocity.y -= gravity * delta
	var collision: KinematicCollision3D = move_and_collide(velocity * delta)
	if collision != null:
		velocity = velocity.bounce(collision.get_normal()) * wall_bounce
	# Contain airborne grenades using the authored map bounds, above low walls too.
	if is_instance_valid(playable_area) and playable_area.shape is BoxShape3D:
		var box := playable_area.shape as BoxShape3D
		var local_point := playable_area.to_local(global_position)
		var local_velocity := playable_area.global_basis.inverse() * velocity
		for axis in [0, 2]:
			var limit: float = maxf(0.0, box.size[axis] * 0.5 - 0.2)
			if absf(local_point[axis]) > limit:
				local_point[axis] = clampf(local_point[axis], -limit, limit)
				local_velocity[axis] = (
					-signf(local_point[axis]) * absf(local_velocity[axis]) * wall_bounce
				)
		global_position = playable_area.to_global(local_point)
		velocity = playable_area.global_basis * local_velocity
	if global_position.y < floor_height:
		global_position.y = floor_height
		velocity.y = -velocity.y * 0.25 if velocity.y < -1.2 else 0.0
		velocity.x *= 0.28
		velocity.z *= 0.28
		velocity.x = move_toward(velocity.x, 0.0, delta * 28.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 28.0)
	_model.rotate_z(delta * 8.0)
	_update_ring()
	_ring_material.albedo_color.a = (
		0.35 + 0.35 * (0.5 + 0.5 * sin((fuse_duration - fuse_left) * 35.0))
	)
	if fuse_left <= 0.0:
		detonate()


func configure(
	origin: Vector3, direction: Vector3, distance: float = 9.0, context: DamageContext = null
) -> void:
	global_position = origin
	damage_context = context if context != null else DamageContext.new()
	fuse_left = fuse_duration
	# Flight to the floor takes about 0.68 s from the survivor's hand.
	velocity = direction.normalized() * (clampf(distance, 1.5, 10.0) / 0.68)
	velocity.y = 5.0
	_update_ring()
	reset_physics_interpolation()


func get_configuration_errors() -> PackedStringArray:
	var warnings := PackedStringArray()
	var collider := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider == null or collider.shape == null:
		warnings.append("Grenade scene needs a CollisionShape3D with a shape.")
	var model := get_node_or_null("Model") as MeshInstance3D
	if model == null or model.mesh == null:
		warnings.append("Grenade scene needs a Model MeshInstance3D with a mesh.")
	var ring := get_node_or_null("Ring") as MeshInstance3D
	if ring == null or ring.mesh == null or ring.material_override is not StandardMaterial3D:
		warnings.append("Grenade scene needs a Ring with a StandardMaterial3D override.")
	if fuse_duration <= 0.0 or blast_radius <= 0.0 or damage <= 0.0 or gravity < 0.0:
		warnings.append(
			"Grenade fuse, radius and damage must be positive; gravity cannot be negative."
		)
	return warnings


func detonate() -> void:
	if exploded:
		return
	exploded = true
	set_physics_process(false)
	_model.hide()
	blast_requested.emit(global_position, damage, blast_radius, damage_context)
	detonated.emit(global_position, damage, blast_radius)
	_ring.scale = Vector3(0.15, 0.12, 0.15)
	_ring_material.albedo_color = Color(1.0, 0.8, 0.4, 1.0)
	var tween: Tween = create_tween().set_parallel(true)
	(
		tween
		. tween_property(_ring, "scale", Vector3(blast_radius, 0.12, blast_radius), 0.25)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(_ring_material, "albedo_color:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)


func _get_configuration_warnings() -> PackedStringArray:
	return get_configuration_errors()


func _update_ring() -> void:
	if is_instance_valid(_ring):
		_ring.global_position = Vector3(global_position.x, 0.04, global_position.z)
