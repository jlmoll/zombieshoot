class_name EnemySpawner
extends Node3D
## Factory, dependency wiring and ownership of this run's enemies.

signal enemy_defeated(enemy: Node3D)

@export var enemy_scenes: Dictionary[String, PackedScene] = {
	"walker": preload("res://scenes/enemies/walker.tscn"),
	"runner": preload("res://scenes/enemies/runner.tscn"),
	"brute": preload("res://scenes/enemies/brute.tscn"),
	"spitter": preload("res://scenes/enemies/spitter.tscn"),
	"boss": preload("res://scenes/enemies/boss.tscn"),
}
var player: Node3D
var navigation: HordeNavigation
var combat: Node3D
var effects: ImpactEffects
var audio: GameAudio
var camera_rig: IsometricCameraRig
var _serial: int = 0


func spawn(kind: String, at: Vector3, wave: int) -> Zombie:
	var scene: PackedScene = enemy_scenes.get(kind, enemy_scenes.get("walker"))
	if scene == null:
		push_error("EnemySpawner has no scene for %s and no walker fallback." % kind)
		return null
	var enemy := scene.instantiate() as Zombie
	_serial += 1
	enemy.name = "%s_%03d" % [kind.to_pascal_case(), _serial]
	enemy.target = player
	enemy.navigation = navigation
	enemy.configure_wave(wave)
	enemy.neighbors = get_children
	enemy.position = to_local(at)
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
