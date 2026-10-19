@tool
class_name WaveSpawnRule
extends Resource
## Later matching rules take precedence. Serial is shared across the entire run.

## Tipo que sustituye al enemigo por defecto cuando esta regla coincide.
## Debe tener una escena registrada y una entrada habilitada para la oleada.
@export var enemy_kind: String = "walker"
## Aplica la regla cada N apariciones normales de la partida: 4 afecta a 4, 8, 12...
## El contador no se reinicia entre oleadas y los jefes adicionales no lo incrementan.
## Con 1 coincide siempre; si coinciden varias reglas, gana la última de la composición.
@export_range(1, 1000) var every_nth_spawn: int = 1


func matches(serial: int) -> bool:
	return every_nth_spawn > 0 and serial % every_nth_spawn == 0


func get_configuration_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if enemy_kind.is_empty():
		errors.append("Spawn rule needs an enemy kind.")
	if every_nth_spawn < 1:
		errors.append("Spawn rule divisor must be positive.")
	return errors
