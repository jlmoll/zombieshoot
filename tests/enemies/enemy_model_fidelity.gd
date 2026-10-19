extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var model: Node3D = load("res://assets/models/zombie_blocky.glb").instantiate()
	root.add_child(model)
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var reference: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/blocky_blender_reference.json")
	)
	var count: int = 0
	var worst: float = 0.0
	for clip: String in reference:
		for sample: Dictionary in reference[clip]:
			ap.play(clip, 0.0)
			ap.seek(sample.time, true)
			ap.pause()
			for mesh_name: String in sample.positions:
				var mesh: Node3D = model.find_child(mesh_name, true, false)
				if mesh == null:
					push_error("Missing mesh: " + mesh_name)
					quit(1)
					return
				var p: Array = sample.positions[mesh_name]
				var error: float = mesh.global_position.distance_to(Vector3(p[0], p[1], p[2]))
				worst = maxf(worst, error)
				assert(error < 0.01, "%s / %s: position mismatch %s" % [clip, mesh_name, error])
				count += 1
	print("BLENDER / GODOT TRANSFORMS PASSED: %d mesh positions; max error %f m" % [count, worst])
	quit()
