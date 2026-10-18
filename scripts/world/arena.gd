@tool
class_name Arena
extends Node3D
## Editor-authored map. Geometry is the source of truth for navigation.
@export var player_spawn: Marker3D
@export var playable_area: CollisionShape3D
@export var spawn_container: Node3D
@export_range(0.25, 2.0) var navigation_cell_size: float = 1.0
@export_range(0.1, 2.0) var navigation_clearance: float = 0.75
@onready var navigation: HordeNavigation = $Navigation

func _ready() -> void:
	if not Engine.is_editor_hint():
		assert(player_spawn != null and playable_area != null and playable_area.shape is BoxShape3D and spawn_container != null, "Map needs PlayerSpawn, a box PlayableArea, and EnemySpawns.")
		rebuild_navigation()

func rebuild_navigation() -> void:
	navigation.configure_map(self, playable_area, navigation_cell_size, navigation_clearance)

func choose_spawn(kind: String, wave: int, target_position: Vector3, rng: RandomNumberGenerator) -> Variant:
	var candidates: Array[SpawnZone] = []
	var total: float = 0.0
	for child in spawn_container.get_children():
		if child is SpawnZone and child.accepts(kind, wave):
			candidates.append(child)
			total += child.weight
	for attempt in range(32):
		var roll: float = rng.randf() * total
		for zone in candidates:
			roll -= zone.weight
			if roll <= 0.0:
				var point := zone.sample(rng)
				if point.distance_to(target_position) >= zone.minimum_distance and navigation.can_reach_target(point):
					return point
				break
	return null

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if player_spawn == null:
		warnings.append("Assign a PlayerSpawn marker.")
	if playable_area == null or not playable_area.shape is BoxShape3D:
		warnings.append("Assign a PlayableArea CollisionShape3D with a BoxShape3D.")
	if spawn_container == null:
		warnings.append("Assign the container of SpawnZone markers.")
	return warnings
