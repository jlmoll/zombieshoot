@tool
extends Node3D
## Decorative floor sign; edit its content from the instance root.
@export var sector_number: String = "07":
	set(value):
		sector_number = value
		_refresh()
@export var caption: String = "CONTENCIÓN  /  SECTOR":
	set(value):
		caption = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	var number := get_node_or_null("Number") as Label3D
	var subtitle := get_node_or_null("Caption") as Label3D
	if number != null:
		number.text = sector_number
	if subtitle != null:
		subtitle.text = caption
