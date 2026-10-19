@tool
class_name EnemySpawner
extends Node3D
## Factory, dependency wiring and ownership of this run's enemies.

signal enemy_defeated(enemy: Node3D)
signal spawn_failed(message: String)

## Registro de identificadores de enemigo y sus escenas, con raíz de tipo Zombie.
## Usa estas claves en las oleadas y entradas. Un tipo sin escena detiene la partida.
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
	var scene: PackedScene = enemy_scenes.get(kind)
	if scene == null:
		spawn_failed.emit("EnemySpawner has no registered scene for '%s'." % kind)
		return null
	var instance := scene.instantiate()
	if not instance is Zombie:
		instance.free()
		spawn_failed.emit("Enemy '%s' scene root must be a Zombie." % kind)
		return null
	var enemy := instance as Zombie
	_serial += 1
	enemy.name = "%s_%03d" % [kind.to_pascal_case(), _serial]
	enemy.target = player
	enemy.navigation = navigation
	enemy.configure_wave(wave)
	enemy.neighbors = get_children
	enemy.position = to_local(at)
	enemy.defeated.connect(enemy_defeated.emit)
	enemy.projectile_spawn_requested.connect(combat.spawn_projectile)
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


func _get_configuration_warnings() -> PackedStringArray:
	return ContentValidator.validate_enemy_scenes(enemy_scenes)
