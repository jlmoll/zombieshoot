class_name RunRewards
extends Node
## Run-local reward state. The session only wires dependencies and forwards stats.

signal changed

@export_range(0, 10000) var wave_bonus: int = 250
@export_range(0.0, 1000.0) var interwave_healing: float = 12.0
@export_range(0.0, 1000.0) var medkit_healing: float = 25.0
@export_range(1, 100) var guaranteed_health_interval: int = 13
@export_range(1, 100) var emergency_health_interval: int = 5
@export_range(0.0, 1.0) var emergency_health_threshold: float = 0.4
@export_range(1, 100) var ammo_interval: int = 8
@export_range(1, 100) var kill_sound_interval: int = 5

var score: int = 0
var kills: int = 0
var pickups: PickupManager
var audio: GameAudio
var waves: WaveDirector
var _rewarded: Dictionary[int, WeakRef] = {}
var _completed_waves: Dictionary[int, bool] = {}


func reward_defeat(enemy: Zombie) -> void:
	var context: DamageContext = enemy.last_damage_context
	if context == null:
		return
	var recipient := context.get_instigator() as Survivor
	if recipient == null or context.team != DamageContext.Team.PLAYER:
		return
	var identity: int = enemy.get_instance_id()
	if _rewarded.has(identity) and _rewarded[identity].get_ref() == enemy:
		return
	_rewarded[identity] = weakref(enemy)
	kills += 1
	recipient.kills += 1
	score += enemy.score_value * (1 + int(waves.wave / 3.0))
	if (
		enemy.kind == "boss"
		or recipient.kills % guaranteed_health_interval == 0
		or (
			recipient.health < recipient.max_health * emergency_health_threshold
			and recipient.kills % emergency_health_interval == 0
		)
	):
		pickups.spawn_pickup(enemy.global_position, "health", recipient)
	elif recipient.kills % ammo_interval == 0:
		pickups.spawn_pickup(enemy.global_position, "ammo", recipient)
	if recipient.kills % kill_sound_interval == 0 and is_instance_valid(audio):
		audio.play_sound("kill")
	changed.emit()


func reward_wave(player: Survivor, final_wave: bool) -> void:
	if _completed_waves.has(waves.wave):
		return
	_completed_waves[waves.wave] = true
	score += wave_bonus * waves.wave
	if not final_wave:
		player.heal(interwave_healing)
	changed.emit()


func collect_supply(kind: String, recipient: Survivor) -> void:
	if not is_instance_valid(recipient):
		return
	match kind:
		"health":
			recipient.heal(medkit_healing)
		"ammo":
			recipient.refill_ammo()
		_:
			return
	if is_instance_valid(audio):
		audio.play_sound("upgrade")
