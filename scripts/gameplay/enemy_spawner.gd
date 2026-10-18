class_name EnemySpawner
extends Node3D
## Factory, dependency wiring and ownership of this run's enemies.

signal enemy_defeated(enemy: Node3D)

const ENEMY_SCENE: PackedScene = preload("res://scenes/actors/enemy.tscn")
var player: Node3D
var navigation: HordeNavigation
var combat: Node3D
var effects: ImpactEffects
var audio: GameAudio
var camera_rig: IsometricCameraRig
var _serial: int = 0


func spawn(kind: String, at: Vector3, wave: int) -> Zombie:
	var enemy: Zombie = ENEMY_SCENE.instantiate()
	_serial += 1
	enemy.name = "%s_%03d" % [kind.to_pascal_case(), _serial]
	enemy.target = player
	enemy.navigation = navigation
	enemy.configure(kind, wave)
	enemy.position = at
	enemy.defeated.connect(enemy_defeated.emit)
	enemy.enemy_bullet_requested.connect(combat.spawn_enemy_bullet)
	enemy.particles_requested.connect(effects.spawn_particles)
	enemy.sound_requested.connect(audio.play_sound)
	enemy.trauma_requested.connect(camera_rig.add_trauma)
	add_child(enemy)
	effects.spawn_particles(at + Vector3.UP * 0.2, Color("eeb25d"), 5)
	return enemy


func living_count() -> int:
	var count: int = 0
	for enemy: Zombie in get_children():
		if not enemy.dead and not enemy.is_queued_for_deletion():
			count += 1
	return count
