class_name PickupManager
extends Node3D
## Factory contract: all spawn positions are global world coordinates.

signal supply_collected(kind: String, recipient: Survivor)

const PICKUP_SCENE: PackedScene = preload("res://scenes/gameplay/supply_pickup.tscn")
var player: Survivor


func spawn_pickup(at: Vector3, kind: String, recipient: Survivor = null) -> SupplyPickup:
	if recipient == null:
		recipient = player
	var pickup: SupplyPickup = PICKUP_SCENE.instantiate()
	pickup.name = "Medkit" if kind == "health" else "AmmoSupply"
	pickup.kind = kind
	pickup.target = recipient
	pickup.position = to_local(at + Vector3.UP * 0.5)
	pickup.collected.connect(_on_collected.bind(recipient))
	add_child(pickup, true)
	return pickup


func _on_collected(kind: String, recipient: Survivor) -> void:
	supply_collected.emit(kind, recipient)
