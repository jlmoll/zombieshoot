class_name Survivor
extends CharacterBody3D
## Screen-relative twin-stick survivor. All art is deliberately primitive geometry.

signal stats_changed
signal died

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
var _visual: Node3D
var _gun: Node3D
var _flash: MeshInstance3D
var _body_material: StandardMaterial3D
var _flash_left: float = 0.0
var _recoil: float = 0.0
var _hud_tick: float = 0.0
var _walk_phase: float = 0.0
var _alive: bool = true


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_build_model()
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
	stats_changed.emit()


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
	_flash_left = maxf(0.0, _flash_left - delta)
	_recoil = move_toward(_recoil, 0.0, delta * 2.5)
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
	_animate(delta)
	_hud_tick -= delta
	if _hud_tick <= 0.0:
		_hud_tick = 0.08
		stats_changed.emit()


func _active() -> bool:
	if not _alive:
		return false
	var world: Node = get_tree().current_scene
	return not world.has_method("is_gameplay_active") or bool(world.call("is_gameplay_active"))


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
				var hit: Vector3 = origin + ray * ((0.85 - origin.y) / ray.y)
				var offset: Vector3 = hit - global_position
				offset.y = 0.0
				if offset.length_squared() > 0.04:
					aim_direction = offset.normalized()
	_visual.rotation.y = atan2(aim_direction.x, aim_direction.z)


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
	get_tree().current_scene.spawn_grenade(global_position + Vector3.UP * 0.95, heading, distance)
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
	var origin: Vector3 = global_position + Vector3.UP * 0.85 + aim_direction * 0.86
	# Keep the muzzle on this side of cover when the weapon visually overlaps it.
	var muzzle_query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.85, origin, 2)
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
		get_tree().current_scene.call("spawn_player_bullet", origin, direction, float(weapon["damage"]) * damage_multiplier, float(weapon["speed"]), int(weapon["pierce"]))
	_flash_left = 0.055
	_recoil = 0.14 if weapon_index == 1 else 0.07
	_sound(["pistol", "shotgun", "smg"][weapon_index])
	get_tree().current_scene.call("add_trauma", 0.09 if weapon_index == 1 else 0.025)
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
	if is_instance_valid(_gun):
		_gun.scale = Vector3(1.35, 1.15, 1.25) if weapon_index == 1 else Vector3.ONE


func try_dash() -> void:
	if dash_cooldown > 0.0 or dash_remaining > 0.0 or not _alive:
		return
	_dash_direction = move_direction.normalized() if move_direction.length_squared() > 0.01 else aim_direction
	dash_remaining = DASH_DURATION
	dash_cooldown = DASH_COOLDOWN * dash_multiplier
	invulnerability = maxf(invulnerability, DASH_DURATION + 0.04)
	_sound("dash")
	get_tree().current_scene.call("spawn_particles", global_position + Vector3.UP * 0.2, Color(0.25, 0.95, 1.0), 10)
	stats_changed.emit()


func take_damage(amount: float) -> void:
	if invulnerability > 0.0 or dash_remaining > 0.0 or not _alive or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	invulnerability = 0.8
	_sound("hurt")
	get_tree().current_scene.call("add_trauma", 0.38)
	get_tree().current_scene.call("spawn_particles", global_position + Vector3.UP * 0.7, Color(1.0, 0.35, 0.2), 12)
	stats_changed.emit()
	if health <= 0.0:
		_alive = false
		velocity = Vector3.ZERO
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
	get_tree().current_scene.call("play_sound", kind)


func _animate(delta: float) -> void:
	_walk_phase += delta * velocity.length() * 1.8
	_visual.position.y = absf(sin(_walk_phase)) * 0.055 if velocity.length() > 0.2 else 0.0
	_visual.rotation.z = sin(_walk_phase) * 0.045 if velocity.length() > 0.2 else 0.0
	_gun.position.z = -_recoil
	_flash.visible = _flash_left > 0.0
	_visual.visible = invulnerability <= 0.0 or dash_remaining > 0.0 or fmod(invulnerability, 0.12) < 0.075
	_body_material.emission_enabled = dash_remaining > 0.0
	_body_material.emission = Color(0.1, 0.7, 0.8)
	_body_material.emission_energy_multiplier = 1.0


func _material(color: Color, emission: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	return material


func _mesh(parent: Node3D, mesh: Mesh, location: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	parent.add_child(instance)
	return instance


func _build_model() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.33
	capsule.height = 1.35
	collision.shape = capsule
	collision.position.y = 0.675
	add_child(collision)
	_visual = Node3D.new()
	add_child(_visual)
	_body_material = _material(Color(0.12, 0.67, 0.78))
	var torso := CapsuleMesh.new()
	torso.radius = 0.3
	torso.height = 0.8
	_mesh(_visual, torso, Vector3(0, 0.67, 0), _body_material)
	var head := SphereMesh.new()
	head.radius = 0.235
	head.height = 0.47
	_mesh(_visual, head, Vector3(0, 1.22, 0), _material(Color(0.91, 0.75, 0.52)))
	var visor := BoxMesh.new()
	visor.size = Vector3(0.37, 0.12, 0.1)
	_mesh(_visual, visor, Vector3(0, 1.25, 0.21), _material(Color(0.025, 0.1, 0.15)))
	var boot := BoxMesh.new()
	boot.size = Vector3(0.22, 0.28, 0.32)
	var dark: Material = _material(Color(0.04, 0.1, 0.13))
	_mesh(_visual, boot, Vector3(-0.17, 0.15, 0), dark)
	_mesh(_visual, boot, Vector3(0.17, 0.15, 0), dark)
	_gun = Node3D.new()
	_visual.add_child(_gun)
	var receiver := BoxMesh.new()
	receiver.size = Vector3(0.18, 0.18, 0.6)
	_mesh(_gun, receiver, Vector3(0.15, 0.85, 0.49), _material(Color(0.18, 0.23, 0.28)))
	var barrel := BoxMesh.new()
	barrel.size = Vector3(0.09, 0.09, 0.25)
	_mesh(_gun, barrel, Vector3(0.15, 0.85, 0.84), dark)
	var flash := SphereMesh.new()
	flash.radius = 0.16
	flash.height = 0.22
	_flash = _mesh(_gun, flash, Vector3(0.15, 0.85, 1.0), _material(Color(1.0, 0.79, 0.2), true))
	_flash.visible = false
