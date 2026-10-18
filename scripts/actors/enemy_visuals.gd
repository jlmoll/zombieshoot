class_name ZombieVisuals
extends Node3D
## Prototype meshes, health bar, attack warning, and animation for a zombie.

static var _materials: Dictionary = {}
static var _box: BoxMesh
static var _head: SphereMesh

var warning: MeshInstance3D
var _body: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _health_fill: MeshInstance3D
var _health_root: Node3D
var kind: String = ""
var _visual_scale: float = 1.0


func configure(enemy_kind: String, actor_scale: float) -> void:
	if kind == enemy_kind and is_equal_approx(_visual_scale, actor_scale) and is_instance_valid(_body):
		return
	kind = enemy_kind
	_visual_scale = actor_scale
	_build_visuals()


func show_warning(attack: String, progress: float) -> void:
	warning.visible = true
	var warning_radius: float = 4.3 if attack == "slam" else 1.3 * _visual_scale
	warning.scale = Vector3(warning_radius, 0.6 + progress * 2.0, warning_radius)


func hide_warning() -> void:
	warning.visible = false


func reset_health() -> void:
	_health_root.visible = kind == "boss"
	_health_fill.scale.x = 0.9 * _visual_scale
	_health_fill.position.x = 0.0


func show_health(health: float, maximum: float) -> void:
	_health_root.visible = true
	var fraction: float = clampf(health / maxf(maximum, 0.001), 0.0, 1.0)
	_health_fill.scale.x = 0.9 * _visual_scale * fraction
	_health_fill.position.x = -0.45 * _visual_scale * (1.0 - fraction)


func animate(delta: float, clock: float, speed: float, moving: float, to_target: Vector3, windup: float, flash: float) -> void:
	var facing: float = atan2(-to_target.x, -to_target.z)
	_body.rotation.y = lerp_angle(_body.rotation.y, facing, minf(delta * 10.0, 1.0))
	var stride: float = sin(clock * speed * 4.3) * minf(moving, 1.0)
	for index: int in range(_legs.size()):
		_legs[index].rotation.x = stride * 0.5 * (1.0 if index == 0 else -1.0)
	for index: int in range(_arms.size()):
		_arms[index].rotation.x = -0.9 + stride * 0.18 * (1.0 if index == 0 else -1.0)
	_body.position.y = absf(stride) * 0.055
	var squash: float = 1.0 + sin(clock * 29.0) * 0.045 if windup > 0.0 else 1.0
	var hit_scale: float = 1.0 + flash * 0.65
	_body.scale = _body.scale.lerp(Vector3(hit_scale, squash, hit_scale) * _visual_scale, minf(1.0, delta * 20.0))

static func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key: String = color.to_html() + str(glow)
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.88
	if color.a < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 1.8
	_materials[key] = result
	return result


func _part(parent: Node3D, at: Vector3, size: Vector3, color: Color, spherical: bool = false, glow: bool = false) -> MeshInstance3D:
	if _box == null:
		_box = BoxMesh.new()
		_box.size = Vector3.ONE
	if _head == null:
		_head = SphereMesh.new()
		_head.radius = 0.5
		_head.height = 1.0
		_head.radial_segments = 8
		_head.rings = 4
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _head if spherical else _box
	mesh_instance.material_override = _material(color, glow)
	mesh_instance.position = at
	mesh_instance.scale = size
	parent.add_child(mesh_instance)
	return mesh_instance


func _build_visuals() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_legs.clear()
	_arms.clear()
	_body = Node3D.new()
	_body.name = &"Body"
	_body.scale = Vector3.ONE * _visual_scale
	add_child(_body)
	var skin := Color("83ad70")
	var jacket := Color("354b47")
	match kind:
		"runner":
			skin = Color("b9b77c")
			jacket = Color("a56b30")
		"brute":
			skin = Color("b094c0")
			jacket = Color("514260")
		"spitter":
			skin = Color("b4d96b")
			jacket = Color("48775a")
		"boss":
			skin = Color("ce8f7c")
			jacket = Color("8b3946")
	_part(_body, Vector3(0, 0.97, 0), Vector3(0.68, 0.72, 0.42), jacket)
	_part(_body, Vector3(0, 1.51, -0.025), Vector3(0.54, 0.52, 0.48), skin, true)
	_part(_body, Vector3(-0.14, 1.56, -0.225), Vector3(0.08, 0.065, 0.045), Color("f7ce73"), false, true)
	_part(_body, Vector3(0.14, 1.56, -0.225), Vector3(0.08, 0.065, 0.045), Color("f7ce73"), false, true)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.19, 0.66, 0)
		_body.add_child(leg)
		_part(leg, Vector3(0, -0.3, 0), Vector3(0.23, 0.62, 0.25), Color("263b40"))
		_part(leg, Vector3(0, -0.56, -0.055), Vector3(0.27, 0.15, 0.36), Color("17272d"))
		_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.4, 1.21, -0.03)
		arm.rotation.x = -0.9
		_body.add_child(arm)
		_part(arm, Vector3(0, -0.24, 0), Vector3(0.19, 0.53, 0.21), skin)
		_arms.append(arm)
	if kind == "spitter":
		_part(_body, Vector3(0, 1.03, 0.29), Vector3(0.72, 0.7, 0.6), Color("a1d553"), true, true)
	if kind == "boss":
		for side in [-1.0, 1.0]:
			_part(_body, Vector3(side * 0.48, 1.3, 0), Vector3(0.35, 0.3, 0.51), Color("b7a18b"))
	_health_root = Node3D.new()
	_health_root.name = &"HealthBar"
	_health_root.position.y = 1.9 * _visual_scale
	add_child(_health_root)
	_part(_health_root, Vector3.ZERO, Vector3(0.95 * _visual_scale, 0.07, 0.09), Color("17252b"))
	_health_fill = _part(_health_root, Vector3(0, 0, -0.012), Vector3(0.9 * _visual_scale, 0.08, 0.09), Color("e8a46c"), false, true)
	_health_root.visible = kind == "boss"
	warning = MeshInstance3D.new()
	warning.name = &"AttackWarning"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.93
	ring.outer_radius = 1.0
	ring.rings = 32
	ring.ring_segments = 6
	warning.mesh = ring
	warning.material_override = _material(Color(1.0, 0.3, 0.12, 0.8), true)
	warning.position.y = 0.045
	warning.visible = false
	add_child(warning)
