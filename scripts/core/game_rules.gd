class_name GameRules
extends RefCounted
## Shared tuning, independent of scene orchestration.

const WAVE_COUNT: int = 8
const PLAYER_LAYER: int = 1
const WALL_LAYER: int = 2
const ENEMY_LAYER: int = 4
const UPGRADES: Array[Dictionary] = [
	{"id": "damage", "title": "PUNTA HUECA", "description": "+25% de daño con todas las armas."},
	{"id": "speed", "title": "PASO LIGERO", "description": "+15% de velocidad de movimiento."},
	{"id": "fire_rate", "title": "GATILLO RÁPIDO", "description": "+20% de cadencia de disparo."},
	{"id": "health", "title": "SEGUNDO ALIENTO", "description": "+25 de vida máxima y recuperación total."},
	{"id": "reload", "title": "MANOS RÁPIDAS", "description": "Recargas un 20% más rápidas."},
	{"id": "dash", "title": "REFLEJOS", "description": "Recuperas la esquiva un 20% más rápido."},
]
