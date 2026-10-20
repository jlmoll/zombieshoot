class_name ArenaLighting
extends Node3D
## Three clean miniature palettes. Boss lighting temporarily overrides the saved choice.

enum Preset { NIGHT, EMERGENCY, CONTAINMENT }

const LABELS: Array[String] = ["TURNO NOCTURNO", "EMERGENCIA", "CONTENCIÓN"]
const ACCENTS: Array[Color] = [Color("#ffbd69"), Color("#ff160c"), Color("#9fffa6")]
const AMBIENTS: Array[Color] = [Color("#718da9"), Color("#392934"), Color("#92b4b7")]
const KEYS: Array[Color] = [Color("#b9d5ed"), Color("#b9c5dc"), Color("#d9eeeb")]
const AMBIENT_ENERGY: Array[float] = [0.14, 0.06, 0.30]
const KEY_ENERGY: Array[float] = [0.45, 0.28, 0.95]
const FILL_ENERGY: Array[float] = [0.08, 0.18, 0.16]
var selected_preset: int = Preset.NIGHT
var boss_active: bool = false
var active_preset: int = Preset.NIGHT
var _transition: Tween
var _lights: Array[OmniLight3D] = []
var _lenses: Array[StandardMaterial3D] = []
var _strips: Array[StandardMaterial3D] = []
var _strip_colors: Array[Color] = []
var _strip_albedos: Array[Color] = []
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
		elif child is MeshInstance3D:
			var material := child.material_override as StandardMaterial3D
			if material != null and material.emission_enabled:
				child.material_override = _register_strip(material)
		elif child is GridMap:
			if child.mesh_library == null:
				continue
			# Private library and meshes keep the red override out of shared map assets.
			child.mesh_library = child.mesh_library.duplicate()
			for item in child.mesh_library.get_item_list():
				var mesh: Mesh = child.mesh_library.get_item_mesh(item)
				if mesh == null:
					continue
				mesh = mesh.duplicate()
				for surface in mesh.get_surface_count():
					var material := mesh.surface_get_material(surface) as StandardMaterial3D
					if material != null and material.emission_enabled:
						mesh.surface_set_material(surface, _register_strip(material))
				child.mesh_library.set_item_mesh(item, mesh)
		_collect_fixtures(child)


func _register_strip(source: StandardMaterial3D) -> StandardMaterial3D:
	var material := source.duplicate() as StandardMaterial3D
	_strips.append(material)
	_strip_colors.append(material.emission)
	_strip_albedos.append(material.albedo_color)
	return material


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
	_blend(
		environment,
		"background_color",
		Color("#060408") if active_preset == Preset.EMERGENCY else Color("#0b1520"),
		duration
	)
	_blend(key_light, "light_color", KEYS[active_preset], duration)
	_blend(key_light, "light_energy", KEY_ENERGY[active_preset], duration)
	_blend(fill_light, "light_energy", FILL_ENERGY[active_preset], duration)
	_blend(
		fill_light,
		"light_color",
		Color("#f03629") if active_preset == Preset.EMERGENCY else Color("#4eaea6"),
		duration
	)
	for light in _lights:
		_blend(light, "light_color", ACCENTS[active_preset], duration)
		_blend(light, "light_energy", 4.3 if active_preset == Preset.EMERGENCY else 2.8, duration)
		_blend(light, "omni_range", 11.5 if active_preset == Preset.EMERGENCY else 8.0, duration)
	for material in _lenses:
		_blend(material, "albedo_color", ACCENTS[active_preset], duration)
		_blend(material, "emission", ACCENTS[active_preset], duration)
	for index in _strips.size():
		var color: Color = (
			ACCENTS[Preset.EMERGENCY] if active_preset == Preset.EMERGENCY else _strip_colors[index]
		)
		_blend(
			_strips[index],
			"albedo_color",
			color if active_preset == Preset.EMERGENCY else _strip_albedos[index],
			duration
		)
		_blend(_strips[index], "emission", color, duration)


func _blend(target: Object, property: NodePath, value: Variant, duration: float) -> void:
	if duration == 0.0:
		target.set_indexed(property, value)
	else:
		_transition.tween_property(target, property, value, duration)
