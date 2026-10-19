class_name PerkCatalog
extends RefCounted
## Stable IDs and legacy aliases resolve to authored, shared perk definitions.

const OFFERED: Array[PerkDefinition] = [
	preload("res://assets/perks/damage.tres"),
	preload("res://assets/perks/speed.tres"),
	preload("res://assets/perks/fire_rate.tres"),
	preload("res://assets/perks/health.tres"),
	preload("res://assets/perks/reload.tres"),
	preload("res://assets/perks/dash.tres"),
]
const EXTRA: Array[PerkDefinition] = [
	preload("res://assets/perks/heal.tres"),
	preload("res://assets/perks/magazine.tres"),
	preload("res://assets/perks/pierce.tres"),
]
const ALIASES: Dictionary = {
	"power": "damage",
	"movement": "speed",
	"vitality": "health",
	"firerate": "fire_rate",
	"ammo": "magazine",
}


static func find(id: String) -> PerkDefinition:
	var canonical: String = ALIASES.get(id, id)
	for definition in OFFERED + EXTRA:
		if str(definition.id) == canonical:
			return definition
	return null


static func choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in OFFERED:
		result.append(definition.get_choice())
	return result
