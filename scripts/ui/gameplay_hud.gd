class_name GameplayHUD
extends "res://scripts/ui/ui_view.gd"
## Persistent, scene-authored gameplay widgets. No menu or animation state.

@onready var health_bar: ProgressBar = $BottomBar/SurvivalPanel/SurvivalStats/HealthBar
@onready var health_label: Label = $BottomBar/SurvivalPanel/SurvivalStats/HealthLabel
@onready var score_label: Label = $TopBar/ScorePanel/ScoreStats/ScoreLabel
@onready var wave_label: Label = $TopBar/WavePanel/WaveStats/WaveLabel
@onready var enemies_label: Label = $TopBar/WavePanel/WaveStats/EnemiesLabel
@onready var ammo_label: Label = $BottomBar/WeaponPanel/WeaponStats/AmmoLabel
@onready var weapon_label: Label = $BottomBar/WeaponPanel/WeaponStats/WeaponLabel
@onready var grenades_label: Label = $BottomBar/ObjectiveColumn/GrenadesLabel
@onready var reload_bar: ProgressBar = $BottomBar/WeaponPanel/WeaponStats/ReloadBar
@onready var dash_bar: ProgressBar = $BottomBar/SurvivalPanel/SurvivalStats/DashRow/DashBar
@onready var dash_label: Label = $BottomBar/SurvivalPanel/SurvivalStats/DashRow/DashLabel
@onready var objective_label: Label = $BottomBar/ObjectiveColumn/ObjectiveLabel
@onready var time_label: Label = $TopBar/ScorePanel/ScoreStats/TimeLabel


func _ready() -> void:
	for panel in [
		$TopBar/IdentityPanel,
		$TopBar/WavePanel,
		$TopBar/ScorePanel,
		$BottomBar/SurvivalPanel,
		$BottomBar/WeaponPanel
	]:
		_style_panel(panel)
	_style_label($TopBar/IdentityPanel/Identity/BrandLabel, 22, CYAN)
	_style_label($TopBar/IdentityPanel/Identity/StatusLabel, 11, MUTED)
	_style_label(wave_label, 22)
	_style_label(enemies_label, 12, AMBER)
	_style_label(score_label, 24, CYAN)
	_style_label(time_label, 11, MUTED)
	_style_label(health_label, 14)
	_style_label(dash_label, 11, CYAN)
	_style_label(objective_label, 13, AMBER)
	_style_label(grenades_label, 14, AMBER)
	_style_label($BottomBar/ObjectiveColumn/ControlsHint, 11, MUTED)
	_style_label(weapon_label, 12, AMBER)
	_style_label(ammo_label, 26)
	_style_bar(health_bar, CYAN)
	_style_bar(dash_bar, CYAN)
	_style_bar(reload_bar, AMBER)


func update_stats(data: Dictionary) -> void:
	var hp: float = float(data.get("health", 100))
	var max_hp: float = maxf(1.0, float(data.get("max_health", 100)))
	health_bar.value = hp / max_hp
	health_label.text = "INTEGRIDAD  %d / %d" % [ceili(hp), ceili(max_hp)]
	health_label.modulate = RED if hp / max_hp < 0.3 else WHITE
	score_label.text = "%06d" % int(data.get("score", 0))
	wave_label.text = (
		"OLEADA %02d / %02d" % [int(data.get("wave", 1)), int(data.get("wave_count", 8))]
	)
	enemies_label.text = "HOSTILES  %02d" % int(data.get("enemies", 0))
	var reloading: bool = bool(data.get("reloading", false))
	ammo_label.text = (
		"RECARGANDO…"
		if reloading
		else "%02d / %02d" % [int(data.get("ammo", 0)), int(data.get("magazine", 0))]
	)
	ammo_label.add_theme_font_size_override("font_size", 20 if reloading else 26)
	ammo_label.modulate = AMBER if reloading or int(data.get("ammo", 0)) == 0 else WHITE
	weapon_label.text = str(data.get("weapon", "PISTOLA")).to_upper()
	var grenades: int = int(data.get("grenades", 0))
	grenades_label.text = (
		"GRANADAS  %d / %d  ·  G / CLIC DER. / B" % [grenades, int(data.get("max_grenades", 4))]
	)
	grenades_label.modulate = AMBER if grenades > 0 else MUTED
	reload_bar.value = (
		clampf(float(data.get("reload_progress", 0)), 0, 1)
		if reloading
		else float(data.get("ammo", 0)) / maxf(1.0, float(data.get("magazine", 1)))
	)
	var ready: bool = bool(data.get("dash_ready", true))
	dash_bar.value = 1.0 if ready else clampf(float(data.get("dash_progress", 0)), 0, 1)
	dash_label.text = "ESQUIVA LISTA" if ready else "RECUPERANDO…"
	dash_label.modulate = CYAN if ready else MUTED
	var seconds: int = int(data.get("time", 0))
	time_label.text = "TIEMPO  %02d:%02d" % [seconds / 60, seconds % 60]
	objective_label.text = str(data.get("objective", "ELIMINA LA HORDA"))
