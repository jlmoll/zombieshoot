@tool
class_name SpawnZone
extends Marker3D
## Place and rotate this marker; its local X axis defines the entrance width.
@export_range(0.0, 40.0) var width: float = 26.0:
	set(value):
		width = value
		gizmo_extents = 0.5
		_refresh_preview()
@export_range(0.0, 10.0) var weight: float = 1.0
@export_range(1, 100) var first_wave: int = 1
@export var enabled: bool = true
@export var enemy_kinds: Array[String] = ["walker", "runner", "spitter", "brute"]
@export_range(0.0, 40.0) var minimum_distance: float = 8.0

func accepts(kind: String, wave: int) -> bool:
	return enabled and weight > 0.0 and wave >= first_wave and kind in enemy_kinds

func sample(rng: RandomNumberGenerator) -> Vector3:
	return to_global(Vector3(rng.randf_range(-width * 0.5, width * 0.5), 0, 0))


func _ready() -> void:
	_refresh_preview()

func _refresh_preview() -> void:
	var preview := get_node_or_null("WidthPreview") as MeshInstance3D
	if preview != null:
		preview.visible = Engine.is_editor_hint()
		preview.scale.x = maxf(width, 0.1)
