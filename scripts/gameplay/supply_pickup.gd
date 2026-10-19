class_name SupplyPickup
extends Node3D
## A supply owns its lifetime, presentation and collection detection.

signal collected(kind: String)

@export_enum("health", "ammo") var kind: String = "health"
var target: Node3D
var life_left: float = 22.0
var _clock: float = 0.0
var _base_height: float = 0.5


func _ready() -> void:
	_base_height = global_position.y
	_clock = randf() * TAU
	var color: Color = Color("7fea9c") if kind == "health" else Color("ffc16c")
	PrototypeMeshes.box($Visuals, Vector3(0.65, 0.32, 0.65), Vector3.ZERO, Color("183a3b")).name = "Crate"
	PrototypeMeshes.box($Visuals, Vector3(0.45, 0.06, 0.16), Vector3(0, 0.19, 0), color, true).name = "Marking"
	if kind == "health":
		PrototypeMeshes.box($Visuals, Vector3(0.16, 0.06, 0.45), Vector3(0, 0.19, 0), color, true).name = "Cross"


func _physics_process(delta: float) -> void:
	life_left -= delta
	_clock += delta * 3.0
	rotation.y += delta
	global_position.y = _base_height + sin(_clock) * 0.12
	if is_instance_valid(target) and global_position.distance_to(target.global_position + Vector3.UP * 0.5) < 1.25:
		collected.emit(kind)
		set_physics_process(false)
		queue_free()
	elif life_left <= 0.0:
		queue_free()
