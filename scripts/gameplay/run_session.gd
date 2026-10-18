class_name RunSession
extends Node3D
## Composition root for one run. Freeing this node discards all transient state.

signal wave_started(number: int)
signal wave_cleared

@onready var player: Survivor = $Player
@onready var enemies: EnemySpawner = $Enemies
@onready var combat: CombatService = $Combat
@onready var pickups: PickupManager = $Pickups
@onready var effects: ImpactEffects = $Effects
@onready var waves: WaveDirector = $WaveDirector

var score: int = 0
var kills: int = 0
var elapsed: float = 0.0
var _audio: GameAudio
var _navigation: HordeNavigation


func configure_map(map: Arena, audio: GameAudio, camera_rig: IsometricCameraRig) -> void:
	player.global_position = map.player_spawn.global_position
	waves.map = map
	combat.playable_area = map.playable_area
	configure(map.navigation, audio, camera_rig)


func configure(navigation: HordeNavigation, audio: GameAudio, camera_rig: IsometricCameraRig) -> void:
	_audio = audio
	_navigation = navigation
	navigation.set_target(player)
	camera_rig.target = player
	combat.enemies = enemies
	combat.effects = effects
	combat.audio = audio
	combat.camera_rig = camera_rig
	enemies.player = player
	enemies.navigation = navigation
	enemies.combat = combat
	enemies.effects = effects
	enemies.audio = audio
	enemies.camera_rig = camera_rig
	enemies.enemy_defeated.connect(_on_enemy_defeated)
	pickups.player = player
	pickups.audio = audio
	player.bullet_requested.connect(combat.spawn_player_bullet)
	player.grenade_requested.connect(combat.spawn_grenade)
	player.particles_requested.connect(effects.spawn_particles)
	player.sound_requested.connect(audio.play_sound)
	player.trauma_requested.connect(camera_rig.add_trauma)
	waves.target = player
	waves.count_enemies = enemies.living_count
	waves.enemy_spawn_requested.connect(enemies.spawn)
	waves.wave_started.connect(_on_wave_started)
	waves.wave_cleared.connect(wave_cleared.emit)


func start() -> void:
	waves.start()


func _physics_process(delta: float) -> void:
	elapsed += delta


func get_stats() -> Dictionary:
	var stats: Dictionary = player.get_stats()
	stats.merge({"score": score, "wave": waves.wave, "kills": kills,
		"enemies": enemies.living_count() + waves.spawn_left, "time": elapsed})
	return stats


func award_wave_bonus() -> void:
	score += 250 * waves.wave


func _on_wave_started(number: int) -> void:
	player.replenish_grenades()
	_navigation.rebuild()
	_audio.play_sound("wave")
	wave_started.emit(number)


func _on_enemy_defeated(enemy: Node3D) -> void:
	kills += 1
	player.kills = kills
	score += enemy.score_value * (1 + int(waves.wave / 3.0))
	if enemy.kind == "boss" or kills % 13 == 0 or (player.health < player.max_health * 0.4 and kills % 5 == 0):
		pickups.spawn_pickup(enemy.position, "health")
	elif kills % 8 == 0:
		pickups.spawn_pickup(enemy.position, "ammo")
	if kills % 5 == 0:
		_audio.play_sound("kill")
