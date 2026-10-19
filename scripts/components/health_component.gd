@tool
class_name HealthComponent
extends Node
## Per-actor health state. Damage immunity and death presentation belong to actors.

signal health_changed(current: float, maximum: float)
signal died

@export_range(1.0, 100000.0) var maximum: float = 100.0
var current: float = 100.0
var depleted: bool = false
var _initialized: bool = false


func _ready() -> void:
	if not _initialized:
		reset()


func reset(maximum_health: float = -1.0) -> void:
	if maximum_health > 0.0:
		maximum = maxf(1.0, maximum_health)
	current = maximum
	depleted = false
	_initialized = true
	health_changed.emit(current, maximum)


func take_damage(amount: float) -> bool:
	if depleted or amount <= 0.0:
		return false
	set_current(current - amount)
	return true


func heal(amount: float) -> void:
	if not depleted and amount > 0.0:
		set_current(current + amount)


func set_maximum(value: float) -> void:
	maximum = maxf(1.0, value)
	set_current(current)


func set_current(value: float) -> void:
	current = clampf(value, 0.0, maximum)
	health_changed.emit(current, maximum)
	if current <= 0.0 and not depleted:
		depleted = true
		died.emit()
