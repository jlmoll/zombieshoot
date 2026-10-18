class_name ZombieVisuals
extends Node3D
## Blender model, health bar, attack warning, and animation for a zombie.

const DEATH_PLAYBACK_SPEED: float = 2.5

static var _materials: Dictionary = {}
static var _box: BoxMesh
static var _head: SphereMesh

var warning: MeshInstance3D
var _body: Node3D
var _model: Node3D
var _variant_details: Node3D
var _generated: Node3D
var _animation: AnimationPlayer
var _dying: bool = false
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
	if _dying:
		return
	if _animation.current_animation != "Attack" or not _animation.is_playing():
		_play_clip("Walk" if moving > 0.1 else "Idle", clampf(speed / 2.1, 0.65, 1.8) if moving > 0.1 else 1.0)
	var hit_scale: float = 1.0 + flash * 0.65
	_body.scale = _body.scale.lerp(Vector3(hit_scale, 1.0, hit_scale) * _visual_scale, minf(1.0, delta * 20.0))


func _play_clip(clip: StringName, rate: float = 1.0) -> void:
	if _animation.current_animation != clip or not _animation.is_playing():
		_animation.play(clip, 0.1, rate)


func play_attack(windup_duration: float = 0.0) -> void:
	if _dying:
		return
	# The authored impact is at 47% of the attack clip.
	var rate: float = 1.0
	if windup_duration > 0.0:
		rate = _animation.get_animation("Attack").length * 0.47 / windup_duration
	_animation.play("Attack", 0.08, rate)


func play_death() -> float:
	_dying = true
	hide_warning()
	_health_root.hide()
	_variant_details.hide()
	_body.scale = Vector3.ONE * _visual_scale
	_animation.play("Death", 0.04, DEATH_PLAYBACK_SPEED)
	return _animation.get_animation("Death").length / DEATH_PLAYBACK_SPEED


func _variant_colors() -> Dictionary:
	match kind:
		"runner":
			return {"skin": Color("b9b77c"), "cloth": Color("a56b30")}
		"brute":
			return {"skin": Color("b094c0"), "cloth": Color("514260")}
		"spitter":
			return {"skin": Color("b4d96b"), "cloth": Color("48775a")}
		"boss":
			return {"skin": Color("ce8f7c"), "cloth": Color("8b3946")}
	return {"skin": Color("afc5af"), "cloth": Color("297c89")}


func _apply_variant_materials(model: Node3D) -> void:
	var palette: Dictionary = _variant_colors()
	var skin: Color = palette["skin"]
	var cloth: Color = palette["cloth"]
	var meshes: Array[Node] = [model]
	meshes.append_array(model.find_children("*", "MeshInstance3D", true, false))
	for node: Node in meshes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
			continue
		var source: Material = mesh_instance.get_active_material(0)
		if source == null:
			continue
		var material_copy: StandardMaterial3D = source.duplicate() as StandardMaterial3D
		if material_copy == null:
			continue
		var material_name: String = material_copy.resource_name.to_lower()
		if material_name.contains("skin | sage"):
			material_copy.albedo_color = skin
		elif material_name.contains("skin | socket shadow"):
			material_copy.albedo_color = skin.darkened(0.45)
		elif material_name.contains("cloth | petrol shirt"):
			material_copy.albedo_color = cloth
		elif material_name.contains("cloth | torn olive lining"):
			material_copy.albedo_color = cloth.lightened(0.45)
		mesh_instance.material_override = material_copy

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
	_body = get_node("Body") as Node3D
	_model = get_node("Body/ZombieModel") as Node3D
	_variant_details = get_node("Body/VariantDetails") as Node3D
	_generated = get_node("GeneratedVisuals") as Node3D
	for child: Node in _variant_details.get_children():
		_variant_details.remove_child(child)
		child.queue_free()
	for child: Node in _generated.get_children():
		_generated.remove_child(child)
		child.queue_free()
	_body.scale = Vector3.ONE * _visual_scale
	_body.position = Vector3.ZERO
	_apply_variant_materials(_model)
	_animation = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# Imported resources are shared: make the animation library local before changing loops.
	var library: AnimationLibrary = _animation.get_animation_library("").duplicate(true) as AnimationLibrary
	_animation.remove_animation_library("")
	_animation.add_animation_library("", library)
	for clip: StringName in [&"Idle", &"Walk"]:
		_animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_play_clip("Idle")
	if kind == "spitter":
		_part(_variant_details, Vector3(0, 1.12, 0.33), Vector3(0.36, 0.4, 0.34), Color("a1d553"), true, true)
	if kind == "boss":
		for side in [-1.0, 1.0]:
			_part(_variant_details, Vector3(side * 0.42, 1.34, 0), Vector3(0.18, 0.34, 0.2), Color("b7a18b"), true)
	_health_root = Node3D.new()
	_health_root.name = &"HealthBar"
	_health_root.position.y = 2.3 * _visual_scale
	_generated.add_child(_health_root)
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
	_generated.add_child(warning)
