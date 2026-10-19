@tool
class_name WaveCampaign
extends Resource
## Ordered wave definitions. Resources are read only during a run.

@export var waves: Array[WaveDefinition] = []


func get_configuration_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if waves.is_empty():
		errors.append("Campaign has no waves.")
	for index in range(waves.size()):
		if waves[index] == null:
			errors.append("Wave %d has no definition." % (index + 1))
		else:
			for error in waves[index].get_configuration_errors():
				errors.append("Wave %d: %s" % [index + 1, error])
	return errors
