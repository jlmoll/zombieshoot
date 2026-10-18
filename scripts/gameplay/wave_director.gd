class_name WaveDirector
extends Node
## Wave scheduling only; emits spawn and progression requests.

signal wave_started(number: int)
signal wave_cleared
signal enemy_spawn_requested(kind: String, at: Vector3, wave_number: int)

var wave: int = 0
var spawn_left: int = 0
var spawn_clock: float = 0.0
var intermission: float = 0.0
var wave_finished: bool = false
var spawn_serial: int = 0
var running: bool = false
var target: Node3D
var count_enemies: Callable
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func start() -> void:
	wave = 0
	spawn_serial = 0
	intermission = 0.0
	running = true
	start_next_wave()

func start_next_wave() -> void:
	wave += 1
	wave_finished = false
	spawn_left = 9 + wave * 5
	spawn_clock = 1.6
	wave_started.emit(wave)
	if wave == 4 or wave == GameRules.WAVE_COUNT:
		enemy_spawn_requested.emit("boss", Vector3(0, 0, -15), wave)

func _physics_process(delta: float) -> void:
	if not running:
		return
	if intermission > 0.0:
		intermission -= delta
		if intermission <= 0.0:
			start_next_wave()
	elif spawn_left > 0:
		spawn_clock -= delta
		if spawn_clock <= 0.0 and int(count_enemies.call()) < 65:
			spawn_next()
			spawn_clock = maxf(0.16, 0.8 - wave * 0.065)
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
	spawn_left -= 1
	spawn_serial += 1
	var kind: String = "walker"
	if wave >= 2 and spawn_serial % 4 == 0:
		kind = "runner"
	if wave >= 3 and spawn_serial % 7 == 0:
		kind = "spitter"
	if wave >= 3 and spawn_serial % 9 == 0:
		kind = "brute"
	var edge: int = rng.randi_range(0, 3)
	var p: Vector3 = Vector3.ZERO
	for attempt in range(12):
		var offset: float = rng.randf_range(-13, 13)
		match edge:
			0: p = Vector3(offset, 0, -16.2)
			1: p = Vector3(16.2, 0, offset)
			2: p = Vector3(offset, 0, 16.2)
			3: p = Vector3(-16.2, 0, offset)
		if p.distance_to(target.position) > 8.0:
			break
		edge = (edge + 1) % 4
	enemy_spawn_requested.emit(kind, p, wave)
