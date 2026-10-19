@tool
class_name ZombieVisuals
extends Node3D
## Authored model, indicators and palette. Model forward is +Z, without hidden flips.

@export var skin_color := Color("afc5af"):
	set(value):
		skin_color = value
		_apply_palette()
@export var cloth_color := Color("297c89"):
	set(value):
		cloth_color = value
		_apply_palette()
@export var always_show_health: bool = false:
	set(value):
		always_show_health = value
		if is_instance_valid(_health_root):
			_health_root.visible = value
@export_range(0.1, 10.0) var death_playback_speed: float = 2.5
@export_range(0.0, 30.0) var turn_speed: float = 10.0
@export_range(0.01, 1.0) var attack_impact_fraction: float = 0.47

var _visual_scale: float = 1.0
var _dying: bool = false
var _animation: AnimationPlayer

@onready var _body: Node3D = $Body
@onready var _model: Node3D = $Body/ZombieModel
@onready var _variant_details: Node3D = $Body/VariantDetails
@onready var _health_root: Node3D = $Indicators/HealthBar
@onready var _health_fill: MeshInstance3D = $Indicators/HealthBar/Fill
@onready var warning: MeshInstance3D = $Indicators/AttackWarning


func _ready() -> void:
	_apply_palette()
	reset_health()
	if Engine.is_editor_hint():
		return
	_animation = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(_animation != null, "Enemy model needs an AnimationPlayer.")
	var library := _animation.get_animation_library("").duplicate(true) as AnimationLibrary
	_animation.remove_animation_library("")
	_animation.add_animation_library("", library)
	for clip: StringName in [&"Idle", &"Walk"]:
		_animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_play_clip(&"Idle")
	reset_health()


func set_dimensions(actor_scale: float) -> void:
	_visual_scale = actor_scale
	var body := get_node_or_null("Body") as Node3D
	var health_bar := get_node_or_null("Indicators/HealthBar") as Node3D
	if body != null:
		body.scale = Vector3.ONE * actor_scale
	if health_bar != null:
		health_bar.position.y = 2.3 * actor_scale
		health_bar.scale = Vector3(actor_scale, 1, 1)


func show_warning(radius: float, progress: float) -> void:
	warning.visible = true
	warning.scale = Vector3(radius, 0.6 + progress * 2.0, radius)


func hide_warning() -> void:
	warning.visible = false


func reset_health() -> void:
	_health_root.visible = always_show_health
	_health_fill.scale.x = 0.9
	_health_fill.position.x = 0.0


func show_health(health: float, maximum: float) -> void:
	_health_root.visible = true
	var fraction: float = clampf(health / maxf(maximum, 0.001), 0.0, 1.0)
	_health_fill.scale.x = 0.9 * fraction
	_health_fill.position.x = -0.45 * (1.0 - fraction)


func animate(
		delta: float, speed: float, movement: Vector3, facing: Vector3, flash: float
) -> void:
	if _dying:
		return
	if facing.length_squared() > 0.001:
		var yaw: float = atan2(facing.x, facing.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, yaw, minf(delta * turn_speed, 1.0))
	if _animation.current_animation != "Attack" or not _animation.is_playing():
		var moving: bool = movement.length_squared() > 0.01
		var rate: float = clampf(speed / 2.1, 0.65, 1.8) if moving else 1.0
		if moving and movement.normalized().dot(facing.normalized()) < -0.25:
			rate = -rate
		_play_clip(&"Walk" if moving else &"Idle", rate)
	var hit_scale: float = 1.0 + flash * 0.65
	var desired_scale := Vector3(hit_scale, 1.0, hit_scale) * _visual_scale
	_body.scale = _body.scale.lerp(desired_scale, minf(1.0, delta * 20.0))


func play_attack(windup_duration: float = 0.0) -> void:
	if _dying:
		return
	var rate: float = 1.0
	if windup_duration > 0.0:
		rate = _animation.get_animation("Attack").length * attack_impact_fraction
		rate /= windup_duration
	_animation.speed_scale = 1.0
	_animation.play("Attack", 0.08, rate)


func play_death() -> float:
	_dying = true
	hide_warning()
	_health_root.hide()
	_variant_details.hide()
	_body.scale = Vector3.ONE * _visual_scale
	_animation.speed_scale = 1.0
	_animation.play("Death", 0.04, death_playback_speed)
	return _animation.get_animation("Death").length / death_playback_speed


func _play_clip(clip: StringName, rate: float = 1.0) -> void:
	if _animation.current_animation != clip or not _animation.is_playing():
		_animation.play(clip, 0.1)
	_animation.speed_scale = rate


func _apply_palette() -> void:
	var model := get_node_or_null("Body/ZombieModel") as Node3D
	if model == null:
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.mesh.get_surface_count() == 0:
			continue
		var source := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if source == null:
			continue
		var material := source.duplicate() as StandardMaterial3D
		var label: String = source.resource_name.to_lower()
		if label.contains("skin | sage"):
			material.albedo_color = skin_color
		elif label.contains("skin | socket shadow"):
			material.albedo_color = skin_color.darkened(0.45)
		elif label.contains("cloth | petrol shirt"):
			material.albedo_color = cloth_color
		elif label.contains("cloth | torn olive lining"):
			material.albedo_color = cloth_color.lightened(0.45)
		mesh.material_override = material
