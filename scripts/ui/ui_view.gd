class_name UIView
extends Control
## Shared visual language and named builders for dynamic menu content.

const INK := Color("0b141c")
const PANEL := Color("111f2a")
const CYAN := Color("68e5d1")
const AMBER := Color("f4ba65")
const WHITE := Color("edf5f3")
const MUTED := Color("8babb2")
const RED := Color("f37777")


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


func _style_label(label: Label, size: int = 18, color: Color = WHITE) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _label(node_name: String, text: String, size: int = 18, color: Color = WHITE) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	_style_label(label, size, color)
	return label


func _style_bar(bar: ProgressBar, color: Color) -> void:
	var background := _style(Color("263741"), Color.TRANSPARENT, 3)
	var fill := _style(color, Color.TRANSPARENT, 3)
	for box in [background, fill]:
		box.content_margin_left = 0
		box.content_margin_right = 0
		box.content_margin_top = 0
		box.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)


func _style_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", _style(Color(PANEL, 0.93), Color("2a424a")))


func _panel(node_name: String, parent: Node, minimum: Vector2 = Vector2.ZERO) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.custom_minimum_size = minimum
	_style_panel(panel)
	parent.add_child(panel)
	return panel


func _column(node_name: String, parent: Node, separation: int = 8) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = node_name
	column.add_theme_constant_override("separation", separation)
	parent.add_child(column)
	return column


func _button(node_name: String, text: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK if primary else WHITE)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_stylebox_override(
		"normal",
		_style(CYAN if primary else Color("182b36"), CYAN if primary else Color("34505b"), 5)
	)
	button.add_theme_stylebox_override("hover", _style(WHITE, CYAN, 5))
	button.add_theme_stylebox_override("pressed", _style(AMBER, AMBER, 5))
	button.add_theme_stylebox_override("focus", _style(Color(0.4, 0.9, 0.82, 0.18), CYAN, 5))
	button.pressed.connect(action)
	return button
