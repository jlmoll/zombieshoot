class_name WeaponPresentation
extends Node3D
## Model, muzzle, recoil and flash belong to the weapon scene, not the actor.

var _flash_remaining: float = 0.0
var _recoil: float = 0.0
var _recovery: float = 0.6
var _rest_position := Vector3.ZERO
@onready var recoil_root: Node3D = $RecoilRoot
@onready var muzzle: Marker3D = $RecoilRoot/Muzzle
@onready var flash: GeometryInstance3D = $RecoilRoot/Muzzle/Flash


func _ready() -> void:
	_rest_position = recoil_root.position


func advance(delta: float) -> void:
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	_recoil = move_toward(_recoil, 0.0, delta * _recovery)
	recoil_root.position = _rest_position + Vector3(0, 0, -_recoil)
	flash.visible = _flash_remaining > 0.0


func play_shot(recoil_amount: float, flash_duration: float, recovery: float) -> void:
	_recoil = recoil_amount
	_recovery = recovery
	_flash_remaining = flash_duration
	flash.show()


func reset() -> void:
	_flash_remaining = 0.0
	_recoil = 0.0
	recoil_root.position = _rest_position
	flash.hide()


func get_muzzle_position() -> Vector3:
	return muzzle.global_position
