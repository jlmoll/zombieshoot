class_name PerkDefinition
extends Resource
## Shared, read-only content. Receivers apply these parameters to their local state.

@export_group("Identity")
@export var id: StringName
@export var title: String
@export_multiline var description: String
@export_group("Survivor effects")
@export_range(0.01, 10.0) var move_speed_multiplier: float = 1.0
@export_range(0.01, 10.0) var dash_cooldown_multiplier: float = 1.0
@export_range(0.0, 1000.0) var max_health_bonus: float = 0.0
@export_range(0.0, 1000.0) var heal_amount: float = 0.0
@export var full_heal: bool = false
@export_group("Equipment effects")
@export_range(0.01, 10.0) var damage_multiplier: float = 1.0
@export_range(0.01, 10.0) var fire_rate_multiplier: float = 1.0
@export_range(0.01, 10.0) var reload_multiplier: float = 1.0
@export_range(0.01, 10.0) var magazine_multiplier: float = 1.0
@export_range(0, 100) var pierce_bonus: int = 0
@export var refill_ammo: bool = false


func get_choice() -> Dictionary:
	return {"id": str(id), "title": title, "description": description}
