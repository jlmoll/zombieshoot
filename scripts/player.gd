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
const WEAPON_DEFINITIONS: Array[Dictionary] = [
	{"name": "PISTOLA", "damage": 30.0, "interval": 0.22, "magazine": 12, "reload": 0.9, "speed": 36.0, "pellets": 1, "spread": 0.018, "pierce": 0},
	{"name": "ESCOPETA", "damage": 19.0, "interval": 0.65, "magazine": 6, "reload": 1.35, "speed": 30.0, "pellets": 7, "spread": 0.28, "pierce": 0},
	{"name": "SUBFUSIL", "damage": 14.0, "interval": 0.085, "magazine": 30, "reload": 1.25, "speed": 40.0, "pellets": 1, "spread": 0.065, "pierce": 0},
]

var max_health: float = 100.0
var health: float = 100.0
var ammo: int = 12
var magazine_size: int = 12
var reloading: bool = false
var reload_duration: float = 0.9
var reload_left: float = 0.0
var weapon_index: int = 0
var weapons: Array[Dictionary] = []
var dash_cooldown: float = 0.0
var dash_remaining: float = 0.0
var kills: int = 0
var grenades: int = 0
var _grenade_left: float = 0.0
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var fire_rate_multiplier: float = 1.0
var reload_multiplier: float = 1.0
var dash_multiplier: float = 1.0
var aim_direction := Vector3(0.70710678, 0.0, -0.70710678)
var move_direction := Vector3.ZERO
var invulnerability: float = 0.0
var _fire_left: float = 0.0
var _dash_direction := Vector3.ZERO
var _mouse_active: bool = true
var _pad_buttons: Dictionary = {}
@onready var visuals: SurvivorVisuals = $Visuals
var _hud_tick: float = 0.0
var _alive: bool = true


func _ready() -> void:
	reset_state()


func reset_state() -> void:
	weapons.clear()
	for definition: Dictionary in WEAPON_DEFINITIONS:
		var weapon: Dictionary = definition.duplicate(true)
		weapon["ammo"] = int(weapon["magazine"])
		weapons.append(weapon)
	max_health = 100.0
	health = max_health
	kills = 0
	grenades = 0
	_grenade_left = 0.0
	damage_multiplier = 1.0
	speed_multiplier = 1.0
	fire_rate_multiplier = 1.0
	reload_multiplier = 1.0
	dash_multiplier = 1.0
	weapon_index = 0
	dash_cooldown = 0.0
	dash_remaining = 0.0
	invulnerability = 0.0
	_fire_left = 0.0
	reloading = false
	reload_left = 0.0
	_alive = true
	velocity = Vector3.ZERO
	_sync_weapon()
	if is_instance_valid(visuals):
		visuals.reset_pose()
	stats_changed.emit()


func get_stats() -> Dictionary:
	var weapon: Dictionary = weapons[weapon_index] if not weapons.is_empty() else WEAPON_DEFINITIONS[0]
	return {
		"health": health,
		"max_health": max_health,
		"ammo": ammo,
		"magazine": magazine_size,
		"grenades": grenades,
		"max_grenades": MAX_GRENADES,
		"reloading": reloading,
		"reload_progress": 1.0 - reload_left / maxf(reload_duration, 0.01),
		"weapon": weapon.get("name", "ARMA"),
		"dash_ready": dash_cooldown <= 0.0,
		"dash_progress": 1.0 - dash_cooldown / maxf(DASH_COOLDOWN * dash_multiplier, 0.01),
	}


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
				select_weapon((weapon_index + 1) % weapons.size())
			KEY_1, KEY_2, KEY_3:
				select_weapon(int(key - KEY_1))
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_weapon((weapon_index + 1) % weapons.size())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_weapon((weapon_index + weapons.size() - 1) % weapons.size())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			try_throw_grenade()


func _physics_process(delta: float) -> void:
	if not _active():
		return
	_read_input()
	_fire_left = maxf(0.0, _fire_left - delta)
	_grenade_left = maxf(0.0, _grenade_left - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	if reloading:
		reload_left = maxf(0.0, reload_left - delta)
		if reload_left <= 0.0:
			reloading = false
			ammo = magazine_size
			weapons[weapon_index]["ammo"] = ammo
			_sound("reload_done")
			stats_changed.emit()
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
	visuals.animate(delta, aim_direction, velocity.length(), invulnerability, dash_remaining, velocity.normalized(), reloading, 1.0 - reload_left / maxf(reload_duration, 0.01))
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
			select_weapon((weapon_index + 1) % weapons.size())
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
				var hit: Vector3 = origin + ray * ((visuals.get_muzzle_position().y - origin.y) / ray.y)
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
	if reloading or dash_remaining > 0.0 or _fire_left > 0.0 or not _alive:
		return
	if ammo <= 0:
		start_reload()
		return
	var weapon: Dictionary = weapons[weapon_index]
	ammo -= 1
	weapon["ammo"] = ammo
	_fire_left = float(weapon["interval"]) / fire_rate_multiplier
	visuals.set_aim(aim_direction)
	var origin: Vector3 = visuals.get_muzzle_position()
	# Keep the muzzle on this side of cover when the weapon visually overlaps it.
	var muzzle_query := PhysicsRayQueryParameters3D.create(Vector3(global_position.x, origin.y, global_position.z), origin, 2)
	var muzzle_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(muzzle_query)
	if not muzzle_hit.is_empty():
		origin = (muzzle_hit["position"] as Vector3) - aim_direction * 0.03
	var pellets: int = int(weapon["pellets"])
	var spread: float = float(weapon["spread"])
	for pellet: int in range(pellets):
		var angle: float = randf_range(-spread, spread)
		if pellets > 1:
			angle = lerpf(-spread, spread, float(pellet) / float(pellets - 1)) + randf_range(-0.025, 0.025)
		var direction: Vector3 = aim_direction.rotated(Vector3.UP, angle)
		bullet_requested.emit(origin, direction, float(weapon["damage"]) * damage_multiplier, float(weapon["speed"]), int(weapon["pierce"]))
	visuals.show_shot(weapon_index)
	_sound(["pistol", "shotgun", "smg"][weapon_index])
	trauma_requested.emit(0.09 if weapon_index == 1 else 0.025)
	stats_changed.emit()


func start_reload() -> void:
	if reloading or ammo >= magazine_size or not _alive:
		return
	reloading = true
	reload_left = reload_duration
	_sound("reload")
	stats_changed.emit()


func select_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == weapon_index:
		return
	weapons[weapon_index]["ammo"] = ammo
	weapon_index = index
	reloading = false
	reload_left = 0.0
	_fire_left = maxf(_fire_left, 0.12)
	_sync_weapon()
	_sound("switch")
	stats_changed.emit()


func _sync_weapon() -> void:
	var weapon: Dictionary = weapons[weapon_index]
	ammo = int(weapon["ammo"])
	magazine_size = int(weapon["magazine"])
	reload_duration = float(weapon["reload"]) * reload_multiplier
	if is_instance_valid(visuals):
		visuals.set_weapon(weapon_index)


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
		visuals.play_death()
		died.emit()


func heal(amount: float) -> void:
	if _alive:
		health = minf(max_health, health + maxf(amount, 0.0))
		stats_changed.emit()


func apply_upgrade(id: String) -> void:
	match id:
		"damage", "power":
			damage_multiplier *= 1.25
		"speed", "movement":
			speed_multiplier *= 1.15
		"fire_rate", "firerate":
			fire_rate_multiplier *= 1.2
		"health", "vitality":
			max_health += 25.0
			heal(max_health)
		"heal":
			heal(45.0)
		"reload":
			reload_multiplier *= 0.8
		"dash":
			dash_multiplier *= 0.8
		"magazine", "ammo":
			for weapon: Dictionary in weapons:
				weapon["magazine"] = int(ceil(float(weapon["magazine"]) * 1.25))
				weapon["ammo"] = int(weapon["magazine"])
		"pierce":
			for weapon: Dictionary in weapons:
				weapon["pierce"] = int(weapon["pierce"]) + 1
	_sync_weapon()
	stats_changed.emit()


func refill_ammo() -> void:
	for weapon: Dictionary in weapons:
		weapon["ammo"] = int(weapon["magazine"])
	ammo = magazine_size
	reloading = false
	reload_left = 0.0
	stats_changed.emit()


func _sound(kind: String) -> void:
	sound_requested.emit(kind)
