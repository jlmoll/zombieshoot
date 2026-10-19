class_name Game
extends Node3D
## Coordinates application states and wires long-lived nodes to a fresh run.

enum Mode { TITLE, PLAYING, PAUSED, UPGRADES, DEAD, VICTORY }

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run_session.tscn")

@export var map_scene: PackedScene = preload("res://scenes/world/arena.tscn")
var arena: Arena
@onready var camera_rig: IsometricCameraRig = $CameraRig
@onready var audio: GameAudio = $Audio
@onready var save_data: SaveData = $SaveData
@onready var hud: GameHUD = $Interface
@onready var cursor: AimCursor = $AimCursor
@onready var session_slot: Node3D = $SessionSlot

var session: RunSession
var mode: Mode = Mode.TITLE
var _previous_health: float = 100.0


func _ready() -> void:
	audio.set_muted(save_data.muted)
	hud.set_muted(save_data.muted)
	hud.start_requested.connect(_request_start)
	hud.restart_requested.connect(_request_start)
	hud.resume_requested.connect(resume_run)
	hud.menu_requested.connect(show_title)
	hud.upgrade_selected.connect(choose_upgrade)
	hud.mute_toggled.connect(_set_muted)
	_new_session()
	show_title()
	if "--smoke-test" in OS.get_cmdline_user_args():
		var smoke: Node = load("res://tests/smoke_test.gd").new()
		add_child(smoke)
		smoke.call_deferred("run", self)


func _new_session() -> void:
	if is_instance_valid(session):
		session_slot.remove_child(session)
		session.queue_free()
	session = RUN_SCENE.instantiate()
	session_slot.add_child(session)
	arena = map_scene.instantiate()
	session.add_child(arena)
	session.configure(arena, audio, camera_rig)
	session.wave_started.connect(_on_wave_started)
	session.wave_cleared.connect(_on_wave_cleared)
	session.player.died.connect(_on_player_died)
	_previous_health = session.player.health


func _request_start() -> void:
	start_run.call_deferred()


func start_run() -> void:
	_new_session()
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


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_P:
				_toggle_pause()
				get_viewport().set_input_as_handled()
			KEY_ENTER:
				if mode == Mode.TITLE and get_viewport().gui_get_focus_owner() == null:
					_request_start()
					get_viewport().set_input_as_handled()
			KEY_F11:
				var fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_M:
				_set_muted(not audio.muted)
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		if mode == Mode.TITLE:
			_request_start()
		else:
			_toggle_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == Mode.PLAYING:
		pause_run()


func _process(_delta: float) -> void:
	if is_instance_valid(session) and mode != Mode.TITLE:
		if session.player.health < _previous_health:
			hud.set_damage_flash()
		_previous_health = session.player.health
		hud.update_stats(session.get_stats())


func _on_wave_started(number: int) -> void:
	var subtitle: String = "ELIMINA LA AMENAZA" if number % 4 != 0 else "ALERTA · ABOMINACIÓN DETECTADA"
	hud.set_banner("OLEADA %02d / %02d" % [number, GameRules.WAVE_COUNT], subtitle, 3.0)


func _on_wave_cleared() -> void:
	if not is_gameplay_active():
		return
	session.award_wave_bonus()
	session.combat.clear_projectiles()
	if session.waves.wave >= GameRules.WAVE_COUNT:
		_end_run(true)
		return
	session.player.heal(12)
	_set_mode(Mode.UPGRADES)
	var choices: Array = GameRules.UPGRADES.duplicate(true)
	choices.shuffle()
	hud.show_upgrades(choices.slice(0, 3))


func choose_upgrade(id: String) -> void:
	if mode != Mode.UPGRADES:
		return
	session.player.apply_upgrade(id)
	_set_mode(Mode.PLAYING)
	hud.show_gameplay()
	hud.set_banner("SECTOR DESPEJADO", "SIGUIENTE OLEADA EN 3 SEGUNDOS", 2.5)
	session.waves.intermission = 3.0
	audio.play_sound("upgrade")


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
