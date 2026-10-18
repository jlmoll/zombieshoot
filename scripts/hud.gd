class_name GameHUD
extends CanvasLayer
## Presentation only. The game owns pause state and all simulation decisions.

signal start_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal upgrade_selected(id: String)
signal mute_toggled(enabled: bool)

const INK := Color("0b141c")
const PANEL := Color("111f2a")
const CYAN := Color("68e5d1")
const AMBER := Color("f4ba65")
const WHITE := Color("edf5f3")
const MUTED := Color("8babb2")
const RED := Color("f37777")

var _root: Control
var _gameplay: Control
var _modal: Control
var _modal_content: Control
var _health: ProgressBar
var _health_label: Label
var _score: Label
var _wave: Label
var _enemies: Label
var _ammo: Label
var _weapon: Label
var _reload: ProgressBar
var _dash: ProgressBar
var _dash_label: Label
var _objective: Label
var _time: Label
var _banner: VBoxContainer
var _banner_title: Label
var _banner_subtitle: Label
var _banner_timer: float = 0.0
var _flash: ColorRect
var _flash_amount: float = 0.0
var _muted: bool = false
var _sound_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_gameplay()
	_build_banner()
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0.9, 0.12, 0.12, 0)
	_root.add_child(_flash)
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_modal)
	_gameplay.hide()
	_modal.hide()


func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer = maxf(0.0, _banner_timer - delta)
		_banner.modulate.a = minf(1.0, _banner_timer * 2.0)
		_banner.visible = _banner_timer > 0.0
	_flash_amount = maxf(0.0, _flash_amount - delta * 1.7)
	_flash.color.a = _flash_amount


func _style(background: Color, border: Color = Color.TRANSPARENT, radius: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box


func _label(text: String, size: int = 18, color: Color = WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _bar(color: Color, width: float = 240.0, height: float = 8.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, height)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := _style(Color("263741"), Color.TRANSPARENT, 3)
	var fill := _style(color, Color.TRANSPARENT, 3)
	for box in [background, fill]:
		box.content_margin_left = 0
		box.content_margin_right = 0
		box.content_margin_top = 0
		box.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	bar.max_value = 1.0
	bar.value = 1.0
	return bar


func _panel(parent: Node, minimum: Vector2 = Vector2.ZERO) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	panel.add_theme_stylebox_override("panel", _style(Color(PANEL, 0.93), Color("2a424a")))
	parent.add_child(panel)
	return panel


func _column(parent: Node, separation: int = 8) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	parent.add_child(column)
	return column


func _button(text: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK if primary else WHITE)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_stylebox_override("normal", _style(CYAN if primary else Color("182b36"), CYAN if primary else Color("34505b"), 5))
	button.add_theme_stylebox_override("hover", _style(WHITE, CYAN, 5))
	button.add_theme_stylebox_override("pressed", _style(AMBER, AMBER, 5))
	button.add_theme_stylebox_override("focus", _style(Color(0.4, 0.9, 0.82, 0.18), CYAN, 5))
	button.pressed.connect(action)
	return button


func _build_gameplay() -> void:
	_gameplay = Control.new()
	_gameplay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gameplay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_gameplay)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28
	top.offset_top = 24
	top.offset_right = -28
	top.add_theme_constant_override("separation", 18)
	_gameplay.add_child(top)
	var identity := _column(_panel(top), 1)
	identity.add_child(_label("DEAD SHIFT", 22, CYAN))
	identity.add_child(_label("CONTENCIÓN // EN CURSO", 11, MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	var wave_column := _column(_panel(top), 2)
	_wave = _label("OLEADA 01 / 08", 22)
	_enemies = _label("HOSTILES  0", 12, AMBER)
	wave_column.add_child(_wave)
	wave_column.add_child(_enemies)
	var score_column := _column(_panel(top, Vector2(160, 0)), 2)
	_score = _label("000000", 24, CYAN)
	_time = _label("TIEMPO  00:00", 11, MUTED)
	score_column.add_child(_score)
	score_column.add_child(_time)
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 28
	bottom.offset_right = -28
	bottom.offset_top = -116
	bottom.offset_bottom = -24
	bottom.add_theme_constant_override("separation", 20)
	_gameplay.add_child(bottom)
	var survival := _column(_panel(bottom, Vector2(280, 0)), 7)
	_health_label = _label("INTEGRIDAD  100 / 100", 14)
	_health = _bar(CYAN, 250, 10)
	survival.add_child(_health_label)
	survival.add_child(_health)
	var dash_row := HBoxContainer.new()
	dash_row.add_theme_constant_override("separation", 12)
	survival.add_child(dash_row)
	_dash_label = _label("ESQUIVA LISTA", 11, CYAN)
	dash_row.add_child(_dash_label)
	_dash = _bar(CYAN, 95, 5)
	_dash.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dash_row.add_child(_dash)
	var middle := _column(bottom, 4)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_END
	_objective = _label("ELIMINA LA HORDA", 13, AMBER)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(_objective)
	var hint := _label("ESPACIO · ESQUIVAR     Q · ARMA     ESC · PAUSA", 11, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(hint)
	var gun := _column(_panel(bottom, Vector2(265, 0)), 2)
	_weapon = _label("PISTOLA", 12, AMBER)
	_ammo = _label("12 / 12", 26)
	_reload = _bar(AMBER, 225, 5)
	gun.add_child(_weapon)
	gun.add_child(_ammo)
	gun.add_child(_reload)


func _build_banner() -> void:
	_banner = VBoxContainer.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -340
	_banner.offset_right = 340
	_banner.offset_top = 132
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_title = _label("", 34, AMBER)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_subtitle = _label("", 15, WHITE)
	_banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner.add_child(_banner_subtitle)
	_banner.hide()
	_root.add_child(_banner)


func _clear_modal() -> void:
	for child in _modal.get_children():
		_modal.remove_child(child)
		child.queue_free()
	_modal.show()
	_banner.hide()
	_banner_timer = 0.0
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.055, 0.075, 0.94)
	_modal.add_child(shade)
	var top_line := ColorRect.new()
	top_line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_line.offset_top = 0
	top_line.offset_bottom = 4
	top_line.color = CYAN
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(top_line)
	var stamp := _label("NIGHT OPERATIONS DIVISION  /  SECTOR 07", 12, MUTED)
	stamp.position = Vector2(38, 28)
	_modal.add_child(stamp)
	var footer := _label("PROTOTIPO 3D  ·  SOBREVIVE. ADÁPTATE. CONTÉN.", 12, MUTED)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left = 38
	footer.offset_top = -44
	footer.offset_bottom = -20
	_modal.add_child(footer)


func _center_content(width: float = 700.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 32
	center.offset_right = -32
	center.offset_top = 64
	center.offset_bottom = -64
	_modal.add_child(center)
	var column := _column(center, 18)
	column.custom_minimum_size.x = width
	_modal_content = column
	return column


func show_title(best: int) -> void:
	_clear_modal()
	_gameplay.hide()
	var column := _center_content(1050)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 70)
	column.add_child(row)
	var left := _column(row, 8)
	left.custom_minimum_size.x = 480
	left.add_child(_label("PROTOCOLO DE CONTENCIÓN", 15, CYAN))
	left.add_child(_label("DEAD\nSHIFT", 84, WHITE))
	left.add_child(_label("La noche es larga. Tu cargador, no.", 20, AMBER))
	var gap := Control.new()
	gap.custom_minimum_size.y = 16
	left.add_child(gap)
	var play := _button("INICIAR OPERACIÓN    →", func() -> void: start_requested.emit(), true)
	left.add_child(play)
	_sound_button = _button(_sound_text(), _toggle_sound)
	left.add_child(_sound_button)
	left.add_child(_label("RÉCORD DE CONTENCIÓN   %06d" % best, 14, MUTED))
	var right := _column(_panel(row, Vector2(430, 0)), 14)
	right.add_child(_label("01 / SOBREVIVE A LA NOCHE", 19, CYAN))
	var brief := _label("Ocho oleadas. Hordas crecientes.\nMejora tu equipo entre ataques y\nacaba con la amenaza del sector.", 17)
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(brief)
	right.add_child(HSeparator.new())
	right.add_child(_label("TECLADO + RATÓN", 12, AMBER))
	right.add_child(_label("WASD   Moverse\nRatón + clic izq.   Apuntar / disparar\nEspacio   Esquivar\nR   Recargar\nQ / 1–3 / rueda   Cambiar arma\nEsc / P   Pausa", 15, WHITE))
	right.add_child(HSeparator.new())
	right.add_child(_label("MANDO · DOBLE STICK", 12, AMBER))
	right.add_child(_label("Izq. mover · Der. apuntar y disparar\nRT / RB disparar · A / LB esquivar\nX recargar · Y arma · Start pausa", 14))
	play.call_deferred("grab_focus")


func show_gameplay() -> void:
	_modal.hide()
	_gameplay.show()


func show_pause() -> void:
	_clear_modal()
	var column := _center_content(480)
	column.add_child(_label("OPERACIÓN EN SUSPENSO", 14, CYAN))
	column.add_child(_label("PAUSA", 64))
	column.add_child(_label("Respira. La horda puede esperar.", 18, MUTED))
	var resume := _button("CONTINUAR    →", func() -> void: resume_requested.emit(), true)
	column.add_child(resume)
	column.add_child(_button("REINICIAR OPERACIÓN", func() -> void: restart_requested.emit()))
	_sound_button = _button(_sound_text(), _toggle_sound)
	column.add_child(_sound_button)
	column.add_child(_button("VOLVER AL MENÚ", func() -> void: menu_requested.emit()))
	resume.call_deferred("grab_focus")


func show_game_over(score: int, wave: int, best: int, victory: bool = false) -> void:
	_clear_modal()
	_gameplay.hide()
	var column := _center_content(620)
	column.add_child(_label("TRANSMISIÓN FINAL // SECTOR 07", 14, CYAN if victory else RED))
	column.add_child(_label("AMANECER" if victory else "SEÑAL PERDIDA", 60))
	column.add_child(_label("Sector contenido. Has sobrevivido a la noche." if victory else "El turno ha terminado. Vuelve mejor preparado.", 18, MUTED))
	var results := _column(_panel(column), 8)
	results.add_child(_label("PUNTUACIÓN    %06d" % score, 32, AMBER))
	results.add_child(_label("OLEADA  %02d     /     RÉCORD  %06d" % [wave, best], 18, CYAN))
	var again := _button("NUEVA OPERACIÓN    →", func() -> void: restart_requested.emit(), true)
	column.add_child(again)
	column.add_child(_button("VOLVER AL MENÚ", func() -> void: menu_requested.emit()))
	again.call_deferred("grab_focus")


func show_upgrades(choices: Array) -> void:
	_clear_modal()
	var column := _center_content(1060)
	column.add_child(_label("SUMINISTROS DISPONIBLES", 14, CYAN))
	column.add_child(_label("ADÁPTATE O CAE", 52))
	column.add_child(_label("Elige una mejora permanente para esta operación.", 18, MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	var first: Button
	for index in choices.size():
		var choice: Dictionary = choices[index]
		var id: String = str(choice.get("id", ""))
		var card := _column(_panel(row, Vector2(335, 255)), 14)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(_label("MEJORA / 0%d" % (index + 1), 12, CYAN))
		var heading := _label(str(choice.get("title", "MEJORA")), 23)
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(heading)
		var description := _label(str(choice.get("description", "")), 16, MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size = Vector2(285, 85)
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(description)
		var select := _button("ELEGIR    →", _select_upgrade.bind(id), true)
		card.add_child(select)
		if first == null:
			first = select
	if first != null:
		first.call_deferred("grab_focus")


func _select_upgrade(id: String) -> void:
	# Hide immediately to prevent duplicate activation while the game changes state.
	_modal.hide()
	upgrade_selected.emit(id)


func _sound_text() -> String:
	return "SONIDO: SILENCIADO" if _muted else "SONIDO: ACTIVADO"


func _toggle_sound() -> void:
	set_muted(not _muted)
	mute_toggled.emit(_muted)


func set_muted(enabled: bool) -> void:
	_muted = enabled
	if is_instance_valid(_sound_button):
		_sound_button.text = _sound_text()


func update_stats(data: Dictionary) -> void:
	var hp: float = float(data.get("health", 100))
	var max_hp: float = maxf(1.0, float(data.get("max_health", 100)))
	_health.value = hp / max_hp
	_health_label.text = "INTEGRIDAD  %d / %d" % [ceili(hp), ceili(max_hp)]
	_health_label.modulate = RED if hp / max_hp < 0.3 else WHITE
	_score.text = "%06d" % int(data.get("score", 0))
	_wave.text = "OLEADA %02d / 08" % int(data.get("wave", 1))
	_enemies.text = "HOSTILES  %02d" % int(data.get("enemies", 0))
	var reloading: bool = bool(data.get("reloading", false))
	_ammo.text = "RECARGANDO…" if reloading else "%02d / %02d" % [int(data.get("ammo", 0)), int(data.get("magazine", 0))]
	_ammo.add_theme_font_size_override("font_size", 20 if reloading else 26)
	_ammo.modulate = AMBER if reloading or int(data.get("ammo", 0)) == 0 else WHITE
	_weapon.text = str(data.get("weapon", "PISTOLA")).to_upper()
	_reload.value = clampf(float(data.get("reload_progress", 0)), 0, 1) if reloading else float(data.get("ammo", 0)) / maxf(1.0, float(data.get("magazine", 1)))
	var ready: bool = bool(data.get("dash_ready", true))
	_dash.value = 1.0 if ready else clampf(float(data.get("dash_progress", 0)), 0, 1)
	_dash_label.text = "ESQUIVA LISTA" if ready else "RECUPERANDO…"
	_dash_label.modulate = CYAN if ready else MUTED
	var seconds: int = int(data.get("time", 0))
	_time.text = "TIEMPO  %02d:%02d" % [seconds / 60, seconds % 60]
	_objective.text = str(data.get("objective", "ELIMINA LA HORDA"))


func set_banner(title: String, subtitle: String = "", duration: float = 2.5) -> void:
	_banner_title.text = title
	_banner_subtitle.text = subtitle
	_banner_timer = duration
	_banner.modulate.a = 1.0
	_banner.visible = not _modal.visible


func set_damage_flash() -> void:
	_flash_amount = 0.28
