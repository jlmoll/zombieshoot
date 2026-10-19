class_name GameHUD
extends CanvasLayer
## Public HUD facade. Simulation and pause state belong to the game.
## Instantiate scenes/ui/hud.tscn so each presentation component is explicit.

signal start_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal upgrade_selected(id: String)
signal mute_toggled(enabled: bool)

@onready var gameplay: GameplayHUD = $GameplayHUD
@onready var menus: MenuScreens = $MenuScreens
@onready var feedback: HudFeedback = $HudFeedback


func _ready() -> void:
	menus.start_requested.connect(start_requested.emit)
	menus.resume_requested.connect(resume_requested.emit)
	menus.restart_requested.connect(restart_requested.emit)
	menus.menu_requested.connect(menu_requested.emit)
	menus.upgrade_selected.connect(upgrade_selected.emit)
	menus.mute_toggled.connect(mute_toggled.emit)


func show_title(best: int) -> void:
	feedback.clear_banner()
	gameplay.hide()
	menus.show_title(best)


func show_pause() -> void:
	feedback.clear_banner()
	menus.show_pause()


func show_configuration_error(errors: PackedStringArray) -> void:
	feedback.clear_banner()
	gameplay.hide()
	menus.show_configuration_error(errors)


func show_game_over(score: int, wave: int, best: int, victory: bool = false) -> void:
	feedback.clear_banner()
	gameplay.hide()
	menus.show_game_over(score, wave, best, victory)


func show_upgrades(choices: Array) -> void:
	feedback.clear_banner()
	menus.show_upgrades(choices)


func show_gameplay() -> void:
	menus.hide()
	gameplay.show()


func update_stats(data: Dictionary) -> void:
	gameplay.update_stats(data)


func set_banner(title: String, subtitle: String = "", duration: float = 2.5) -> void:
	if not menus.visible:
		feedback.set_banner(title, subtitle, duration)


func set_damage_flash() -> void:
	feedback.set_damage_flash()


func set_muted(enabled: bool) -> void:
	menus.set_muted(enabled)
