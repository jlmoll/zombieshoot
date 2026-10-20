class_name SaveData
extends Node
## Persistent preferences and record. Gameplay never opens save files directly.

const PATH: String = "user://dead_shift.cfg"
var best_score: int = 0
var muted: bool = false
var lighting_preset: int = 0


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		best_score = int(config.get_value("run", "best", 0))
		muted = bool(config.get_value("settings", "muted", false))
		lighting_preset = clampi(int(config.get_value("settings", "lighting_preset", 0)), 0, 2)


func record_score(score: int) -> void:
	best_score = maxi(best_score, score)
	save()


func set_muted(enabled: bool) -> void:
	muted = enabled
	save()


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("run", "best", best_score)
	config.set_value("settings", "muted", muted)
	config.set_value("settings", "lighting_preset", lighting_preset)
	var error: Error = config.save(PATH)
	if error != OK:
		push_warning("Could not save preferences: %s" % error_string(error))


func set_lighting_preset(value: int) -> void:
	lighting_preset = clampi(value, 0, 2)
	save()
