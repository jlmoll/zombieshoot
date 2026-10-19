extends SceneTree
## Health state contracts are independent of actor presentation and invulnerability.

var checks: int = 0
var failures: int = 0
var deaths: int = 0
var changes: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("HEALTH: " + description)


func run() -> void:
	var SCENE := preload("res://scenes/components/health_component.tscn")
	var first := SCENE.instantiate() as HealthComponent
	var second := SCENE.instantiate() as HealthComponent
	second.maximum = 150.0
	root.add_child(first)
	root.add_child(second)
	first.health_changed.connect(func(_current: float, _maximum: float): changes += 1)
	first.died.connect(func(): deaths += 1)
	first.reset(80.0)
	check(
		first.take_damage(35.0) and first.current == 45.0,
		"damage applies through the common component"
	)
	check(
		second.current == 150.0 and second.maximum == 150.0,
		"instances have independent health state"
	)
	first.heal(-10.0)
	check(first.current == 45.0, "negative healing cannot cause damage")
	first.heal(1000.0)
	check(first.current == 80.0, "healing clamps at the configured maximum")
	first.take_damage(100.0)
	first.take_damage(100.0)
	first.heal(100.0)
	check(
		first.current == 0.0 and first.depleted and deaths == 1,
		"death emits once and healing cannot resurrect a depleted component"
	)
	first.reset(120.0)
	check(
		first.current == 120.0 and not first.depleted,
		"reset restores full health and clears the depleted state"
	)
	first.set_maximum(50.0)
	check(
		first.current == 50.0 and first.maximum == 50.0,
		"reducing maximum health also clamps current health"
	)
	first.take_damage(50.0)
	check(
		deaths == 2 and changes == 7,
		"each accepted mutation emits once; ignored hits and healing emit no changes"
	)
	first.queue_free()
	second.queue_free()
	await process_frame
	print(
		(
			"HEALTH %s: %d checks, %d failures"
			% [
				"PASSED" if failures == 0 else "FAILED",
				checks,
				failures,
			]
		)
	)
	quit(0 if failures == 0 else 1)
