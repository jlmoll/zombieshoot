class_name Grenade
extends CharacterBody3D
## Timed, bouncing projectile. Its fuse and effects follow the gameplay pause.

const FUSE: float = 1.2
const BLAST_RADIUS: float = 4.2
const DAMAGE: float = 160.0
const GRAVITY: float = 18.0
const FLOOR_HEIGHT: float = 0.18

var fuse_left: float = FUSE
var exploded: bool = false
var _model: MeshInstance3D
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D


func configure(origin: Vector3, direction: Vector3, distance: float = 9.0) -> void:
	position = origin
	# Flight to the floor takes about 0.68 s from the survivor's hand.
	velocity = direction.normalized() * (clampf(distance, 1.5, 10.0) / 0.68)
	velocity.y = 5.0


func _ready() -> void:
	add_to_group("grenades")
	collision_layer = 0
	collision_mask = 2
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.16
	collision.shape = shape
	add_child(collision)
	_model = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	mesh.radial_segments = 10
	mesh.rings = 5
	_model.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffc16c")
	material.emission_enabled = true
	material.emission = Color("bf6b25")
	_model.material_override = material
	add_child(_model)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.98
	torus.outer_radius = 1.0
	torus.rings = 40
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.scale = Vector3(BLAST_RADIUS, 0.12, BLAST_RADIUS)
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.albedo_color = Color(1.0, 0.65, 0.25, 0.35)
	_ring.material_override = _ring_material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_update_ring()


func _physics_process(delta: float) -> void:
	if exploded:
		return
	fuse_left -= delta
	velocity.y -= GRAVITY * delta
	var collision: KinematicCollision3D = move_and_collide(velocity * delta)
	if collision != null:
		velocity = velocity.bounce(collision.get_normal()) * 0.45
	# The low visual perimeter must contain grenades even at the top of the arc.
	for axis in [0, 2]:
		if absf(position[axis]) > 17.8:
			position[axis] = clampf(position[axis], -17.8, 17.8)
			velocity[axis] = -signf(position[axis]) * absf(velocity[axis]) * 0.45
	if position.y < FLOOR_HEIGHT:
		position.y = FLOOR_HEIGHT
		velocity.y = -velocity.y * 0.25 if velocity.y < -1.2 else 0.0
		velocity.x *= 0.28
		velocity.z *= 0.28
		velocity.x = move_toward(velocity.x, 0.0, delta * 28.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 28.0)
	_model.rotate_z(delta * 8.0)
	_update_ring()
	_ring_material.albedo_color.a = 0.35 + 0.35 * (0.5 + 0.5 * sin((FUSE - fuse_left) * 35.0))
	if fuse_left <= 0.0:
		detonate()


func _update_ring() -> void:
	_ring.position.y = 0.04 - global_position.y


func detonate() -> void:
	if exploded:
		return
	exploded = true
	set_physics_process(false)
	_model.hide()
	get_tree().current_scene.detonate_grenade(global_position, DAMAGE, BLAST_RADIUS)
	_ring.scale = Vector3(0.15, 0.12, 0.15)
	_ring_material.albedo_color = Color(1.0, 0.8, 0.4, 1.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_ring, "scale", Vector3(BLAST_RADIUS, 0.12, BLAST_RADIUS), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ring_material, "albedo_color:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)
