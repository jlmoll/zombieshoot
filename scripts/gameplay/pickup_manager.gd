class_name PickupManager
extends Node3D
## Spawns supply scenes and applies their rewards to the configured survivor.

const PICKUP_SCENE: PackedScene = preload("res://scenes/gameplay/supply_pickup.tscn")
var player: Survivor
var audio: GameAudio


func spawn_pickup(at: Vector3, kind: String) -> SupplyPickup:
	var pickup: SupplyPickup = PICKUP_SCENE.instantiate()
	pickup.name = "Medkit" if kind == "health" else "AmmoSupply"
	pickup.kind = kind
	pickup.target = player
	pickup.position = at + Vector3.UP * 0.5
	pickup.collected.connect(_on_collected)
	add_child(pickup, true)
	return pickup


func _on_collected(kind: String) -> void:
	if kind == "health":
		player.heal(25)
	else:
		player.refill_ammo()
	audio.play_sound("upgrade")
