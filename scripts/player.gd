class_name Survivor
extends CharacterBody3D
## Screen-relative twin-stick gameplay; presentation belongs to the Visuals child.

signal stats_changed
signal died
signal bullet_requested(origin: Vector3, direction: Vector3, damage: float, speed: float, pierce: int)
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

var max_health: float = 100.0
var health: float = 100.0
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
var _mouse_active: bool = true
var _pad_buttons: Dictionary = {}
var _hud_tick: float = 0.0
var _alive: bool = true

@onready var visuals: SurvivorVisuals = $Visuals
@onready var weapon_controller: WeaponController = $WeaponController


func _ready() -> void:
	weapon_controller.mount(visuals.get_weapon_socket())
	weapon_controller.state_changed.connect(stats_changed.emit)
	weapon_controller.projectile_requested.connect(bullet_requested.emit)
	weapon_controller.sound_requested.connect(sound_requested.emit)
	weapon_controller.trauma_requested.connect(trauma_requested.emit)
	weapon_controller.fired.connect(visuals.show_shot)
	reset_state()


func reset_state() -> void:
	weapon_controller.reset()
	max_health = 100.0
	health = max_health
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


func _input(event: InputEvent) -> void:
	if not _active():
		return
	if event is InputEventMouseMotion:
		_mouse_active = true
	if event is InputEventMouseButton and event.pressed:
		_mouse_active = true
	if event is InputEventKey and event.pressed and not event.echo:
		# Hotkeys follow their displayed labels, including remapped and injected input.
		var key: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		match key:
			KEY_SPACE:
				try_dash()
			KEY_R:
				start_reload()
			KEY_G:
				try_throw_grenade()
			KEY_Q:
				weapon_controller.cycle_weapon()
			KEY_1, KEY_2, KEY_3:
				select_weapon(int(key - KEY_1))
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			weapon_controller.cycle_weapon()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			weapon_controller.cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			try_throw_grenade()


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
	position.y = 0.0
	_update_aim()
	var pad: int = _pad_id()
	var stick_firing: bool = false
	var trigger_firing: bool = false
	if pad >= 0:
		stick_firing = Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)).length() > 0.24
		trigger_firing = Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > 0.25 or Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or stick_firing or trigger_firing:
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


func _pad_id() -> int:
	var pads: Array[int] = Input.get_connected_joypads()
	return pads[0] if not pads.is_empty() else -1


func _read_input() -> void:
	var horizontal: float = float(_key_down(KEY_D)) - float(_key_down(KEY_A))
	var vertical: float = float(_key_down(KEY_S)) - float(_key_down(KEY_W))
	var motion := Vector2(horizontal, vertical)
	var pad: int = _pad_id()
	if pad >= 0:
		var left := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		if left.length() > 0.18:
			motion += left.normalized() * remap(clampf(left.length(), 0.18, 1.0), 0.18, 1.0, 0.0, 1.0)
		if _pad_pressed(pad, JOY_BUTTON_LEFT_SHOULDER) or _pad_pressed(pad, JOY_BUTTON_A):
			try_dash()
		if _pad_pressed(pad, JOY_BUTTON_X):
			start_reload()
		if _pad_pressed(pad, JOY_BUTTON_Y):
			weapon_controller.cycle_weapon()
		if _pad_pressed(pad, JOY_BUTTON_B):
			try_throw_grenade()
	motion = motion.limit_length(1.0)
	move_direction = SCREEN_RIGHT * motion.x + SCREEN_DOWN * motion.y


func _key_down(key: Key) -> bool:
	return Input.is_physical_key_pressed(key) or Input.is_key_pressed(key)


func _pad_pressed(pad: int, button: JoyButton) -> bool:
	var pressed: bool = Input.is_joy_button_pressed(pad, button)
	var was_pressed: bool = bool(_pad_buttons.get(button, false))
	_pad_buttons[button] = pressed
	return pressed and not was_pressed


func _update_aim() -> void:
	var pad: int = _pad_id()
	if pad >= 0:
		var stick := Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
		if stick.length() > 0.24:
			_mouse_active = false
			aim_direction = (SCREEN_RIGHT * stick.x + SCREEN_DOWN * stick.y).normalized()
	if _mouse_active:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			var cursor: Vector2 = get_viewport().get_mouse_position()
			var origin: Vector3 = camera.project_ray_origin(cursor)
			var ray: Vector3 = camera.project_ray_normal(cursor)
			if absf(ray.y) > 0.0001:
				var muzzle_height: float = weapon_controller.get_muzzle_position().y
				var hit: Vector3 = origin + ray * ((muzzle_height - origin.y) / ray.y)
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
	if _mouse_active:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			var cursor: Vector2 = get_viewport().get_mouse_position()
			var origin: Vector3 = camera.project_ray_origin(cursor)
			var ray: Vector3 = camera.project_ray_normal(cursor)
			if absf(ray.y) > 0.0001:
				var offset: Vector3 = origin + ray * (-origin.y / ray.y) - global_position
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


func take_damage(amount: float) -> void:
	if invulnerability > 0.0 or dash_remaining > 0.0 or not _alive or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	invulnerability = 0.8
	_sound("hurt")
	trauma_requested.emit(0.38)
	particles_requested.emit(global_position + Vector3.UP * 0.7, Color(1.0, 0.35, 0.2), 12)
	stats_changed.emit()
	if health <= 0.0:
		_alive = false
		velocity = Vector3.ZERO
		weapon_controller.stop()
		visuals.play_death()
		died.emit()


func heal(amount: float) -> void:
	if _alive:
		health = minf(max_health, health + maxf(amount, 0.0))
		stats_changed.emit()


func apply_upgrade(id: String) -> void:
	match id:
		"speed", "movement":
			speed_multiplier *= 1.15
		"health", "vitality":
			max_health += 25.0
			heal(max_health)
		"heal":
			heal(45.0)
		"dash":
			dash_multiplier *= 0.8
		_:
			weapon_controller.apply_upgrade(id)
	stats_changed.emit()


func refill_ammo() -> void:
	weapon_controller.refill()


func _sound(kind: String) -> void:
	sound_requested.emit(kind)
