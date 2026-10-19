class_name RunSession
extends Node3D
## Composition root for one run. Freeing this node discards all transient state.

signal wave_started(number: int)
signal wave_cleared
signal configuration_failed(errors: PackedStringArray)

@onready var player: Survivor = $Player
@onready var enemies: EnemySpawner = $Enemies
@onready var combat: CombatService = $Combat
@onready var pickups: PickupManager = $Pickups
@onready var effects: ImpactEffects = $Effects
@onready var waves: WaveDirector = $WaveDirector
@onready var rewards: RunRewards = $Rewards

var score: int:
	get:
		return rewards.score
var kills: int:
	get:
		return rewards.kills
var elapsed: float = 0.0
var _audio: GameAudio
var _navigation: HordeNavigation


func configure(map: Arena, audio: GameAudio, camera_rig: IsometricCameraRig) -> void:
	player.global_position = map.player_spawn.global_position
	waves.map = map
	waves.enemy_scenes = enemies.enemy_scenes
	combat.playable_area = map.playable_area
	var navigation: HordeNavigation = map.navigation
	_audio = audio
	_navigation = navigation
	navigation.set_target(player)
	camera_rig.target = player
	combat.enemies = enemies
	combat.damage_targets = [player]
	combat.effects = effects
	combat.audio = audio
	combat.camera_rig = camera_rig
	enemies.player = player
	enemies.navigation = navigation
	enemies.combat = combat
	enemies.effects = effects
	enemies.audio = audio
	enemies.camera_rig = camera_rig
	rewards.pickups = pickups
	rewards.audio = audio
	rewards.waves = waves
	enemies.enemy_defeated.connect(rewards.reward_defeat)
	pickups.player = player
	pickups.supply_collected.connect(rewards.collect_supply)
	player.projectile_spawn_requested.connect(combat.spawn_projectile)
	player.grenade_requested.connect(_spawn_player_grenade)
	player.particles_requested.connect(effects.spawn_particles)
	player.sound_requested.connect(audio.play_sound)
	player.trauma_requested.connect(camera_rig.add_trauma)
	waves.target = player
	waves.count_enemies = enemies.living_count
	waves.enemy_spawn_requested.connect(enemies.spawn)
	waves.wave_started.connect(_on_wave_started)
	waves.wave_cleared.connect(wave_cleared.emit)
	waves.configuration_failed.connect(configuration_failed.emit)
	enemies.spawn_failed.connect(waves.report_spawn_failure)


func start() -> void:
	var errors := ContentValidator.validate_run(waves.map, self)
	if not errors.is_empty():
		configuration_failed.emit(errors)
		return
	waves.start()


func _physics_process(delta: float) -> void:
	elapsed += delta


func get_stats() -> Dictionary:
	var stats: Dictionary = player.get_stats()
	stats.merge({"score": score, "wave": waves.wave, "wave_count": waves.get_wave_count(), "kills": kills,
		"enemies": enemies.living_count() + waves.spawn_left, "time": elapsed})
	return stats


func award_wave_bonus() -> void:
	rewards.reward_wave(player, waves.wave >= waves.get_wave_count())


func _on_wave_started(number: int) -> void:
	player.replenish_grenades()
	_navigation.rebuild()
	_audio.play_sound("wave")
	wave_started.emit(number)


func _spawn_player_grenade(origin: Vector3, direction: Vector3, distance: float) -> void:
	var context := DamageContext.create(player, player, player.get_damage_team(), &"grenade")
	combat.spawn_grenade(origin, direction, distance, context)
