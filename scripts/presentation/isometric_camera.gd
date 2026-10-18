class_name IsometricCameraRig
extends Node3D
## Camera framing, follow smoothing and screen shake have their own lifecycle.

@onready var camera: Camera3D = $Camera
var target: Node3D
var title_mode: bool = true
var trauma: float = 0.0
var _focus: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	camera.look_at(Vector3.ZERO)


func reset() -> void:
	_focus = Vector3.ZERO
	trauma = 0.0


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func _process(delta: float) -> void:
	var destination := Vector3.ZERO
	if not title_mode and is_instance_valid(target):
		destination = target.global_position * 0.76
	_focus = _focus.lerp(destination, 1.0 - exp(-delta * 5.0))
	trauma = maxf(0.0, trauma - delta * 1.7)
	var shake := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.4, 0.4), _rng.randf_range(-1, 1)) * trauma * trauma * 0.28
	camera.position = _focus + Vector3(23, 28, 23) + shake
	camera.look_at(_focus)
	camera.size = lerpf(camera.size, 34.0 if title_mode else 26.0, 1.0 - exp(-delta * 3.0))
