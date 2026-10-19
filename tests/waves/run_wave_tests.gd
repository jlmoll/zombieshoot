extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not load("res://tests/waves/test_waves.gd").run(self):
		quit(1)
		return
	if not load("res://tests/validation/test_content_validation.gd").run(self):
		quit(1)
		return
	print("WAVE AND CONTENT VALIDATION TESTS PASSED")
	quit(0)
