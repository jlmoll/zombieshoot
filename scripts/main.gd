class_name Game
extends Node3D
## Coordinates application states and wires long-lived nodes to a fresh run.

enum Mode { TITLE, PLAYING, PAUSED, UPGRADES, DEAD, VICTORY, CONFIGURATION_ERROR }

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run_session.tscn")
@export var map_scene: PackedScene = preload("res://scenes/world/arena.tscn")
var arena: Arena
var session: RunSession
var lighting: ArenaLighting
var mode: Mode = Mode.TITLE
var _previous_health: float = 100.0
@onready var camera_rig: IsometricCameraRig = $CameraRig
@onready var audio: GameAudio = $Audio
@onready var save_data: SaveData = $SaveData
@onready var hud: GameHUD = $Interface
@onready var cursor: AimCursor = $AimCursor
@onready var session_slot: Node3D = $SessionSlot


func _ready() -> void:
	audio.set_muted(save_data.muted)
	hud.set_muted(save_data.muted)
	hud.start_requested.connect(_request_start)
	hud.restart_requested.connect(_request_start)
	hud.resume_requested.connect(resume_run)
	hud.menu_requested.connect(show_title)
	hud.upgrade_selected.connect(choose_upgrade)
	hud.mute_toggled.connect(_set_muted)
	hud.lighting_selected.connect(_set_lighting_preset)
	hud.set_lighting_preset(save_data.lighting_preset)
	if not _new_session():
		return
	show_title()
	if "--smoke-test" in OS.get_cmdline_user_args():
		var smoke: Node = load("res://tests/smoke_test.gd").new()
		add_child(smoke)
		smoke.call_deferred("run", self)


func _process(_delta: float) -> void:
	if is_instance_valid(session) and mode != Mode.TITLE:
		if session.player.health < _previous_health:
			hud.set_damage_flash()
		_previous_health = session.player.health
		hud.update_stats(session.get_stats())


func _shortcut_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"game_pause"):
		if mode == Mode.TITLE and event.is_action_pressed(&"game_start"):
			_request_start()
		else:
			_toggle_pause()
	elif event.is_action_pressed(&"game_fullscreen"):
		var fullscreen: bool = (
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		)
		DisplayServer.window_set_mode(
			(
				DisplayServer.WINDOW_MODE_WINDOWED
				if fullscreen
				else DisplayServer.WINDOW_MODE_FULLSCREEN
			)
		)
	elif event.is_action_pressed(&"game_mute"):
		_set_muted(not audio.muted)
	else:
		return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed(&"game_start")
		and mode == Mode.TITLE
		and get_viewport().gui_get_focus_owner() == null
	):
		_request_start()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == Mode.PLAYING:
		pause_run()


func start_run() -> void:
	if not _new_session():
		return
	camera_rig.reset()
	_set_mode(Mode.PLAYING)
	hud.show_gameplay()
	session.start()


func show_title() -> void:
	_set_mode(Mode.TITLE)
	hud.show_title(save_data.best_score)


func is_gameplay_active() -> bool:
	return mode == Mode.PLAYING and not get_tree().paused


func pause_run() -> void:
	if mode == Mode.PLAYING:
		_set_mode(Mode.PAUSED)
		hud.show_pause()


func resume_run() -> void:
	if mode == Mode.PAUSED:
		_set_mode(Mode.PLAYING)
		hud.show_gameplay()


func choose_upgrade(id: String) -> void:
	if mode != Mode.UPGRADES:
		return
	session.player.apply_upgrade(id)
	_set_mode(Mode.PLAYING)
	hud.show_gameplay()
	var delay: float = session.waves.get_intermission_duration()
	hud.set_banner("SECTOR DESPEJADO", "SIGUIENTE OLEADA EN %.1f SEGUNDOS" % delay, 2.5)
	session.waves.intermission = maxf(delay, 0.001)
	audio.play_sound("upgrade")


func _new_session() -> bool:
	lighting = null
	if is_instance_valid(session):
		session_slot.remove_child(session)
		session.queue_free()
	session = RUN_SCENE.instantiate()
	var map_instance: Node = map_scene.instantiate() if map_scene != null else null
	var errors := PackedStringArray()
	if not map_instance is Arena:
		errors.append("Game needs a map scene with an Arena root.")
	else:
		errors.append_array(ContentValidator.validate_run(map_instance, session))
	if not errors.is_empty():
		if map_instance != null:
			map_instance.free()
		session.free()
		session = null
		arena = null
		_on_configuration_failed(errors)
		return false
	session_slot.add_child(session)
	arena = map_instance as Arena
	session.add_child(arena)
	lighting = arena.get_node_or_null("Environment") as ArenaLighting
	if lighting != null:
		lighting.select_preset(save_data.lighting_preset, false)
	session.configure(arena, audio, camera_rig)
	session.wave_started.connect(_on_wave_started)
	session.wave_cleared.connect(_on_wave_cleared)
	session.configuration_failed.connect(_on_configuration_failed)
	session.player.died.connect(_on_player_died)
	_previous_health = session.player.health
	return true


func _request_start() -> void:
	start_run.call_deferred()


func _set_mode(next: Mode) -> void:
	mode = next
	get_tree().paused = mode != Mode.PLAYING
	camera_rig.title_mode = mode == Mode.TITLE
	cursor.set_gameplay(mode == Mode.PLAYING)


func _toggle_pause() -> void:
	if mode == Mode.PLAYING:
		pause_run()
	elif mode == Mode.PAUSED:
		resume_run()


func _on_wave_started(number: int) -> void:
	var has_boss: bool = not session.waves.get_current_wave().boss_kind.is_empty()
	if lighting != null:
		lighting.set_boss_active(has_boss)
	var subtitle: String = "ALERTA · ABOMINACIÓN DETECTADA" if has_boss else "ELIMINA LA AMENAZA"
	hud.set_banner("OLEADA %02d / %02d" % [number, session.waves.get_wave_count()], subtitle, 3.0)


func _on_wave_cleared() -> void:
	if not is_gameplay_active():
		return
	if lighting != null:
		lighting.set_boss_active(false)
	session.award_wave_bonus()
	session.combat.clear_projectiles()
	if session.waves.wave >= session.waves.get_wave_count():
		_end_run(true)
		return
	_set_mode(Mode.UPGRADES)
	var choices: Array = GameRules.upgrades.duplicate(true)
	choices.shuffle()
	hud.show_upgrades(choices.slice(0, 3))


func _on_player_died() -> void:
	_end_run(false)


func _end_run(victory: bool) -> void:
	if not is_gameplay_active():
		return
	session.waves.running = false
	_set_mode(Mode.VICTORY if victory else Mode.DEAD)
	save_data.record_score(session.score)
	hud.show_game_over(session.score, session.waves.wave, save_data.best_score, victory)
	audio.play_sound("upgrade" if victory else "death")


func _set_muted(enabled: bool) -> void:
	audio.set_muted(enabled)
	hud.set_muted(enabled)
	save_data.set_muted(enabled)


func _set_lighting_preset(preset: int) -> void:
	save_data.set_lighting_preset(preset)
	hud.set_lighting_preset(preset)
	if lighting != null:
		lighting.select_preset(preset)


func _on_configuration_failed(errors: PackedStringArray) -> void:
	if is_instance_valid(session) and is_instance_valid(session.waves):
		session.waves.running = false
	_set_mode(Mode.CONFIGURATION_ERROR)
	hud.show_configuration_error(errors)
	push_warning("Run stopped: " + "; ".join(errors))
