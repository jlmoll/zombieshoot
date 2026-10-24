@tool
extends Weapon
## Repeated contact cuts; the shared controller supplies held-trigger cadence.

@export_group("Melee")
@export_range(0.2, 3.0) var reach: float = 1.35
@export_range(0.1, 2.0) var cut_width: float = 0.65
var _cut_shape := BoxShape3D.new()


func try_fire(heading: Vector3, wielder_position: Vector3) -> bool:
	if not is_inside_tree() or get_tree().paused or cooldown_remaining > 0.0:
		return false
	var direction := Vector3(heading.x, 0.0, heading.z).normalized()
	if direction.length_squared() < 0.001:
		return false
	cooldown_remaining = fire_interval / maxf(0.01, fire_rate_multiplier)
	var start := wielder_position + Vector3.UP * 0.75
	_cut_shape.size = Vector3(cut_width, 1.0, reach)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _cut_shape
	query.transform = Transform3D(
		Basis(Vector3.UP, atan2(direction.x, direction.z)), start + direction * (reach * 0.5 + 0.1)
	)
	query.collision_mask = GameRules.ENEMY_LAYER | GameRules.PLAYER_LAYER
	var context := DamageContext.create(self, wielder, _get_wielder_team(), weapon_id)
	var damaged: Array[Node] = []
	var space := get_world_3d().direct_space_state
	for hit in space.intersect_shape(query, 128):
		var target := hit["collider"] as Node3D
		if target == null or target in damaged or not target.has_method("take_damage"):
			continue
		if not context.can_damage(target):
			continue
		var contact := Vector3(target.global_position.x, start.y, target.global_position.z)
		var wall_query := PhysicsRayQueryParameters3D.create(start, contact, obstruction_mask)
		wall_query.hit_from_inside = true
		if not space.intersect_ray(wall_query).is_empty():
			continue
		damaged.append(target)
		target.call("take_damage", damage * damage_multiplier, context.for_hit(contact, direction))
	presentation.play_shot(recoil_amount, 0.0, recoil_recovery)
	presentation.flash.hide()
	sound_requested.emit(shot_sound)
	if not damaged.is_empty():
		trauma_requested.emit(camera_trauma)
	fired.emit()
	state_changed.emit()
	return true


func start_reload() -> bool:
	return false


func get_stats() -> Dictionary:
	var stats := super.get_stats()
	stats["melee"] = true
	return stats
