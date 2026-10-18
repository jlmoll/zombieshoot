class_name Zombie
extends CharacterBody3D
## Procedural horde actor. The world owns navigation, bullets and death rewards.

static var _materials: Dictionary = {}
static var _box: BoxMesh
static var _head: SphereMesh

var kind: String = "walker"
var health: float = 36.0
var max_health: float = 36.0
var score_value: int = 100
var speed: float = 2.1
var contact_damage: float = 10.0
var radius: float = 0.43
var wave_number: int = 1
var dead: bool = false

var _world: Node
var _player: Node3D
var _visual: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _health_fill: MeshInstance3D
var _health_root: Node3D
var _warning: MeshInstance3D
var _visual_scale: float = 1.0
var _clock: float = 0.0
var _contact_cooldown: float = 0.0
var _attack_cooldown: float = 1.5
var _windup: float = 0.0
var _windup_duration: float = 0.0
var _attack: String = ""
var _attack_target: Vector3 = Vector3.ZERO
var _navigation_timer: float = 0.0
var _navigation: Vector3 = Vector3.ZERO
var _separation: Vector3 = Vector3.ZERO
var _knockback: Vector3 = Vector3.ZERO
var _flash: float = 0.0
var _configured: bool = false


func configure(enemy_kind: String, wave: int) -> void:
	kind = enemy_kind
	wave_number = maxi(1, wave)
	var health_scale: float = 1.0 + float(wave_number - 1) * 0.105
	match kind:
		"runner":
			max_health = 25.0 * health_scale
			speed = 4.15
			contact_damage = 8.0
			score_value = 140
			radius = 0.34
			_visual_scale = 0.82
		"brute":
			max_health = 155.0 * health_scale
			speed = 1.45
			contact_damage = 20.0
			score_value = 300
			radius = 0.68
			_visual_scale = 1.45
		"spitter":
			max_health = 50.0 * health_scale
			speed = 1.85
			contact_damage = 8.0
			score_value = 220
			radius = 0.43
			_visual_scale = 1.0
		"boss":
			max_health = 1100.0 * health_scale
			speed = 1.65
			contact_damage = 24.0
			score_value = 2500
			radius = 1.0
			_visual_scale = 2.05
		_:
			kind = "walker"
			max_health = 36.0 * health_scale
			speed = 2.1
			contact_damage = 10.0
			score_value = 100
			radius = 0.43
			_visual_scale = 1.0
	health = max_health
	_configured = true
	if is_node_ready():
		_build_visuals()


func _ready() -> void:
	add_to_group("enemies")
	_world = get_tree().current_scene
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if not _configured:
		configure(kind, wave_number)
	collision_layer = 4
	collision_mask = 2
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_clock = randf() * TAU
	_navigation_timer = randf() * 0.2
	_attack_cooldown = randf_range(1.2, 2.8)
	_build_visuals()


static func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key: String = color.to_html() + str(glow)
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.88
	if color.a < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 1.8
	_materials[key] = result
	return result


func _part(parent: Node3D, at: Vector3, size: Vector3, color: Color, spherical: bool = false, glow: bool = false) -> MeshInstance3D:
	if _box == null:
		_box = BoxMesh.new()
		_box.size = Vector3.ONE
	if _head == null:
		_head = SphereMesh.new()
		_head.radius = 0.5
		_head.height = 1.0
		_head.radial_segments = 8
		_head.rings = 4
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _head if spherical else _box
	mesh_instance.material_override = _material(color, glow)
	mesh_instance.position = at
	mesh_instance.scale = size
	parent.add_child(mesh_instance)
	return mesh_instance


func _build_visuals() -> void:
	# configure() may be used after adding the actor, so rebuilding is idempotent.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_legs.clear()
	_arms.clear()
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = 1.6 * _visual_scale
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * _visual_scale
	add_child(_visual)
	var skin := Color("83ad70")
	var jacket := Color("354b47")
	match kind:
		"runner":
			skin = Color("b9b77c")
			jacket = Color("a56b30")
		"brute":
			skin = Color("b094c0")
			jacket = Color("514260")
		"spitter":
			skin = Color("b4d96b")
			jacket = Color("48775a")
		"boss":
			skin = Color("ce8f7c")
			jacket = Color("8b3946")
	_part(_visual, Vector3(0, 0.97, 0), Vector3(0.68, 0.72, 0.42), jacket)
	_part(_visual, Vector3(0, 1.51, -0.025), Vector3(0.54, 0.52, 0.48), skin, true)
	_part(_visual, Vector3(-0.14, 1.56, -0.225), Vector3(0.08, 0.065, 0.045), Color("f7ce73"), false, true)
	_part(_visual, Vector3(0.14, 1.56, -0.225), Vector3(0.08, 0.065, 0.045), Color("f7ce73"), false, true)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.19, 0.66, 0)
		_visual.add_child(leg)
		_part(leg, Vector3(0, -0.3, 0), Vector3(0.23, 0.62, 0.25), Color("263b40"))
		_part(leg, Vector3(0, -0.56, -0.055), Vector3(0.27, 0.15, 0.36), Color("17272d"))
		_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.4, 1.21, -0.03)
		arm.rotation.x = -0.9
		_visual.add_child(arm)
		_part(arm, Vector3(0, -0.24, 0), Vector3(0.19, 0.53, 0.21), skin)
		_arms.append(arm)
	if kind == "spitter":
		_part(_visual, Vector3(0, 1.03, 0.29), Vector3(0.72, 0.7, 0.6), Color("a1d553"), true, true)
	if kind == "boss":
		for side in [-1.0, 1.0]:
			_part(_visual, Vector3(side * 0.48, 1.3, 0), Vector3(0.35, 0.3, 0.51), Color("b7a18b"))
	_health_root = Node3D.new()
	_health_root.position.y = 1.9 * _visual_scale
	add_child(_health_root)
	_part(_health_root, Vector3.ZERO, Vector3(0.95 * _visual_scale, 0.07, 0.09), Color("17252b"))
	_health_fill = _part(_health_root, Vector3(0, 0, -0.012), Vector3(0.9 * _visual_scale, 0.08, 0.09), Color("e8a46c"), false, true)
	_health_root.visible = kind == "boss"
	_warning = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.93
	ring.outer_radius = 1.0
	ring.rings = 32
	ring.ring_segments = 6
	_warning.mesh = ring
	_warning.material_override = _material(Color(1.0, 0.3, 0.12, 0.8), true)
	_warning.position.y = 0.045
	_warning.visible = false
	add_child(_warning)


func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(_player):
		return
	_clock += delta
	_contact_cooldown = maxf(0, _contact_cooldown - delta)
	_attack_cooldown -= delta
	_flash = maxf(0, _flash - delta)
	var difference: Vector3 = _player.global_position - global_position
	difference.y = 0
	var distance: float = difference.length()
	var to_player: Vector3 = difference.normalized()
	_navigation_timer -= delta
	if _navigation_timer <= 0:
		_navigation_timer = 0.22 + randf() * 0.08
		_navigation = to_player
		if _world.has_method("get_navigation_direction"):
			_navigation = _world.get_navigation_direction(global_position, _player.global_position)
		_navigation.y = 0
		_navigation = _navigation.normalized()
		_update_separation()
	var desired: Vector3 = _navigation
	if kind == "spitter":
		if distance < 4.7:
			desired = -to_player
		elif distance < 7.0:
			desired = Vector3(-to_player.z, 0, to_player.x) * sin(_clock * 0.55)
		if _attack_cooldown <= 0 and distance < 15.0:
			_begin_attack("spit", 0.65)
	elif kind == "boss" and _attack_cooldown <= 0:
		_begin_attack("slam" if distance < 4.8 else "burst", 0.95 if distance < 4.8 else 0.8)
	if _windup > 0:
		_windup -= delta
		desired = Vector3.ZERO
		var progress: float = 1.0 - maxf(_windup, 0.0) / _windup_duration
		_warning.visible = true
		var warning_radius: float = 4.3 if _attack == "slam" else 1.3 * _visual_scale
		_warning.scale = Vector3(warning_radius, 0.6 + progress * 2.0, warning_radius)
		if _windup <= 0:
			_perform_attack()
	else:
		_warning.visible = false
	velocity = desired.normalized() * speed + _separation + _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 15.0)
	move_and_slide()
	position.y = 0.0
	var facing: float = atan2(-to_player.x, -to_player.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, facing, minf(delta * 10, 1.0))
	_animate(delta, desired.length())
	if distance < radius + 0.55 and _contact_cooldown <= 0:
		_contact_cooldown = 1.1
		if _player.has_method("take_damage"):
			_player.take_damage(contact_damage)


func _update_separation() -> void:
	_separation = Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other) or other.dead:
			continue
		var gap: Vector3 = global_position - other.global_position
		gap.y = 0
		var gap_squared: float = gap.length_squared()
		var spacing: float = radius + float(other.radius) + 0.12
		if gap_squared < spacing * spacing and gap_squared > 0.0001:
			var gap_length: float = sqrt(gap_squared)
			_separation += gap / gap_length * (spacing - gap_length) * 3.8
	_separation = _separation.limit_length(3.0)


func _animate(delta: float, moving: float) -> void:
	var stride: float = sin(_clock * speed * 4.3) * minf(moving, 1.0)
	for index in range(_legs.size()):
		_legs[index].rotation.x = stride * 0.5 * (1.0 if index == 0 else -1.0)
	for index in range(_arms.size()):
		_arms[index].rotation.x = -0.9 + stride * 0.18 * (1.0 if index == 0 else -1.0)
	_visual.position.y = absf(stride) * 0.055
	var squash: float = 1.0 + sin(_clock * 29.0) * 0.045 if _windup > 0 else 1.0
	var hit_scale: float = 1.0 + _flash * 0.65
	_visual.scale = _visual.scale.lerp(Vector3(hit_scale, squash, hit_scale) * _visual_scale, minf(1.0, delta * 20.0))


func _begin_attack(attack_kind: String, duration: float) -> void:
	if _windup > 0:
		return
	_attack = attack_kind
	_windup = duration
	_windup_duration = duration
	_attack_target = _player.global_position
	_attack_cooldown = 3.4 if kind == "boss" else 2.7
	if _world.has_method("play_sound"):
		_world.play_sound("warning")


func _perform_attack() -> void:
	if not is_instance_valid(_player) or dead:
		return
	var origin: Vector3 = global_position + Vector3.UP * 0.8
	match _attack:
		"spit":
			var direction: Vector3 = (_attack_target - global_position).normalized()
			direction.y = 0
			direction = direction.normalized()
			for spread in [-0.17, 0.0, 0.17]:
				_world.spawn_enemy_bullet(origin, direction.rotated(Vector3.UP, spread), 10.0, 6.5)
		"burst":
			var count: int = 18 if health < max_health * 0.5 else 12
			var offset: float = _clock * 0.6
			for index in range(count):
				var angle: float = TAU * float(index) / float(count) + offset
				_world.spawn_enemy_bullet(origin, Vector3(cos(angle), 0, sin(angle)), 13.0, 5.0)
			_world.add_trauma(0.16)
		"slam":
			_world.spawn_particles(global_position + Vector3.UP * 0.1, Color("e9a06a"), 28)
			_world.add_trauma(0.4)
			if global_position.distance_to(_player.global_position) < 4.3:
				_player.take_damage(26.0)
			for index in range(8):
				var angle: float = TAU * float(index) / 8.0
				_world.spawn_enemy_bullet(origin, Vector3(cos(angle), 0, sin(angle)), 10.0, 4.0)
	_world.play_sound("enemy_shoot")
	_warning.visible = false


func take_damage(amount: float) -> void:
	if dead or amount <= 0:
		return
	health = maxf(0.0, health - amount)
	_flash = 0.16
	if is_instance_valid(_player):
		var away: Vector3 = global_position - _player.global_position
		away.y = 0
		_knockback += away.normalized() * (0.8 if kind == "boss" else 2.3)
	if is_instance_valid(_health_fill):
		_health_root.visible = true
		_health_fill.scale.x = 0.9 * _visual_scale * health / max_health
		_health_fill.position.x = -0.45 * _visual_scale * (1.0 - health / max_health)
	if health <= 0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	_world.spawn_particles(global_position + Vector3.UP * 0.65, Color("a3b879"), 16 if kind == "boss" else 7)
	_world.enemy_killed(self)
	queue_free()
