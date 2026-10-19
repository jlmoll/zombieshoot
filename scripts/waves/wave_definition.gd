@tool
class_name WaveDefinition
extends Resource
## Immutable design data; the director owns counters and clocks.

## Total de enemigos normales que deben aparecer antes de completar la oleada.
## No incluye el jefe adicional de [member boss_kind]. Puede ser 0 si hay un jefe.
@export_range(0, 1000) var enemy_count: int = 14
## Segundos de espera antes de la primera aparición normal. El jefe aparece al inicio.
@export_range(0.0, 60.0) var initial_delay: float = 1.6
## Segundos entre apariciones normales. Un valor menor aumenta la presión de la horda.
@export_range(0.01, 60.0) var spawn_interval: float = 0.735
## Límite de enemigos vivos para permitir otra aparición normal; incluye al jefe vivo.
## Al alcanzar el límite, los enemigos pendientes esperan, sin perderse del total.
@export_range(1, 1000) var maximum_alive: int = 65
## Tipo usado si ninguna regla de [member composition] coincide.
## Debe estar registrado en EnemySpawner: walker, runner, spitter, brute o boss.
@export var default_enemy_kind: String = "walker"
## Reglas que sustituyen el tipo por defecto, sin añadir enemigos al total.
## Se evalúan en orden y gana la última coincidencia. El contador continúa entre oleadas.
@export var composition: Array[WaveSpawnRule] = []
## Tipo del jefe adicional que aparece al comenzar, antes de los enemigos normales.
## Vacío desactiva el jefe. Necesita una escena registrada y una entrada que admita ese tipo.
@export var boss_kind: String = ""
## Segundos de espera después de elegir una mejora, antes de iniciar la siguiente oleada.
## La última oleada termina en victoria y no usa esta espera.
@export_range(0.0, 60.0) var intermission_duration: float = 3.0
## Segundos tolerados sin encontrar una entrada válida por distancia o navegación.
## Al agotarse, la partida muestra un error de configuración en lugar de esperar sin fin.
@export_range(0.1, 120.0) var blocked_spawn_timeout: float = 15.0


func get_enemy_kind(serial: int) -> String:
	var kind := default_enemy_kind
	for rule in composition:
		if rule != null and rule.matches(serial):
			kind = rule.enemy_kind
	return kind


func get_configuration_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if enemy_count < 0 or (enemy_count == 0 and boss_kind.is_empty()):
		errors.append("Wave needs at least one enemy or boss.")
	if initial_delay < 0.0 or spawn_interval <= 0.0 or maximum_alive < 1:
		errors.append("Wave delays and concurrent enemy limit are invalid.")
	if intermission_duration < 0.0 or blocked_spawn_timeout <= 0.0:
		errors.append("Wave intermission and blocked spawn timeout are invalid.")
	if default_enemy_kind.is_empty() and enemy_count > 0:
		errors.append("Wave needs a default enemy kind.")
	for index in range(composition.size()):
		if composition[index] == null:
			errors.append("Composition entry %d is missing." % index)
		else:
			errors.append_array(composition[index].get_configuration_errors())
	return errors
