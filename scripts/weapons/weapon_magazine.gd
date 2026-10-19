class_name WeaponMagazine
extends Node
## Per-instance ammunition and reload lifecycle, independent of its wielder.

signal changed
signal reload_finished

var capacity: int = 1
var ammo: int = 1
var reload_duration: float = 1.0
var reload_remaining: float = 0.0
var reloading: bool = false


func reset(size: int) -> void:
	capacity = maxi(1, size)
	refill()


func advance(delta: float) -> void:
	if not reloading:
		return
	reload_remaining = maxf(0.0, reload_remaining - delta)
	if reload_remaining <= 0.0:
		refill()
		reload_finished.emit()


func consume() -> bool:
	if reloading or ammo <= 0:
		return false
	ammo -= 1
	changed.emit()
	return true


func start_reload(duration: float) -> bool:
	if reloading or ammo >= capacity:
		return false
	reload_duration = maxf(0.01, duration)
	reload_remaining = reload_duration
	reloading = true
	changed.emit()
	return true


func cancel_reload() -> void:
	reloading = false
	reload_remaining = 0.0
	changed.emit()


func refill() -> void:
	ammo = capacity
	cancel_reload()


func get_reload_progress() -> float:
	return 1.0 - reload_remaining / maxf(reload_duration, 0.01)
