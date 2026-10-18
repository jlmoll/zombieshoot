class_name Zombie
extends CharacterBody3D
## Horde gameplay actor with injected target/navigation and explicit effect signals.

signal enemy_bullet_requested(origin: Vector3, direction: Vector3, damage: float, speed: float)
signal sound_requested(kind: String)
signal particles_requested(at: Vector3, color: Color, count: int)
signal trauma_requested(amount: float)
signal defeated(enemy: Node3D)

## Keep collision radius independent from presentation for forgiving hits.
const MODEL_SCALE: float = 0.8
const MODEL_HIT_HEIGHT: float = 2.25

var kind: String = "walker"
var health: float = 36.0
var max_health: float = 36.0
var score_value: int = 100
var speed: float = 2.1
var contact_damage: float = 10.0
var radius: float = 0.43
var wave_number: int = 1
var dead: bool = false

var target: Node3D
var navigation: Node
var visuals: ZombieVisuals
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
	_visual_scale *= MODEL_SCALE
	health = max_health
	_configured = true
	_apply_configuration()


func _ready() -> void:
	if not _configured:
		configure(kind, wave_number)
	_clock = randf() * TAU
	_navigation_timer = randf() * 0.2
	_attack_cooldown = randf_range(1.2, 2.8)
	_apply_configuration()


func _apply_configuration() -> void:
	# Scene children exist before add_child; dimensions and visuals can be configured in either order.
	var collider: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null:
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		shape.height = maxf(radius * 2.0, MODEL_HIT_HEIGHT * _visual_scale)
		collider.shape = shape
		collider.position.y = shape.height * 0.5
	visuals = get_node_or_null("Visuals") as ZombieVisuals
	if visuals != null:
		visuals.configure(kind, _visual_scale)
		visuals.reset_health()


func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(target):
		return
	_clock += delta
	_contact_cooldown = maxf(0, _contact_cooldown - delta)
	_attack_cooldown -= delta
	_flash = maxf(0, _flash - delta)
	var difference: Vector3 = target.global_position - global_position
	difference.y = 0
	var distance: float = difference.length()
	var to_target: Vector3 = difference.normalized()
	_navigation_timer -= delta
	if _navigation_timer <= 0:
		_navigation_timer = 0.22 + randf() * 0.08
		_navigation = to_target
		if is_instance_valid(navigation):
			_navigation = navigation.get_direction(global_position, target.global_position)
		_navigation.y = 0
		_navigation = _navigation.normalized()
		_update_separation()
	var desired: Vector3 = _navigation
	if kind == "spitter":
		if distance < 4.7:
			desired = -to_target
		elif distance < 7.0:
			desired = Vector3(-to_target.z, 0, to_target.x) * sin(_clock * 0.55)
		if _attack_cooldown <= 0 and distance < 15.0:
			_begin_attack("spit", 0.65)
	elif kind == "boss" and _attack_cooldown <= 0:
		_begin_attack("slam" if distance < 4.8 else "burst", 0.95 if distance < 4.8 else 0.8)
	if _windup > 0:
		_windup -= delta
		desired = Vector3.ZERO
		var progress: float = 1.0 - maxf(_windup, 0.0) / _windup_duration
		visuals.show_warning(_attack, progress)
		if _windup <= 0:
			_perform_attack()
	else:
		visuals.hide_warning()
	velocity = desired.normalized() * speed + _separation + _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 15.0)
	move_and_slide()
	position.y = 0.0
	visuals.animate(delta, _clock, speed, desired.length(), to_target, _windup, _flash)
	if distance < radius + 0.55 and _contact_cooldown <= 0:
		_contact_cooldown = 1.1
		visuals.play_attack()
		if target.has_method("take_damage"):
			target.take_damage(contact_damage)


func _update_separation() -> void:
	_separation = Vector3.ZERO
	for child: Node in get_parent().get_children():
		var other: Zombie = child as Zombie
		if other == null or other == self or not is_instance_valid(other) or other.dead:
			continue
		var gap: Vector3 = global_position - other.global_position
		gap.y = 0
		var gap_squared: float = gap.length_squared()
		var spacing: float = radius + float(other.radius) + 0.12
		if gap_squared < spacing * spacing and gap_squared > 0.0001:
			var gap_length: float = sqrt(gap_squared)
			_separation += gap / gap_length * (spacing - gap_length) * 3.8
	_separation = _separation.limit_length(3.0)


func _begin_attack(attack_kind: String, duration: float) -> void:
	if _windup > 0:
		return
	visuals.play_attack(duration)
	_attack = attack_kind
	_windup = duration
	_windup_duration = duration
	_attack_target = target.global_position
	_attack_cooldown = 3.4 if kind == "boss" else 2.7
	sound_requested.emit("warning")


func _perform_attack() -> void:
	if not is_instance_valid(target) or dead:
		return
	var origin: Vector3 = global_position + Vector3.UP * 0.8
	match _attack:
		"spit":
			var direction: Vector3 = (_attack_target - global_position).normalized()
			direction.y = 0
			direction = direction.normalized()
			for spread in [-0.17, 0.0, 0.17]:
				enemy_bullet_requested.emit(origin, direction.rotated(Vector3.UP, spread), 10.0, 6.5)
		"burst":
			var count: int = 18 if health < max_health * 0.5 else 12
			var offset: float = _clock * 0.6
			for index in range(count):
				var angle: float = TAU * float(index) / float(count) + offset
				enemy_bullet_requested.emit(origin, Vector3(cos(angle), 0, sin(angle)), 13.0, 5.0)
			trauma_requested.emit(0.16)
		"slam":
			particles_requested.emit(global_position + Vector3.UP * 0.1, Color("e9a06a"), 28)
			trauma_requested.emit(0.4)
			if global_position.distance_to(target.global_position) < 4.3:
				target.take_damage(26.0)
			for index in range(8):
				var angle: float = TAU * float(index) / 8.0
				enemy_bullet_requested.emit(origin, Vector3(cos(angle), 0, sin(angle)), 10.0, 4.0)
	sound_requested.emit("enemy_shoot")
	visuals.hide_warning()


func take_damage(amount: float) -> void:
	if dead or amount <= 0:
		return
	health = maxf(0.0, health - amount)
	_flash = 0.16
	if is_instance_valid(target):
		var away: Vector3 = global_position - target.global_position
		away.y = 0
		_knockback += away.normalized() * (0.8 if kind == "boss" else 2.3)
	if is_instance_valid(visuals):
		visuals.show_health(health, max_health)
	if health <= 0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	particles_requested.emit(global_position + Vector3.UP * 0.65, Color("a3b879"), 16 if kind == "boss" else 7)
	defeated.emit(self)
	var death_duration: float = visuals.play_death()
	await get_tree().create_timer(death_duration + 0.25, false).timeout
	queue_free()
