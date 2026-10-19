class_name WeaponController
extends Node
## Owns equipment selection and shared switch lockout. Weapons own their state.

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

@export_range(0.0, 2.0) var switch_delay: float = 0.12
@export var switch_sound: String = "switch"

var weapons: Array[Weapon] = []
var selected_index: int = 0
var cooldown_remaining: float = 0.0
var wielder: Node:
	set(value):
		wielder = value
		for weapon in weapons:
			weapon.wielder = value
var current_weapon: Weapon:
	get:
		return weapons[selected_index] if not weapons.is_empty() else null


func _ready() -> void:
	for child in get_children():
		if child is Weapon:
			weapons.append(child)
			child.wielder = wielder
			child.projectile_requested.connect(projectile_requested.emit)
			child.projectile_spawn_requested.connect(projectile_spawn_requested.emit)
			child.state_changed.connect(state_changed.emit)
			child.fired.connect(fired.emit)
			child.sound_requested.connect(sound_requested.emit)
			child.trauma_requested.connect(trauma_requested.emit)
	assert(not weapons.is_empty(), "WeaponController needs at least one Weapon scene.")


func mount(socket: Node3D) -> void:
	for weapon in weapons:
		weapon.reparent(socket, false)


func reset() -> void:
	selected_index = 0
	cooldown_remaining = 0.0
	for index in range(weapons.size()):
		weapons[index].reset()
		weapons[index].set_equipped(index == selected_index)
	state_changed.emit()


func advance(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	for weapon in weapons:
		weapon.advance(delta)


func select_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == selected_index:
		return
	current_weapon.set_equipped(false)
	selected_index = index
	current_weapon.set_equipped(true)
	cooldown_remaining = maxf(cooldown_remaining, switch_delay)
	sound_requested.emit(switch_sound)
	state_changed.emit()


func cycle_weapon(step: int = 1) -> void:
	select_weapon(posmod(selected_index + step, weapons.size()))


func get_muzzle_position() -> Vector3:
	return current_weapon.presentation.get_muzzle_position()


func try_fire(heading: Vector3, wielder_position: Vector3) -> bool:
	if cooldown_remaining > 0.0:
		return false
	if current_weapon.try_fire(heading, wielder_position):
		# Keep cadence across switches, so swapping cannot bypass a slow weapon.
		cooldown_remaining = current_weapon.cooldown_remaining
		return true
	return false


func start_reload() -> void:
	current_weapon.start_reload()


func refill() -> void:
	for weapon in weapons:
		weapon.magazine.refill()
	state_changed.emit()


func stop() -> void:
	for weapon in weapons:
		weapon.magazine.cancel_reload()
		weapon.presentation.reset()


func apply_upgrade(id: String) -> void:
	var definition := PerkCatalog.find(id)
	if definition != null:
		apply_perk(definition)


func apply_perk(definition: PerkDefinition) -> void:
	for weapon in weapons:
		weapon.damage_multiplier *= definition.damage_multiplier
		weapon.fire_rate_multiplier *= definition.fire_rate_multiplier
		weapon.reload_multiplier *= definition.reload_multiplier
		weapon.magazine.capacity = ceili(weapon.magazine.capacity * definition.magazine_multiplier)
		weapon.penetration_bonus += definition.pierce_bonus
		if definition.refill_ammo:
			weapon.magazine.refill()
	state_changed.emit()
