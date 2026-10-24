class_name GameAudio
extends Node
## Procedural sound bank and bounded voice pool; no save or run logic.

var muted: bool = false
var audio_pool: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var sound_index: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in range(16):
		var audio: AudioStreamPlayer = AudioStreamPlayer.new()
		audio.name = "Voice%02d" % i
		audio.volume_db = -15
		add_child(audio)
		audio_pool.append(audio)
	var specs: Dictionary = {
		"shoot": [190.0, 0.07, 0.65],
		"shotgun": [95.0, 0.13, 0.8],
		"smg": [250.0, 0.05, 0.6],
		"chainsaw": [75.0, 0.13, 0.45],
		"hit": [110.0, 0.08, 0.5],
		"kill": [520.0, 0.09, 0.15],
		"dash": [380.0, 0.16, 0.35],
		"reload": [800.0, 0.06, 0.3],
		"hurt": [80.0, 0.2, 0.6],
		"wave": [240.0, 0.5, 0.05],
		"upgrade": [660.0, 0.24, 0.0],
		"death": [70.0, 0.65, 0.35],
		"spit": [145.0, 0.15, 0.4],
		"grenade_throw": [420.0, 0.12, 0.25],
		"explosion": [55.0, 0.48, 0.85],
	}
	for kind in specs:
		var spec: Array = specs[kind]
		var data: PackedByteArray = PackedByteArray()
		var samples: int = int(float(spec[1]) * 22050)
		data.resize(samples * 2)
		for i in range(samples):
			var t: float = float(i) / 22050.0
			var envelope: float = pow(1.0 - float(i) / samples, 2.0)
			var tone: float = sin(TAU * float(spec[0]) * t * (1.0 - t * 1.2))
			var sample: float = (
				lerpf(tone, _rng.randf_range(-1, 1), float(spec[2])) * envelope * 0.6
			)
			data.encode_s16(i * 2, int(sample * 32767))
		var stream: AudioStreamWAV = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = data
		sounds[kind] = stream


func play_sound(kind: String) -> void:
	if muted or audio_pool.is_empty():
		return
	var aliases: Dictionary = {
		"pistol": "shoot",
		"fire": "shoot",
		"damage": "hurt",
		"enemy_hit": "hit",
		"enemy_death": "kill",
		"pickup": "upgrade",
		"boss": "wave",
		"warning": "wave",
		"enemy_shoot": "spit",
		"reload_done": "reload",
		"switch": "reload"
	}
	kind = aliases.get(kind, kind)
	if not sounds.has(kind):
		return
	var audio: AudioStreamPlayer = audio_pool[sound_index % audio_pool.size()]
	sound_index += 1
	audio.stream = sounds[kind]
	audio.pitch_scale = _rng.randf_range(0.92, 1.08)
	audio.play()


func set_muted(enabled: bool) -> void:
	muted = enabled
	AudioServer.set_bus_mute(0, muted)
