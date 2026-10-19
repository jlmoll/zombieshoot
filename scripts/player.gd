class_name Survivor
extends CharacterBody3D
## Screen-relative twin-stick gameplay; presentation belongs to the Visuals child.

signal stats_changed
signal died
signal bullet_requested(origin: Vector3, direction: Vector3, damage: float, speed: float, pierce: int)
signal projectile_spawn_requested(
	origin: Vector3, direction: Vector3, damage: float, speed: float, pierce: int,
	context: DamageContext, scene: PackedScene
)
signal grenade_requested(origin: Vector3, direction: Vector3, distance: float)
signal sound_requested(kind: String)
signal particles_requested(at: Vector3, color: Color, count: int)
signal trauma_requested(amount: float)

const SCREEN_RIGHT := Vector3(0.70710678, 0.0, -0.70710678)
const SCREEN_DOWN := Vector3(0.70710678, 0.0, 0.70710678)
const BASE_SPEED := 6.4
const DASH_DURATION := 0.20
const DASH_COOLDOWN := 1.0
const MAX_GRENADES: int = 4
const GRENADES_PER_WAVE: int = 2
const GRENADE_COOLDOWN: float = 0.35

@export var team: DamageContext.Team = DamageContext.Team.PLAYER
@export var health_component: HealthComponent

var max_health: float:
	get:
		return health_component.maximum
	set(value):
		health_component.set_maximum(value)
var health: float:
	get:
		return health_component.current
	set(value):
		health_component.set_current(value)
var last_damage_context: DamageContext
var dash_cooldown: float = 0.0
var dash_remaining: float = 0.0
var kills: int = 0
var grenades: int = 0
var speed_multiplier: float = 1.0
var dash_multiplier: float = 1.0
var aim_direction := Vector3(0.70710678, 0.0, -0.70710678)
var move_direction := Vector3.ZERO
var invulnerability: float = 0.0
var _grenade_left: float = 0.0
var _dash_direction := Vector3.ZERO
var _hud_tick: float = 0.0
var _alive: bool = true

@onready var visuals: SurvivorVisuals = $Visuals
@onready var weapon_controller: WeaponController = $WeaponController
@onready var controls: PlayerInput = $PlayerInput


func _ready() -> void:
	assert(health_component != null, "Survivor needs a HealthComponent scene.")
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_health_depleted)
	controls.command_requested.connect(_on_input_command)
	weapon_controller.wielder = self
	weapon_controller.mount(visuals.get_weapon_socket())
	weapon_controller.state_changed.connect(stats_changed.emit)
	weapon_controller.projectile_requested.connect(bullet_requested.emit)
	weapon_controller.projectile_spawn_requested.connect(projectile_spawn_requested.emit)
	weapon_controller.sound_requested.connect(sound_requested.emit)
	weapon_controller.trauma_requested.connect(trauma_requested.emit)
	weapon_controller.fired.connect(visuals.show_shot)
	reset_state()


func reset_state() -> void:
	weapon_controller.reset()
	health_component.reset(100.0)
	last_damage_context = null
	kills = 0
	grenades = 0
	_grenade_left = 0.0
	speed_multiplier = 1.0
	dash_multiplier = 1.0
	dash_cooldown = 0.0
	dash_remaining = 0.0
	invulnerability = 0.0
	_alive = true
	velocity = Vector3.ZERO
	if is_instance_valid(visuals):
		visuals.reset_pose()
	stats_changed.emit()


func get_stats() -> Dictionary:
	var stats: Dictionary = weapon_controller.current_weapon.get_stats()
	stats.merge({
		"health": health,
		"max_health": max_health,
		"grenades": grenades,
		"max_grenades": MAX_GRENADES,
		"dash_ready": dash_cooldown <= 0.0,
		"dash_progress": 1.0 - dash_cooldown / maxf(DASH_COOLDOWN * dash_multiplier, 0.01),
	})
	return stats


func _physics_process(delta: float) -> void:
	if not _active():
		return
	_read_input()
	weapon_controller.advance(delta)
	_grenade_left = maxf(0.0, _grenade_left - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	if dash_remaining > 0.0:
		dash_remaining = maxf(0.0, dash_remaining - delta)
		velocity = _dash_direction * 22.0
	else:
		velocity = move_direction * BASE_SPEED * speed_multiplier
	move_and_slide()
	global_position.y = 0.0
	_update_aim()
	if controls.wants_to_fire():
		try_shoot()
	var magazine: WeaponMagazine = weapon_controller.current_weapon.magazine
	visuals.animate(
		delta, aim_direction, velocity.length(), invulnerability, dash_remaining,
		velocity.normalized(), magazine.reloading, magazine.get_reload_progress()
	)
	_hud_tick -= delta
	if _hud_tick <= 0.0:
		_hud_tick = 0.08
		stats_changed.emit()


func _active() -> bool:
	return _alive and is_inside_tree() and not get_tree().paused


func _read_input() -> void:
	var motion: Vector2 = controls.get_move_vector()
	move_direction = SCREEN_RIGHT * motion.x + SCREEN_DOWN * motion.y


func _on_input_command(command: StringName) -> void:
	if not _active():
		return
	match command:
		&"dash":
			_read_input()
			try_dash()
		&"reload":
			start_reload()
		&"grenade":
			try_throw_grenade()
		&"next_weapon":
			weapon_controller.cycle_weapon()
		&"previous_weapon":
			weapon_controller.cycle_weapon(-1)
		&"weapon_1", &"weapon_2", &"weapon_3":
			select_weapon(int(str(command).trim_prefix("weapon_")) - 1)


func _update_aim() -> void:
	var stick: Vector2 = controls.get_aim_vector()
	if not stick.is_zero_approx():
		controls.mouse_aim_active = false
		aim_direction = (SCREEN_RIGHT * stick.x + SCREEN_DOWN * stick.y).normalized()
	if controls.mouse_aim_active:
		var camera: Camera3D = get_viewport().get_camera_3d()
		var hit: Variant = CursorProjection.project(
			camera, get_viewport().get_mouse_position(), weapon_controller.get_muzzle_position().y
		)
		if hit != null:
			var offset: Vector3 = hit - global_position
			offset.y = 0.0
			if offset.length_squared() > 0.04:
				aim_direction = offset.normalized()
	visuals.set_aim(aim_direction)


func replenish_grenades() -> void:
	grenades = mini(MAX_GRENADES, grenades + GRENADES_PER_WAVE)
	stats_changed.emit()


func try_throw_grenade() -> bool:
	if not _active() or grenades <= 0 or _grenade_left > 0.0:
		return false
	_update_aim()
	var heading: Vector3 = aim_direction
	var distance: float = 9.0
	if controls.mouse_aim_active:
		var camera: Camera3D = get_viewport().get_camera_3d()
		var hit: Variant = CursorProjection.project(camera, get_viewport().get_mouse_position())
		if hit != null:
			var offset: Vector3 = hit - global_position
			offset.y = 0.0
			distance = clampf(offset.length(), 1.5, 10.0)
			if offset.length_squared() > 0.01:
				heading = offset.normalized()
	grenades -= 1
	_grenade_left = GRENADE_COOLDOWN
	grenade_requested.emit(global_position + Vector3.UP * 0.95, heading, distance)
	_sound("grenade_throw")
	stats_changed.emit()
	return true


func try_shoot() -> void:
	if not _active() or dash_remaining > 0.0:
		return
	visuals.set_aim(aim_direction)
	weapon_controller.try_fire(aim_direction, global_position)


func start_reload() -> void:
	if _active():
		weapon_controller.start_reload()


func select_weapon(index: int) -> void:
	if _active():
		weapon_controller.select_weapon(index)


func try_dash() -> void:
	if dash_cooldown > 0.0 or dash_remaining > 0.0 or not _alive:
		return
	_dash_direction = move_direction.normalized() if move_direction.length_squared() > 0.01 else aim_direction
	dash_remaining = DASH_DURATION
	dash_cooldown = DASH_COOLDOWN * dash_multiplier
	invulnerability = maxf(invulnerability, DASH_DURATION + 0.04)
	_sound("dash")
	particles_requested.emit(global_position + Vector3.UP * 0.2, Color(0.25, 0.95, 1.0), 10)
	stats_changed.emit()


func get_damage_team() -> DamageContext.Team:
	return team


func take_damage(amount: float, context: DamageContext = null) -> void:
	if invulnerability > 0.0 or dash_remaining > 0.0 or not _alive or amount <= 0.0:
		return
	if context != null and not context.can_damage(self):
		return
	last_damage_context = context
	health_component.take_damage(amount)
	invulnerability = 0.8
	_sound("hurt")
	trauma_requested.emit(0.38)
	particles_requested.emit(global_position + Vector3.UP * 0.7, Color(1.0, 0.35, 0.2), 12)


func _on_health_changed(_current: float, _maximum: float) -> void:
	stats_changed.emit()


func _on_health_depleted() -> void:
	if not _alive:
		return
	_alive = false
	velocity = Vector3.ZERO
	weapon_controller.stop()
	visuals.play_death()
	died.emit()


func heal(amount: float) -> void:
	if _alive:
		health_component.heal(amount)


func apply_upgrade(id: String) -> void:
	var definition: PerkDefinition = PerkCatalog.find(id)
	if definition != null:
		apply_perk(definition)


func apply_perk(definition: PerkDefinition) -> void:
	if definition == null:
		return
	speed_multiplier *= definition.move_speed_multiplier
	dash_multiplier *= definition.dash_cooldown_multiplier
	max_health += definition.max_health_bonus
	heal(max_health if definition.full_heal else definition.heal_amount)
	weapon_controller.apply_perk(definition)
	stats_changed.emit()


func refill_ammo() -> void:
	weapon_controller.refill()


func _sound(kind: String) -> void:
	sound_requested.emit(kind)
