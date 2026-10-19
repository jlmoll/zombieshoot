class_name EnemyCombat
extends Node
## Shared attack selection, cooldown and telegraph lifecycle; payloads are child nodes.

signal attack_started(duration: float)
signal sound_requested(kind: String)
signal projectile_requested(origin: Vector3, direction: Vector3, damage: float, speed: float)
signal projectile_spawn_requested(
	origin: Vector3,
	direction: Vector3,
	damage: float,
	speed: float,
	pierce: int,
	context: DamageContext,
	scene: PackedScene
)
signal particles_requested(at: Vector3, color: Color, count: int)
signal trauma_requested(amount: float)

## Espera mínima en segundos tras aparecer antes de intentar el primer ataque especial.
@export_range(0.0, 10.0) var initial_delay_min: float = 1.2
## Espera máxima en segundos. Se elige un valor aleatorio entre ambos límites por enemigo.
@export_range(0.0, 10.0) var initial_delay_max: float = 2.8
## Identificador del sonido reproducido cuando comienza el aviso de un ataque especial.
@export var warning_sound: String = "warning"
## Identificador del sonido reproducido al ejecutar el ataque después de su preparación.
@export var attack_sound: String = "enemy_shoot"
var attacks: Array[EnemyAttack] = []
var current_attack: EnemyAttack
var cooldown_remaining: float = 1.5
var windup_remaining: float = 0.0
var carrier: Node:
	set(value):
		carrier = value
		for attack in attacks:
			_set_carrier(attack)
var _locked_target := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	cooldown_remaining = _rng.randf_range(initial_delay_min, initial_delay_max)
	for child in get_children():
		if child is EnemyAttack:
			attacks.append(child)
			_connect_payload(child)


func advance(
	delta: float,
	distance: float,
	source: Vector3,
	origin: Vector3,
	target: Node3D,
	phase: float,
	enraged: bool
) -> bool:
	cooldown_remaining -= delta
	if windup_remaining <= 0.0 and cooldown_remaining <= 0.0:
		for attack in attacks:
			if attack.can_start(distance):
				current_attack = attack
				_locked_target = target.global_position
				windup_remaining = attack.windup_duration
				cooldown_remaining = attack.cooldown
				attack_started.emit(attack.windup_duration)
				sound_requested.emit(warning_sound)
				break
	if windup_remaining <= 0.0:
		return false
	windup_remaining = maxf(0.0, windup_remaining - delta)
	if windup_remaining <= 0.0:
		current_attack.execute(source, origin, target, _locked_target, phase, enraged)
		sound_requested.emit(attack_sound)
	return true


func get_progress() -> float:
	if current_attack == null:
		return 0.0
	return 1.0 - windup_remaining / current_attack.windup_duration


func _connect_payload(attack: EnemyAttack) -> void:
	attack.carrier = carrier
	attack.projectile_requested.connect(projectile_requested.emit)
	attack.projectile_spawn_requested.connect(projectile_spawn_requested.emit)
	attack.particles_requested.connect(particles_requested.emit)
	attack.trauma_requested.connect(trauma_requested.emit)
	# Composite attacks can contain reusable payloads without selecting those as attacks.
	for child in attack.get_children():
		if child is EnemyAttack:
			_connect_payload(child)


func _set_carrier(attack: EnemyAttack) -> void:
	attack.carrier = carrier
	for child in attack.get_children():
		if child is EnemyAttack:
			_set_carrier(child)
