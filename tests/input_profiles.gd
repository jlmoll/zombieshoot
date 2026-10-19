extends SceneTree
## Exercise actual Input Map events with two actors and two synthetic devices.

var checks: int = 0
var failures: int = 0
var first: Survivor
var second: Survivor


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("INPUT: " + description)


func send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func key(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	return event


func axis(device: int, index: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = index
	event.axis_value = value
	return event


func button(device: int, index: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	event.pressed = pressed
	return event


func run() -> void:
	var scene := load("res://scenes/actors/player.tscn") as PackedScene
	first = scene.instantiate() as Survivor
	second = scene.instantiate() as Survivor
	second.get_node("PlayerInput").player_slot = 2
	root.add_child(first)
	root.add_child(second)
	first.set_physics_process(false)
	second.set_physics_process(false)
	await process_frame
	var p1: PlayerInput = first.controls
	var p2: PlayerInput = second.controls
	check(p1.owns_mouse() and not p2.owns_mouse(), "system pointer belongs only to P1")
	await send(key(KEY_D, true))
	check(p1.get_move_vector().x > 0.99 and p2.get_move_vector().is_zero_approx(),
		"keyboard movement reaches only P1")
	await send(key(KEY_D, false))
	check(p1.get_move_vector().is_zero_approx(), "keyboard release clears movement")
	await send(axis(0, JOY_AXIS_LEFT_X, -1.0))
	check(p1.get_move_vector().x < -0.99 and p2.get_move_vector().is_zero_approx(),
		"pad 0 reaches only its assigned player")
	await send(axis(1, JOY_AXIS_LEFT_Y, 1.0))
	check(p1.get_move_vector().x < -0.99 and p2.get_move_vector().y > 0.99,
		"two pads drive different movement vectors simultaneously")
	await send(axis(0, JOY_AXIS_LEFT_X, 0.1))
	check(p1.get_move_vector().is_zero_approx(), "movement deadzone ignores stick drift")
	await send(axis(0, JOY_AXIS_LEFT_X, 0.15))
	await send(axis(0, JOY_AXIS_LEFT_Y, 0.15))
	check(p1.get_move_vector().length() > 0.0,
		"diagonal input uses a radial deadzone rather than independent axis thresholds")
	await send(axis(0, JOY_AXIS_LEFT_Y, 0.0))
	await send(axis(0, JOY_AXIS_LEFT_X, 0.0))
	await send(axis(1, JOY_AXIS_LEFT_Y, 0.0))
	await send(axis(1, JOY_AXIS_RIGHT_X, 1.0))
	check(p2.get_aim_vector().x > 0.99 and p1.get_aim_vector().is_zero_approx(),
		"aim stick is isolated by player profile")
	check(p2.wants_to_fire() and not p1.wants_to_fire(),
		"right-stick auto-fire reaches only its player")
	await send(axis(1, JOY_AXIS_RIGHT_X, 0.0))
	await send(axis(0, JOY_AXIS_TRIGGER_RIGHT, 1.0))
	check(p1.wants_to_fire() and not p2.wants_to_fire(), "trigger does not fire the other actor")
	await send(axis(0, JOY_AXIS_TRIGGER_RIGHT, 0.0))
	check(not p1.wants_to_fire(), "trigger release clears firing")
	await send(button(1, JOY_BUTTON_Y, true))
	check(first.weapon_controller.selected_index == 0 and second.weapon_controller.selected_index == 1,
		"device 1 switches only P2's weapon")
	await send(button(1, JOY_BUTTON_Y, false))
	await send(button(0, JOY_BUTTON_Y, true))
	check(first.weapon_controller.selected_index == 1 and second.weapon_controller.selected_index == 1,
		"device 0 switches only P1's weapon")
	await send(button(0, JOY_BUTTON_Y, false))
	p1.assign_gamepad(-1)
	p2.assign_gamepad(0)
	await send(axis(0, JOY_AXIS_LEFT_X, 1.0))
	check(p1.get_move_vector().is_zero_approx() and p2.get_move_vector().x > 0.99,
		"one gamepad can be reassigned to P2 while P1 keeps the keyboard")
	await send(key(KEY_A, true))
	check(p1.get_move_vector().x < -0.99 and p2.get_move_vector().x > 0.99,
		"keyboard and reassigned pad operate simultaneously without cross-talk")
	await send(key(KEY_A, false))
	await send(axis(0, JOY_AXIS_LEFT_X, 0.0))
	first.weapon_controller.current_weapon.magazine.ammo = 0
	var reload_action: StringName = p1.action_for(&"reload")
	for binding in InputMap.action_get_events(reload_action):
		if binding is InputEventKey:
			InputMap.action_erase_event(reload_action, binding)
	InputMap.action_add_event(reload_action, key(KEY_T, false))
	await send(key(KEY_R, true))
	check(not first.weapon_controller.current_weapon.magazine.reloading,
		"removing the default key removes its behavior without changing player code")
	await send(key(KEY_R, false))
	await send(key(KEY_T, true))
	check(first.weapon_controller.current_weapon.magazine.reloading,
		"runtime Input Map rebinding changes gameplay behavior")
	await send(key(KEY_T, false))
	first.weapon_controller.current_weapon.magazine.cancel_reload()
	var ui := Button.new()
	ui.size = Vector2(300, 120)
	root.add_child(ui)
	ui.gui_input.connect(func(_event: InputEvent) -> void: ui.accept_event())
	ui.grab_focus()
	await send(key(KEY_SPACE, true))
	check(first.dash_remaining == 0.0, "focused UI can consume dash before gameplay")
	await send(key(KEY_SPACE, false))
	await send(key(KEY_D, true))
	check(p1.get_move_vector().is_zero_approx(), "UI-consumed held key does not move the actor")
	await send(key(KEY_D, false))
	ui.release_focus()
	ui.queue_free()
	await process_frame
	await send(key(KEY_D, true))
	await send(axis(0, JOY_AXIS_LEFT_Y, -1.0))
	p1.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(p1.get_move_vector().is_zero_approx() and p2.get_move_vector().y < -0.99,
		"clearing one reader does not clear the other player's accepted state")
	await send(key(KEY_D, false))
	Input.joy_connection_changed.emit(0, false)
	check(p2.get_move_vector().is_zero_approx(), "disconnecting the assigned pad clears held input")
	check(key(KEY_F11, true).is_action_pressed(&"game_fullscreen"),
		"fullscreen shortcut is configured in Input Map")
	check(key(KEY_ESCAPE, true).is_action_pressed(&"game_pause"),
		"pause shortcut is configured in Input Map")
	p1.assign_gamepad(-1)
	p2.assign_gamepad(1)
	first.queue_free()
	await process_frame
	first = scene.instantiate() as Survivor
	first.get_node("PlayerInput").gamepad_device = 0
	root.add_child(first)
	first.set_physics_process(false)
	await send(axis(0, JOY_AXIS_LEFT_X, 1.0))
	check(first.controls.get_move_vector().x > 0.99 and p2.get_move_vector().is_zero_approx(),
		"new actor can restore gamepad bindings after its old profile disabled them")
	await send(axis(0, JOY_AXIS_LEFT_X, 0.0))
	first.queue_free()
	second.queue_free()
	await process_frame
	await process_frame
	print("INPUT PROFILES %s: %d checks, %d failures" % [
		"PASSED" if failures == 0 else "FAILED", checks, failures,
	])
	quit(0 if failures == 0 else 1)
