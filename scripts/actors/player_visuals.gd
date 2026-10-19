class_name SurvivorVisuals
extends Node3D
## Presents the editable Blender technician without owning gameplay state.

var _model: Node3D
var _animation: AnimationPlayer
var _lower_body: Node3D
var _upper_body: Node3D
var _gun: Node3D
var _gun_rest: Vector3
var _dash_materials: Array[StandardMaterial3D] = []
var _aim_left: float = 0.0
var _dying: bool = false


func _ready() -> void:
	_model = $TechnicianModel
	_animation = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_lower_body = _model.find_child("LowerBody_Pivot", true, false) as Node3D
	_upper_body = _model.find_child("UpperBody_Pivot", true, false) as Node3D
	_gun = _model.find_child("WeaponSocket", true, false) as Node3D
	_gun_rest = _gun.position
	# Imported resources are shared: localize loops and temporary dash emission.
	var library: AnimationLibrary = (
		_animation.get_animation_library("").duplicate(true) as AnimationLibrary
	)
	_animation.remove_animation_library("")
	_animation.add_animation_library("", library)
	for clip: StringName in [&"Idle", &"Walk", &"Aim"]:
		_animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_add_moving_reload(library, false)
	_add_moving_reload(library, true)
	for mesh_node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh_node as MeshInstance3D
		var source := instance.get_active_material(0) as StandardMaterial3D
		if source != null and source.resource_name.begins_with("Suit"):
			var local_material := source.duplicate() as StandardMaterial3D
			instance.material_override = local_material
			_dash_materials.append(local_material)
	var imported := _model.find_child("ImportedWeapon_Mesh", true, false) as Node3D
	if imported != null:
		imported.hide()
	reset_pose()


func set_aim(direction: Vector3) -> void:
	if not _dying and direction.length_squared() > 0.001:
		rotation.y = atan2(direction.x, direction.z)


func get_weapon_socket() -> Node3D:
	return _gun


func show_shot() -> void:
	if not _dying:
		_aim_left = 0.35


func reset_pose() -> void:
	_dying = false
	process_mode = Node.PROCESS_MODE_INHERIT
	_aim_left = 0.0
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	visible = true
	_gun.position = _gun_rest
	_lower_body.rotation.y = 0.0
	_upper_body.rotation.y = 0.0
	_animation.speed_scale = 1.0
	_animation.play("Idle")
	_animation.advance(0.0)
	_set_dash_glow(false)


func animate(
	delta: float,
	direction: Vector3,
	movement_speed: float,
	invulnerability: float,
	dash_remaining: float,
	movement_direction: Vector3 = Vector3.ZERO,
	reloading: bool = false,
	reload_progress: float = 0.0
) -> void:
	if _dying:
		return
	_aim_left = maxf(0.0, _aim_left - delta)
	set_aim(direction)
	var moving: bool = movement_speed > 0.2
	var backwards: bool = moving and movement_direction.dot(direction) < -0.25
	if moving and movement_direction.length_squared() > 0.001:
		# Backpedal instead of twisting the waist 180 degrees away from aim.
		var travel: Vector3 = -movement_direction if backwards else movement_direction
		_lower_body.rotation.y = wrapf(atan2(travel.x, travel.z) - rotation.y, -PI, PI)
	else:
		_lower_body.rotation.y = lerp_angle(_lower_body.rotation.y, 0.0, minf(delta * 12.0, 1.0))
	if dash_remaining > 0.0:
		_play_clip(&"Dash", _animation.get_animation("Dash").length / 0.2)
	elif reloading:
		var reload_clip: StringName = &"Reload"
		if moving:
			reload_clip = &"WalkReloadBack" if backwards else &"WalkReload"
		_play_clip(reload_clip, 1.0)
		# Reload upgrades change duration; the authored action follows ammo progress.
		_animation.seek(
			clampf(reload_progress, 0.0, 0.999) * _animation.get_animation(reload_clip).length, true
		)
	elif moving:
		_play_clip(&"Walk", clampf(movement_speed / 4.3, 0.55, 2.2) * (-1.0 if backwards else 1.0))
	else:
		_play_clip(&"Aim" if _aim_left > 0.0 else &"Idle", 1.0)
	visible = invulnerability <= 0.0 or dash_remaining > 0.0 or fmod(invulnerability, 0.12) < 0.075
	_set_dash_glow(dash_remaining > 0.0)


func play_death() -> float:
	if _dying:
		return 0.0
	_dying = true
	visible = true
	_gun.position = _gun_rest
	_lower_body.rotation.y = 0.0
	_set_dash_glow(false)
	# Defeat pauses gameplay immediately. Only this visual branch keeps playing.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_animation.speed_scale = 1.0
	_animation.play("Death", 0.04)
	_animation.advance(0.0)
	return _animation.get_animation("Death").length


func _play_clip(clip: StringName, rate: float) -> void:
	if _animation.current_animation != clip or not _animation.is_playing():
		_animation.play(clip, 0.08)
	_animation.speed_scale = rate


func _locomotion_track(path: NodePath) -> bool:
	return (
		str(path).contains("LowerBody_Pivot")
		or path.get_name(path.get_name_count() - 1) == &"Body_Motion"
	)


func _add_moving_reload(library: AnimationLibrary, backwards: bool) -> void:
	# Both authored clips last one second. Keep the actual reload upper body,
	# but replace its stationary legs with the walking tracks to avoid gliding.
	var combined := library.get_animation(&"Reload").duplicate(true) as Animation
	var walk: Animation = library.get_animation(&"Walk")
	for track: int in range(combined.get_track_count() - 1, -1, -1):
		if _locomotion_track(combined.track_get_path(track)):
			combined.remove_track(track)
	for track: int in range(walk.get_track_count()):
		if not _locomotion_track(walk.track_get_path(track)):
			continue
		walk.copy_track(track, combined)
		var added: int = combined.get_track_count() - 1
		if backwards:
			var keys: Array[Dictionary] = []
			for key: int in range(combined.track_get_key_count(added)):
				keys.append(
					{
						"time": combined.length - combined.track_get_key_time(added, key),
						"value": combined.track_get_key_value(added, key)
					}
				)
			while combined.track_get_key_count(added) > 0:
				combined.track_remove_key(added, 0)
			for key: Dictionary in keys:
				combined.track_insert_key(added, float(key["time"]), key["value"])
	library.add_animation(&"WalkReloadBack" if backwards else &"WalkReload", combined)


func _set_dash_glow(enabled: bool) -> void:
	for material: StandardMaterial3D in _dash_materials:
		material.emission_enabled = enabled
		material.emission = Color(0.1, 0.7, 0.8)
		material.emission_energy_multiplier = 0.7
