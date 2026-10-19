class_name PlayerInput
extends Node
## Input Map profile scoped to one local player. Never polls an unassigned gamepad.

signal command_requested(command: StringName)

const INTENTS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"aim_left", &"aim_right", &"aim_up", &"aim_down",
	&"fire", &"dash", &"reload", &"grenade",
	&"next_weapon", &"previous_weapon", &"weapon_1", &"weapon_2", &"weapon_3",
]
const COMMANDS: Array[StringName] = [
	&"dash", &"reload", &"grenade", &"next_weapon", &"previous_weapon",
	&"weapon_1", &"weapon_2", &"weapon_3",
]

@export_range(1, 2) var player_slot: int = 1
## -2 keeps the devices authored in Input Map; -1 disables this profile's gamepad.
@export_range(-2, 15) var gamepad_device: int = -2
@export var mouse_aim_enabled: bool = true
@export var stick_aim_fires: bool = true

var mouse_aim_active: bool = false
var _actions: Dictionary[StringName, StringName] = {}
var _accepted: Dictionary[StringName, bool] = {}
var _gamepad_bindings: Dictionary[StringName, Array] = {}


func _ready() -> void:
	for intent in INTENTS:
		_actions[intent] = StringName("p%d_%s" % [player_slot, intent])
		assert(InputMap.has_action(_actions[intent]), "Missing action: %s" % _actions[intent])
		# Project defaults survive a session's disabled profile and node replacement.
		var defaults: Dictionary = ProjectSettings.get_setting("input/%s" % _actions[intent], {})
		var bindings: Array[InputEvent] = []
		for event: InputEvent in defaults.get("events", []):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				bindings.append(event.duplicate() as InputEvent)
		_gamepad_bindings[_actions[intent]] = bindings
	mouse_aim_active = owns_mouse()
	if gamepad_device >= -1:
		assign_gamepad(gamepad_device)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _input(event: InputEvent) -> void:
	# Pointer position is presentation input; gameplay presses wait for the UI below.
	if owns_mouse() and event is InputEventMouseMotion:
		mouse_aim_active = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	var matched: bool = false
	for intent in INTENTS:
		var action: StringName = _actions[intent]
		if not event.is_action(action, true) or Input.get_action_raw_strength(action) <= 0.0:
			continue
		matched = true
		_accepted[intent] = true
		if owns_mouse() and event is InputEventMouseButton:
			mouse_aim_active = true
		elif intent in [&"aim_left", &"aim_right", &"aim_up", &"aim_down"]:
			if not get_aim_vector().is_zero_approx():
				mouse_aim_active = false
		if intent in COMMANDS and event.is_action_pressed(action, false, true):
			command_requested.emit(intent)
	if matched:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_accepted.clear()


func action_for(intent: StringName) -> StringName:
	return _actions[intent]


func owns_mouse() -> bool:
	return player_slot == 1 and mouse_aim_enabled


func get_move_vector() -> Vector2:
	return _get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


func get_aim_vector() -> Vector2:
	return _get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")


func wants_to_fire() -> bool:
	var trigger: bool = _strength(&"fire") > InputMap.action_get_deadzone(_actions[&"fire"])
	return trigger or (stick_aim_fires and not get_aim_vector().is_zero_approx())


func assign_gamepad(device: int) -> void:
	# Only this slot's actions change. A lobby can assign P1 keyboard and P2 pad 0.
	gamepad_device = device
	_accepted.clear()
	for action: StringName in _actions.values():
		var bindings: Array[InputEvent] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				bindings.append(event.duplicate() as InputEvent)
				InputMap.action_erase_event(action, event)
		if not bindings.is_empty():
			_gamepad_bindings[action] = bindings
		if device >= 0:
			for event: InputEvent in _gamepad_bindings.get(action, []):
				var binding := event.duplicate() as InputEvent
				binding.device = device
				InputMap.action_add_event(action, binding)
		Input.action_release(action)


func _get_vector(
		left: StringName, right: StringName, up: StringName, down: StringName
) -> Vector2:
	# Filter UI-consumed presses before applying the same radial deadzone as get_vector.
	var vector := Vector2(_strength(right) - _strength(left), _strength(down) - _strength(up))
	var deadzone: float = 0.0
	for intent in [left, right, up, down]:
		deadzone += InputMap.action_get_deadzone(_actions[intent]) * 0.25
	var length: float = vector.length()
	if length <= deadzone:
		return Vector2.ZERO
	return vector.normalized() * clampf((length - deadzone) / maxf(0.001, 1.0 - deadzone), 0.0, 1.0)


func _strength(intent: StringName) -> float:
	var strength: float = Input.get_action_raw_strength(_actions[intent])
	if strength <= 0.0:
		_accepted.erase(intent)
	return strength if _accepted.has(intent) else 0.0


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return
	for intent in INTENTS:
		var action: StringName = _actions[intent]
		for event in InputMap.action_get_events(action):
			if (event is InputEventJoypadButton or event is InputEventJoypadMotion):
				if event.device == device:
					Input.action_release(action)
					_accepted.erase(intent)
					break
