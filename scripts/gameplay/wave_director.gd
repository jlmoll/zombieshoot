@tool
class_name WaveDirector
extends Node
## Wave scheduling only; emits spawn and progression requests.

signal wave_started(number: int)
signal wave_cleared
signal enemy_spawn_requested(kind: String, at: Vector3, wave_number: int)
signal configuration_failed(errors: PackedStringArray)

@export var campaign: WaveCampaign = preload("res://assets/waves/default_campaign.tres")

var wave: int = 0
var spawn_left: int = 0
var spawn_clock: float = 0.0
var intermission: float = 0.0
var wave_finished: bool = false
var spawn_serial: int = 0
var running: bool = false
var map: Arena
var boss_pending: bool = false
var target: Node3D
var count_enemies: Callable
var rng := RandomNumberGenerator.new()
var enemy_scenes: Dictionary[String, PackedScene] = {}
var _definition: WaveDefinition
var _blocked_duration: float = 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	rng.randomize()

func start() -> void:
	var errors := get_configuration_errors(map, enemy_scenes)
	if not is_instance_valid(target):
		errors.append("WaveDirector needs a live target.")
	if not count_enemies.is_valid():
		errors.append("WaveDirector needs an enemy count callback.")
	if not errors.is_empty():
		_fail_configuration(errors)
		return
	boss_pending = false
	wave = 0
	spawn_serial = 0
	intermission = 0.0
	running = true
	start_next_wave()

func start_next_wave() -> void:
	if campaign == null or wave >= campaign.waves.size():
		running = false
		return
	wave += 1
	_definition = campaign.waves[wave - 1]
	boss_pending = false
	wave_finished = false
	spawn_left = _definition.enemy_count
	spawn_clock = _definition.initial_delay
	_blocked_duration = 0.0
	wave_started.emit(wave)
	if not _definition.boss_kind.is_empty():
		boss_pending = true
		_try_spawn_boss()

func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if Engine.is_editor_hint() or not running:
		return
	if not is_instance_valid(target) or not is_instance_valid(map):
		_fail_configuration(PackedStringArray(["WaveDirector lost its map or target."]))
		return
	if intermission > 0.0:
		intermission -= delta
		if intermission <= 0.0:
			start_next_wave()
	elif boss_pending:
		_try_spawn_boss()
		if boss_pending:
			_record_blocked_spawn(delta)
	elif spawn_left > 0:
		spawn_clock -= delta
		if spawn_clock <= 0.0 and int(count_enemies.call()) < _definition.maximum_alive:
			var previous_count := spawn_left
			spawn_next()
			if spawn_left == previous_count:
				_record_blocked_spawn(delta)
			else:
				spawn_clock = _definition.spawn_interval
	elif not wave_finished and int(count_enemies.call()) == 0:
		wave_finished = true
		_emit_wave_cleared.call_deferred()

func _emit_wave_cleared() -> void:
	if running and is_inside_tree():
		# Pause can arrive after the physics tick but before this deferred callback.
		# Recheck after resuming instead of silently losing the completed wave.
		if get_tree().paused:
			wave_finished = false
			return
		wave_cleared.emit()

func spawn_next() -> void:
	if _definition == null or not running or spawn_left <= 0:
		return
	var next_serial: int = spawn_serial + 1
	var kind: String = _definition.get_enemy_kind(next_serial)
	var point: Variant = map.choose_spawn(kind, wave, target.global_position, rng)
	if point == null:
		return
	spawn_left -= 1
	spawn_serial = next_serial
	_blocked_duration = 0.0
	enemy_spawn_requested.emit(kind, point, wave)

func _try_spawn_boss() -> void:
	var point: Variant = map.choose_spawn(_definition.boss_kind, wave, target.global_position, rng)
	if point != null:
		boss_pending = false
		_blocked_duration = 0.0
		enemy_spawn_requested.emit(_definition.boss_kind, point, wave)


func get_wave_count() -> int:
	return campaign.waves.size() if campaign != null else 0


func get_current_wave() -> WaveDefinition:
	return _definition


func get_intermission_duration() -> float:
	return _definition.intermission_duration if _definition != null else 0.0


func get_configuration_errors(
		arena: Arena, registered_scenes: Dictionary[String, PackedScene]
) -> PackedStringArray:
	return ContentValidator.validate_campaign(campaign, arena, registered_scenes)


func _record_blocked_spawn(delta: float) -> void:
	_blocked_duration += delta
	if _blocked_duration >= _definition.blocked_spawn_timeout:
		_fail_configuration(PackedStringArray([
			"Wave %d: no reachable spawn satisfies its entrance and distance rules for %.1f seconds."
			% [wave, _definition.blocked_spawn_timeout]
		]))


func _fail_configuration(errors: PackedStringArray) -> void:
	running = false
	configuration_failed.emit(errors)


func report_spawn_failure(message: String) -> void:
	_fail_configuration(PackedStringArray([message]))


func _get_configuration_warnings() -> PackedStringArray:
	if campaign == null:
		return PackedStringArray(["Assign a WaveCampaign resource."])
	return campaign.get_configuration_errors()
