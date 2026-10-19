@tool
class_name Zombie
extends CharacterBody3D
## Base enemy actor. Scenes configure stats and compose movement, attacks and visuals.

signal enemy_bullet_requested(origin: Vector3, direction: Vector3, damage: float, speed: float)
signal projectile_spawn_requested(
	origin: Vector3,
	direction: Vector3,
	damage: float,
	speed: float,
	pierce: int,
	context: DamageContext,
	scene: PackedScene
)
signal sound_requested(kind: String)
signal particles_requested(at: Vector3, color: Color, count: int)
signal trauma_requested(amount: float)
signal defeated(enemy: Node3D)

@export_group("Identity and stats")
## Identificador del tipo. Debe coincidir con su clave en EnemySpawner y las reglas de oleada.
@export var kind: String = "walker"
## Equipo utilizado para filtrar daño aliado y atribuir los ataques de este enemigo.
@export var team: DamageContext.Team = DamageContext.Team.ENEMY
## Vida máxima en la primera oleada, antes de aplicar [member health_per_wave].
@export_range(1.0, 10000.0) var base_health: float = 36.0
## Incremento de vida por oleada expresado como fracción de la vida base: 0.105 = 10,5 %.
## Fórmula: base_health * (1 + (numero_de_oleada - 1) * health_per_wave).
## El crecimiento es lineal; no modifica la velocidad ni el daño.
@export_range(0.0, 1.0) var health_per_wave: float = 0.105
## Velocidad de desplazamiento en metros por segundo. No aumenta automáticamente por oleada.
@export_range(0.0, 30.0) var speed: float = 2.1
## Daño de cada golpe por contacto. Los ataques especiales tienen su propio daño.
@export_range(0.0, 100.0) var contact_damage: float = 10.0
## Puntos base al morir por daño atribuido a un jugador, antes del multiplicador de oleada.
@export_range(0, 10000) var score_value: int = 100
@export_group("Body")
## Radio de colisión en metros. También interviene en separación y alcance de contacto.
@export_range(0.1, 3.0) var radius: float = 0.43:
	set(value):
		radius = value
		_refresh_dimensions()
## Escala del modelo y sus indicadores. Ajusta también la altura de la colisión,
## pero no el radio, la vida, la velocidad ni el daño.
@export_range(0.1, 5.0) var visual_scale: float = 0.8:
	set(value):
		visual_scale = value
		_refresh_dimensions()
## Altura del cuerpo antes de aplicar visual_scale, en metros.
## La cápsula conserva una altura mínima equivalente al diámetro de su radio.
@export_range(0.1, 5.0) var model_hit_height: float = 2.25:
	set(value):
		model_hit_height = value
		_refresh_dimensions()
@export_group("Combat response")
## Segundos mínimos entre golpes por contacto de este enemigo.
@export_range(0.01, 5.0) var contact_interval: float = 1.1
## Alcance adicional en metros sobre el radio para golpear al jugador por contacto.
@export_range(0.0, 3.0) var contact_reach: float = 0.55
## Velocidad de retroceso añadida por impacto, en metros por segundo. Con 0 no hay empuje.
@export_range(0.0, 10.0) var knockback_strength: float = 2.3
## Rapidez con la que desaparece el retroceso, en metros por segundo al cuadrado.
## Un valor mayor permite recuperar antes el movimiento normal.
@export_range(0.0, 50.0) var knockback_recovery: float = 15.0
## Duración en segundos del destello visual al recibir daño.
@export_range(0.0, 2.0) var hit_flash_duration: float = 0.16
## Segundos que se conserva el cadáver después de terminar su animación de muerte.
## El enemigo deja de contar para la oleada en cuanto muere, antes de retirarlo.
@export_range(0.0, 2.0) var corpse_linger: float = 0.25
## Cantidad de partículas solicitadas al morir; el servicio de efectos puede limitarlas.
@export_range(0, 100) var death_particle_count: int = 7
## Color de las partículas de muerte.
@export var death_color := Color("a3b879")
@export_group("Components")
## Hijo de presentación: modelo, animaciones, barra de vida y avisos de ataque.
@export var visuals: ZombieVisuals
## Hijo que calcula persecución, separación y distancias de combate.
@export var movement: EnemyMovement
## Hijo que selecciona y ejecuta sus escenas de ataque.
@export var combat: EnemyCombat
## Marcador del propio enemigo que fija el origen global de sus proyectiles.
@export var attack_origin: Marker3D
## Componente de vida exclusivo de esta instancia; debe pertenecer al propio enemigo.
@export var health_component: HealthComponent
var health: float:
	get:
		return health_component.current
	set(value):
		health_component.set_current(value)
var max_health: float:
	get:
		return health_component.maximum
	set(value):
		health_component.set_maximum(value)
var last_damage_context: DamageContext
var wave_number: int = 1
var dead: bool = false
var target: Node3D
var navigation: HordeNavigation
var neighbors: Callable
var _clock: float = 0.0
var _contact_remaining: float = 0.0
var _knockback := Vector3.ZERO
var _flash: float = 0.0
var _configured: bool = false


func _ready() -> void:
	_refresh_dimensions()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	assert(visuals != null and movement != null and combat != null and attack_origin != null)
	assert(health_component != null, "Zombie needs a HealthComponent scene.")
	health_component.died.connect(_die)
	if not _configured:
		configure_wave(wave_number)
	visuals.reset_health()
	_clock = randf() * TAU
	movement.navigation = navigation
	movement.neighbors = neighbors
	combat.carrier = self
	combat.projectile_requested.connect(enemy_bullet_requested.emit)
	combat.projectile_spawn_requested.connect(projectile_spawn_requested.emit)
	combat.particles_requested.connect(particles_requested.emit)
	combat.trauma_requested.connect(trauma_requested.emit)
	combat.sound_requested.connect(sound_requested.emit)
	combat.attack_started.connect(visuals.play_attack)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or dead or not is_instance_valid(target):
		return
	_clock += delta
	_contact_remaining = maxf(0.0, _contact_remaining - delta)
	_flash = maxf(0.0, _flash - delta)
	var difference: Vector3 = target.global_position - global_position
	difference.y = 0.0
	var distance: float = difference.length()
	var to_target := difference.normalized()
	var desired: Vector3 = movement.get_direction(delta, self, target.global_position, _clock)
	var attacking: bool = combat.advance(
		delta,
		distance,
		global_position,
		attack_origin.global_position,
		target,
		_clock,
		health < max_health * 0.5
	)
	if attacking:
		desired = Vector3.ZERO
	if combat.windup_remaining > 0.0:
		var attack: EnemyAttack = combat.current_attack
		var warning_radius: float = attack.warning_radius
		if attack.scale_warning_with_model:
			warning_radius *= visual_scale
		visuals.show_warning(warning_radius, combat.get_progress())
	else:
		visuals.hide_warning()
	velocity = desired.normalized() * speed + movement.separation + _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * knockback_recovery)
	move_and_slide()
	global_position.y = 0.0
	# Pursuers face their path, rather than walking backwards on an obstacle detour.
	var facing: Vector3 = to_target
	if not movement.keep_distance and desired.length_squared() > 0.001:
		facing = desired.normalized()
	visuals.animate(delta, speed, desired, facing, _flash)
	if distance < radius + contact_reach and _contact_remaining <= 0.0:
		_contact_remaining = contact_interval
		visuals.play_attack()
		if target.has_method("take_damage"):
			var context := DamageContext.create(self, self, team, &"contact")
			target.take_damage(contact_damage, context.for_hit(target.global_position, to_target))


func configure_wave(wave: int) -> void:
	wave_number = maxi(1, wave)
	health_component.reset(base_health * (1.0 + float(wave_number - 1) * health_per_wave))
	last_damage_context = null
	_configured = true
	_refresh_dimensions()
	if visuals != null and visuals.is_node_ready():
		visuals.reset_health()


func get_damage_team() -> DamageContext.Team:
	return team


func take_damage(amount: float, context: DamageContext = null) -> void:
	if dead or amount <= 0.0:
		return
	if context != null and not context.can_damage(self):
		return
	last_damage_context = context
	health_component.take_damage(amount)
	if dead:
		return
	_flash = hit_flash_duration
	var away := Vector3.ZERO
	if context != null:
		away = context.hit_direction
	if away.is_zero_approx() and is_instance_valid(target):
		away = global_position - target.global_position
	away.y = 0.0
	_knockback += away.normalized() * knockback_strength
	if is_instance_valid(visuals):
		visuals.show_health(health, max_health)


func heal(amount: float) -> void:
	if dead:
		return
	health_component.heal(amount)
	if is_instance_valid(visuals):
		visuals.show_health(health, max_health)


func _get_configuration_warnings() -> PackedStringArray:
	if visuals == null or movement == null or combat == null or attack_origin == null:
		return ["Assign Visuals, Movement, Combat and AttackOrigin components."]
	if health_component == null:
		return ["Assign a HealthComponent scene."]
	return []


func _refresh_dimensions() -> void:
	var collider := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null:
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		shape.height = maxf(radius * 2.0, model_hit_height * visual_scale)
		collider.shape = shape
		collider.position.y = shape.height * 0.5
	var presentation := get_node_or_null("Visuals") as ZombieVisuals
	if presentation != null:
		presentation.set_dimensions(visual_scale)


func _die() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	particles_requested.emit(global_position + Vector3.UP * 0.65, death_color, death_particle_count)
	defeated.emit(self)
	var death_duration: float = visuals.play_death()
	await get_tree().create_timer(death_duration + corpse_linger, false).timeout
	queue_free()
