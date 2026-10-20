class_name MenuScreens
extends "res://scripts/ui/ui_view.gd"
## Owns modal composition and menu intent signals, never simulation state.

signal start_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal upgrade_selected(id: String)
signal mute_toggled(enabled: bool)
signal lighting_selected(preset: int)

var _muted: bool = false
var _sound_button: Button
var _lighting_button: Button
var _lighting_preset: int = 0
@onready var content_center: CenterContainer = $ContentCenter


func _ready() -> void:
	_style_label($DivisionStamp, 12, MUTED)
	_style_label($Footer, 12, MUTED)


func show_title(best: int) -> void:
	var column := _screen("TitleScreen", 1050)
	var row := HBoxContainer.new()
	row.name = "TitleColumns"
	row.add_theme_constant_override("separation", 70)
	column.add_child(row)
	var left := _column("OperationIntro", row, 8)
	left.custom_minimum_size.x = 480
	left.add_child(_label("ProtocolLabel", "PROTOCOLO DE CONTENCIÓN", 15, CYAN))
	left.add_child(_label("GameTitle", "DEAD\nSHIFT", 84, WHITE))
	left.add_child(_label("Tagline", "La noche es larga. Tu cargador, no.", 20, AMBER))
	var gap := Control.new()
	gap.name = "ActionSpacing"
	gap.custom_minimum_size.y = 16
	left.add_child(gap)
	var play := _button("StartButton", "INICIAR OPERACIÓN    →", start_requested.emit, true)
	left.add_child(play)
	_sound_button = _button("SoundButton", _sound_text(), _toggle_sound)
	left.add_child(_sound_button)
	_add_lighting_selector(left)
	left.add_child(_label("BestScore", "RÉCORD DE CONTENCIÓN   %06d" % best, 14, MUTED))
	var right := _column("Instructions", _panel("InstructionsPanel", row, Vector2(430, 0)), 10)
	right.add_child(_label("MissionHeading", "01 / SOBREVIVE A LA NOCHE", 19, CYAN))
	var brief := _label(
		"MissionBrief",
		(
			"Ocho oleadas. Hordas crecientes.\n"
			+ "Mejora tu equipo entre ataques y\nacaba con la amenaza del sector."
		),
		17
	)
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(brief)
	var keyboard_separator := HSeparator.new()
	keyboard_separator.name = "KeyboardSeparator"
	right.add_child(keyboard_separator)
	right.add_child(_label("KeyboardHeading", "TECLADO + RATÓN", 12, AMBER))
	right.add_child(
		_label(
			"KeyboardControls",
			(
				"WASD   Moverse\nRatón + clic izq.   Apuntar / disparar\n"
				+ "Espacio   Esquivar\nG / clic derecho   Granada (+2/oleada, máx. 4)\n"
				+ "R   Recargar\nQ / 1–3 / rueda   Cambiar arma\nEsc / P   Pausa"
			),
			15,
			WHITE
		)
	)
	var controller_separator := HSeparator.new()
	controller_separator.name = "ControllerSeparator"
	right.add_child(controller_separator)
	right.add_child(_label("ControllerHeading", "MANDO · DOBLE STICK", 12, AMBER))
	right.add_child(
		_label(
			"ControllerControls",
			(
				"Izq. mover · Der. apuntar y disparar\nRT / RB disparar · A / LB esquivar\n"
				+ "B granada · X recargar · Y arma · Start pausa"
			),
			14
		)
	)
	_focus_when_ready.call_deferred(play)


func show_pause() -> void:
	var column := _screen("PauseScreen", 480)
	column.add_child(_label("OperationStatus", "OPERACIÓN EN SUSPENSO", 14, CYAN))
	column.add_child(_label("PauseHeading", "PAUSA", 64))
	column.add_child(_label("PauseMessage", "Respira. La horda puede esperar.", 18, MUTED))
	var resume := _button("ResumeButton", "CONTINUAR    →", resume_requested.emit, true)
	column.add_child(resume)
	column.add_child(_button("RestartButton", "REINICIAR OPERACIÓN", restart_requested.emit))
	_sound_button = _button("SoundButton", _sound_text(), _toggle_sound)
	column.add_child(_sound_button)
	_add_lighting_selector(column)
	column.add_child(_button("MenuButton", "VOLVER AL MENÚ", menu_requested.emit))
	_focus_when_ready.call_deferred(resume)


func set_lighting_preset(preset: int) -> void:
	_lighting_preset = clampi(preset, 0, 2)
	if is_instance_valid(_lighting_button):
		_lighting_button.text = "LUZ: %s  →" % ArenaLighting.LABELS[_lighting_preset]


func show_configuration_error(errors: PackedStringArray) -> void:
	var column := _screen("ConfigurationErrorScreen", 920)
	column.add_child(_label("ConfigurationHeading", "REVISAR CONFIGURACIÓN", 40, RED))
	column.add_child(
		_label(
			"ConfigurationMessage",
			"Revisa el contenido del proyecto y vuelve a intentarlo.",
			18,
			MUTED
		)
	)
	var details := RichTextLabel.new()
	details.name = "ConfigurationDetails"
	details.text = "\n".join(errors)
	details.custom_minimum_size = Vector2(800, 180)
	details.add_theme_font_size_override("normal_font_size", 16)
	details.add_theme_color_override("default_color", MUTED)
	column.add_child(details)
	var retry := _button("RestartButton", "VOLVER A INTENTAR    →", restart_requested.emit, true)
	column.add_child(retry)
	column.add_child(_button("MenuButton", "VOLVER AL MENÚ", menu_requested.emit))
	_focus_when_ready.call_deferred(retry)


func show_game_over(score: int, wave: int, best: int, victory: bool = false) -> void:
	var column := _screen("VictoryScreen" if victory else "DefeatScreen", 620)
	column.add_child(
		_label("TransmissionStatus", "TRANSMISIÓN FINAL // SECTOR 07", 14, CYAN if victory else RED)
	)
	column.add_child(_label("ResultHeading", "AMANECER" if victory else "SEÑAL PERDIDA", 60))
	column.add_child(
		_label(
			"ResultMessage",
			(
				"Sector contenido. Has sobrevivido a la noche."
				if victory
				else "El turno ha terminado. Vuelve mejor preparado."
			),
			18,
			MUTED
		)
	)
	var results := _column("ResultStats", _panel("ResultPanel", column), 8)
	results.add_child(_label("FinalScore", "PUNTUACIÓN    %06d" % score, 32, AMBER))
	results.add_child(
		_label("FinalWaveAndBest", "OLEADA  %02d     /     RÉCORD  %06d" % [wave, best], 18, CYAN)
	)
	var again := _button("RestartButton", "NUEVA OPERACIÓN    →", restart_requested.emit, true)
	column.add_child(again)
	column.add_child(_button("MenuButton", "VOLVER AL MENÚ", menu_requested.emit))
	_focus_when_ready.call_deferred(again)


func show_upgrades(choices: Array) -> void:
	var column := _screen("UpgradeScreen", 1060)
	column.add_child(_label("SupplyStatus", "SUMINISTROS DISPONIBLES", 14, CYAN))
	column.add_child(_label("UpgradeHeading", "ADÁPTATE O CAE", 52))
	column.add_child(
		_label("UpgradePrompt", "Elige una mejora permanente para esta operación.", 18, MUTED)
	)
	var row := HBoxContainer.new()
	row.name = "UpgradeChoices"
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	var first: Button
	for index in choices.size():
		var choice: Dictionary = choices[index]
		var id: String = str(choice.get("id", ""))
		var card := _column(
			"UpgradeContent", _panel("UpgradeCard%d" % (index + 1), row, Vector2(335, 255)), 14
		)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(_label("ChoiceNumber", "MEJORA / 0%d" % (index + 1), 12, CYAN))
		var heading := _label("UpgradeTitle", str(choice.get("title", "MEJORA")), 23)
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(heading)
		var description := _label(
			"UpgradeDescription", str(choice.get("description", "")), 16, MUTED
		)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size = Vector2(285, 85)
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(description)
		var select := _button("SelectButton", "ELEGIR    →", _select_upgrade.bind(id), true)
		card.add_child(select)
		if first == null:
			first = select
	if first != null:
		_focus_when_ready.call_deferred(first)


func set_muted(enabled: bool) -> void:
	_muted = enabled
	if is_instance_valid(_sound_button):
		_sound_button.text = _sound_text()


func _add_lighting_selector(column: VBoxContainer) -> void:
	_lighting_button = _button("LightingButton", "", _cycle_lighting)
	column.add_child(_lighting_button)
	set_lighting_preset(_lighting_preset)
	column.add_child(_label("LightingHint", "Boss: emergencia automática", 13, MUTED))


func _cycle_lighting() -> void:
	set_lighting_preset((_lighting_preset + 1) % ArenaLighting.LABELS.size())
	lighting_selected.emit(_lighting_preset)


func _clear_content() -> void:
	for child in content_center.get_children():
		content_center.remove_child(child)
		child.queue_free()
	_sound_button = null
	show()


func _screen(node_name: String, width: float) -> VBoxContainer:
	_clear_content()
	var column := _column(node_name, content_center, 18)
	column.custom_minimum_size.x = width
	return column


func _focus_when_ready(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()


func _select_upgrade(id: String) -> void:
	# Hide immediately to prevent duplicate selection while the game changes state.
	hide()
	upgrade_selected.emit(id)


func _sound_text() -> String:
	return "SONIDO: SILENCIADO" if _muted else "SONIDO: ACTIVADO"


func _toggle_sound() -> void:
	set_muted(not _muted)
	mute_toggled.emit(_muted)
