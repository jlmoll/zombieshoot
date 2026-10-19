@tool
class_name Weapon
extends Node3D
## Shared firearm contract. Variants configure this node and compose its children.

signal state_changed
signal fired
signal projectile_requested(
	origin: Vector3, direction: Vector3, damage: float, speed: float, pierce: int
)
signal projectile_spawn_requested(
	origin: Vector3, direction: Vector3, damage: float, speed: float, pierce: int,
	context: DamageContext, scene: PackedScene
)
signal sound_requested(kind: String)
signal trauma_requested(amount: float)

@export_group("Identity")
@export var display_name: String = "ARMA"
@export var weapon_id: StringName = &"weapon"
@export_group("Ballistics")
@export var projectile_scene: PackedScene = preload("res://scenes/projectiles/player_bullet.tscn")
@export_range(0.1, 1000.0) var damage: float = 30.0
@export_range(0.01, 10.0) var fire_interval: float = 0.22
@export_range(1.0, 200.0) var projectile_speed: float = 36.0
@export_range(1, 100) var pellets: int = 1
@export_range(0.0, 3.14) var spread: float = 0.018
@export_range(0.0, 1.0) var pellet_jitter: float = 0.025
@export_range(0, 100) var penetration: int = 0
@export_flags_3d_physics var obstruction_mask: int = GameRules.WALL_LAYER
@export_group("Magazine")
@export_range(1, 1000) var magazine_capacity: int = 12
@export_range(0.01, 20.0) var reload_time: float = 0.9
@export_group("Feedback")
@export var shot_sound: String = "pistol"
@export var reload_sound: String = "reload"
@export var reload_finished_sound: String = "reload_done"
@export_range(0.0, 1.0) var recoil_amount: float = 0.027
@export_range(0.01, 10.0) var recoil_recovery: float = 0.6
@export_range(0.0, 1.0) var flash_duration: float = 0.055
@export_range(0.0, 1.0) var camera_trauma: float = 0.025
@export_group("Components")
@export var magazine: WeaponMagazine
@export var emitter: ProjectileEmitter
@export var presentation: WeaponPresentation

var damage_multiplier: float = 1.0
var fire_rate_multiplier: float = 1.0
var reload_multiplier: float = 1.0
var penetration_bonus: int = 0
var cooldown_remaining: float = 0.0
var wielder: Node


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	assert(magazine != null and emitter != null and presentation != null)
	magazine.changed.connect(state_changed.emit)
	magazine.reload_finished.connect(_on_reload_finished)
	emitter.projectile_requested.connect(projectile_requested.emit)
	emitter.projectile_spawn_requested.connect(projectile_spawn_requested.emit)
	reset()


func _get_configuration_warnings() -> PackedStringArray:
	if projectile_scene == null:
		return ["Assign a projectile scene with a Bullet root."]
	if magazine == null or emitter == null or presentation == null:
		return ["Assign Magazine, Emitter and Presentation components."]
	return []


func reset() -> void:
	damage_multiplier = 1.0
	fire_rate_multiplier = 1.0
	reload_multiplier = 1.0
	penetration_bonus = 0
	cooldown_remaining = 0.0
	magazine.reset(magazine_capacity)
	presentation.reset()


func advance(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	magazine.advance(delta)
	presentation.advance(delta)


func try_fire(heading: Vector3, wielder_position: Vector3) -> bool:
	if not is_inside_tree() or get_tree().paused or heading.length_squared() < 0.001:
		return false
	if magazine.reloading or cooldown_remaining > 0.0:
		return false
	if magazine.ammo <= 0:
		start_reload()
		return false
	magazine.consume()
	cooldown_remaining = fire_interval / maxf(0.01, fire_rate_multiplier)
	var direction := heading.normalized()
	var origin: Vector3 = presentation.get_muzzle_position()
	# A model can overlap cover; never allow the muzzle to fire through that cover.
	var start := Vector3(wielder_position.x, origin.y, wielder_position.z)
	var query := PhysicsRayQueryParameters3D.create(start, origin, obstruction_mask)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		origin = (hit["position"] as Vector3) - direction * 0.03
	emitter.emit_shot(
		origin, direction, damage * damage_multiplier, projectile_speed,
		penetration + penetration_bonus, pellets, spread, pellet_jitter,
		DamageContext.create(self, wielder, _get_wielder_team(), weapon_id), projectile_scene
	)
	presentation.play_shot(recoil_amount, flash_duration, recoil_recovery)
	sound_requested.emit(shot_sound)
	trauma_requested.emit(camera_trauma)
	fired.emit()
	state_changed.emit()
	return true


func _get_wielder_team() -> DamageContext.Team:
	if is_instance_valid(wielder) and wielder.has_method("get_damage_team"):
		return wielder.get_damage_team()
	return DamageContext.Team.PLAYER


func start_reload() -> bool:
	if not is_inside_tree() or get_tree().paused:
		return false
	if not magazine.start_reload(reload_time * reload_multiplier):
		return false
	sound_requested.emit(reload_sound)
	return true


func set_equipped(equipped: bool) -> void:
	visible = equipped
	if not equipped:
		magazine.cancel_reload()
		presentation.reset()


func get_stats() -> Dictionary:
	return {
		"weapon": display_name,
		"ammo": magazine.ammo,
		"magazine": magazine.capacity,
		"reloading": magazine.reloading,
		"reload_progress": magazine.get_reload_progress(),
	}


func _on_reload_finished() -> void:
	sound_requested.emit(reload_finished_sound)
