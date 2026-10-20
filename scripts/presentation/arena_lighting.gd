class_name ArenaLighting
extends Node3D
## Three clean miniature palettes. Boss lighting temporarily overrides the saved choice.

enum Preset { NIGHT, EMERGENCY, CONTAINMENT }

const LABELS: Array[String] = ["TURNO NOCTURNO", "EMERGENCIA", "CONTENCIÓN"]
const ACCENTS: Array[Color] = [Color("#ffbd69"), Color("#ff3446"), Color("#9fffa6")]
const AMBIENTS: Array[Color] = [Color("#718da9"), Color("#788ba6"), Color("#92b4b7")]
const KEYS: Array[Color] = [Color("#b9d5ed"), Color("#c5d9ed"), Color("#d9eeeb")]
const AMBIENT_ENERGY: Array[float] = [0.24, 0.22, 0.30]
const KEY_ENERGY: Array[float] = [0.8, 0.7, 0.95]
var selected_preset: int = Preset.NIGHT
var boss_active: bool = false
var active_preset: int = Preset.NIGHT
var _transition: Tween
var _lights: Array[OmniLight3D] = []
var _lenses: Array[StandardMaterial3D] = []
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var key_light: DirectionalLight3D = $KeyLight
@onready var fill_light: DirectionalLight3D = $FillLight


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world_environment.environment = world_environment.environment.duplicate()
	_collect_fixtures(get_parent())
	_apply(false)


func select_preset(value: int, animate: bool = true) -> void:
	selected_preset = clampi(value, Preset.NIGHT, Preset.CONTAINMENT)
	_apply(animate)


func set_boss_active(enabled: bool) -> void:
	boss_active = enabled
	_apply(true)


func _collect_fixtures(node: Node) -> void:
	for child in node.get_children():
		if child is OmniLight3D and child.is_in_group("miniature_accent"):
			_lights.append(child)
		elif child is MeshInstance3D and child.is_in_group("miniature_lens"):
			var material := child.material_override.duplicate() as StandardMaterial3D
			child.material_override = material
			_lenses.append(material)
		_collect_fixtures(child)


func _apply(animate: bool) -> void:
	active_preset = Preset.EMERGENCY if boss_active else selected_preset
	if _transition != null:
		_transition.kill()
	if animate:
		_transition = create_tween().set_parallel(true)
		_transition.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_transition.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var duration: float = 1.2 if animate else 0.0
	var environment := world_environment.environment
	_blend(environment, "ambient_light_color", AMBIENTS[active_preset], duration)
	_blend(environment, "ambient_light_energy", AMBIENT_ENERGY[active_preset], duration)
	_blend(key_light, "light_color", KEYS[active_preset], duration)
	_blend(key_light, "light_energy", KEY_ENERGY[active_preset], duration)
	_blend(fill_light, "light_energy", 0.16, duration)
	for light in _lights:
		_blend(light, "light_color", ACCENTS[active_preset], duration)
		_blend(light, "light_energy", 3.2 if active_preset == Preset.EMERGENCY else 2.8, duration)
	for material in _lenses:
		_blend(material, "albedo_color", ACCENTS[active_preset], duration)
		_blend(material, "emission", ACCENTS[active_preset], duration)


func _blend(target: Object, property: NodePath, value: Variant, duration: float) -> void:
	if duration == 0.0:
		target.set_indexed(property, value)
	else:
		_transition.tween_property(target, property, value, duration)
