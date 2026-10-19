@tool
class_name Arena
extends Node3D
## Editor-authored map. Geometry is the source of truth for navigation.
@export var player_spawn: Marker3D
@export var playable_area: CollisionShape3D
@export var spawn_container: Node3D
@export_range(0.25, 2.0) var navigation_cell_size: float = 1.0
@export_range(0.1, 2.0) var navigation_clearance: float = 0.75
@onready var navigation: HordeNavigation = get_node_or_null("Navigation") as HordeNavigation

func _ready() -> void:
	if not Engine.is_editor_hint():
		if get_configuration_errors().is_empty():
			rebuild_navigation()

func rebuild_navigation() -> void:
	navigation.configure_map(self, playable_area, navigation_cell_size, navigation_clearance)

func choose_spawn(kind: String, wave: int, target_position: Vector3, rng: RandomNumberGenerator) -> Variant:
	# Every factory-facing position, including the result, is in global coordinates.
	if not is_instance_valid(spawn_container) or not is_instance_valid(navigation):
		return null
	var candidates: Array[SpawnZone] = []
	var total: float = 0.0
	for child in spawn_container.get_children():
		if child is SpawnZone and child.accepts(kind, wave):
			candidates.append(child)
			total += child.weight
	if candidates.is_empty():
		return null
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

func has_spawn_for(kind: String, wave: int) -> bool:
	if not is_instance_valid(spawn_container):
		return false
	for child in spawn_container.get_children():
		if child is SpawnZone and child.accepts(kind, wave):
			return true
	return false


func get_configuration_errors() -> PackedStringArray:
	var warnings := PackedStringArray()
	if player_spawn == null:
		warnings.append("Assign a PlayerSpawn marker.")
	elif not is_ancestor_of(player_spawn):
		warnings.append("PlayerSpawn must belong to this arena.")
	if playable_area == null or not playable_area.shape is BoxShape3D:
		warnings.append("Assign a PlayableArea CollisionShape3D with a BoxShape3D.")
	elif not is_ancestor_of(playable_area):
		warnings.append("PlayableArea must belong to this arena.")
	if spawn_container == null:
		warnings.append("Assign the container of SpawnZone markers.")
	elif not is_ancestor_of(spawn_container):
		warnings.append("EnemySpawns must belong to this arena.")
	else:
		var enabled_zones: int = 0
		for child in spawn_container.get_children():
			if child is SpawnZone:
				warnings.append_array(child.get_configuration_errors())
				if child.enabled and child.weight > 0.0:
					enabled_zones += 1
		if enabled_zones == 0:
			warnings.append("Arena has no enabled spawn entrances with positive weight.")
	if not get_node_or_null("Navigation") is HordeNavigation:
		warnings.append("Arena needs a HordeNavigation child named Navigation.")
	return warnings


func _get_configuration_warnings() -> PackedStringArray:
	return get_configuration_errors()
