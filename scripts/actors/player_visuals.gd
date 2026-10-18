class_name SurvivorVisuals
extends Node3D
## Owns the survivor's prototype meshes and all presentation animation.

var _gun: Node3D
var _flash: MeshInstance3D
var _body_material: StandardMaterial3D
var _flash_left: float = 0.0
var _recoil: float = 0.0
var _walk_phase: float = 0.0


func _ready() -> void:
	_build_model()


func set_aim(direction: Vector3) -> void:
	rotation.y = atan2(direction.x, direction.z)


func set_weapon(index: int) -> void:
	if is_instance_valid(_gun):
		_gun.scale = Vector3(1.35, 1.15, 1.25) if index == 1 else Vector3.ONE


func show_shot(index: int) -> void:
	_flash_left = 0.055
	_recoil = 0.14 if index == 1 else 0.07


func reset_pose() -> void:
	_flash_left = 0.0
	_recoil = 0.0
	_walk_phase = 0.0
	position = Vector3.ZERO
	rotation.z = 0.0
	visible = true


func animate(delta: float, direction: Vector3, movement_speed: float, invulnerability: float, dash_remaining: float) -> void:
	_flash_left = maxf(0.0, _flash_left - delta)
	_recoil = move_toward(_recoil, 0.0, delta * 2.5)
	_walk_phase += delta * movement_speed * 1.8
	set_aim(direction)
	position.y = absf(sin(_walk_phase)) * 0.055 if movement_speed > 0.2 else 0.0
	rotation.z = sin(_walk_phase) * 0.045 if movement_speed > 0.2 else 0.0
	_gun.position.z = -_recoil
	_flash.visible = _flash_left > 0.0
	visible = invulnerability <= 0.0 or dash_remaining > 0.0 or fmod(invulnerability, 0.12) < 0.075
	_body_material.emission_enabled = dash_remaining > 0.0
	_body_material.emission = Color(0.1, 0.7, 0.8)
	_body_material.emission_energy_multiplier = 1.0

func _material(color: Color, emission: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	return material


func _mesh(parent: Node3D, mesh: Mesh, location: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	parent.add_child(instance)
	return instance


func _build_model() -> void:
	_body_material = _material(Color(0.12, 0.67, 0.78))
	var torso := CapsuleMesh.new()
	torso.radius = 0.3
	torso.height = 0.8
	_mesh(self, torso, Vector3(0, 0.67, 0), _body_material)
	var head := SphereMesh.new()
	head.radius = 0.235
	head.height = 0.47
	_mesh(self, head, Vector3(0, 1.22, 0), _material(Color(0.91, 0.75, 0.52)))
	var visor := BoxMesh.new()
	visor.size = Vector3(0.37, 0.12, 0.1)
	_mesh(self, visor, Vector3(0, 1.25, 0.21), _material(Color(0.025, 0.1, 0.15)))
	var boot := BoxMesh.new()
	boot.size = Vector3(0.22, 0.28, 0.32)
	var dark: Material = _material(Color(0.04, 0.1, 0.13))
	_mesh(self, boot, Vector3(-0.17, 0.15, 0), dark)
	_mesh(self, boot, Vector3(0.17, 0.15, 0), dark)
	_gun = Node3D.new()
	add_child(_gun)
	var receiver := BoxMesh.new()
	receiver.size = Vector3(0.18, 0.18, 0.6)
	_mesh(_gun, receiver, Vector3(0.15, 0.85, 0.49), _material(Color(0.18, 0.23, 0.28)))
	var barrel := BoxMesh.new()
	barrel.size = Vector3(0.09, 0.09, 0.25)
	_mesh(_gun, barrel, Vector3(0.15, 0.85, 0.84), dark)
	var flash := SphereMesh.new()
	flash.radius = 0.16
	flash.height = 0.22
	_flash = _mesh(_gun, flash, Vector3(0.15, 0.85, 1.0), _material(Color(1.0, 0.79, 0.2), true))
	_flash.visible = false
