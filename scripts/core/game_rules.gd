class_name GameRules
extends RefCounted
## Shared tuning, independent of scene orchestration.

const PLAYER_LAYER: int = 1
const WALL_LAYER: int = 2
const ENEMY_LAYER: int = 4
static var UPGRADES: Array[Dictionary] = PerkCatalog.choices()
