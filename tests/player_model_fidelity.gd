extends SceneTree
## Compare evaluated Blender poses with the imported model, catching collapsed pivots.
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var packed: PackedScene = load("res://assets/models/player_technician.glb")
	check(packed != null, "Player GLB loads")
	if packed == null:
		quit(1)
		return
	var model: Node3D = packed.instantiate()
	root.add_child(model)
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	check(ap != null, "Imported AnimationPlayer exists")
	if ap == null:
		quit(1)
		return
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/player_blender_reference.json"))
	var worst: float = 0.0
	for clip: String in reference:
		check(ap.has_animation(clip), "Missing imported clip " + clip)
		if not ap.has_animation(clip): continue
		for sample: Dictionary in reference[clip]:
			ap.play(clip, 0.0)
			ap.seek(sample.time, true)
			ap.pause()
			for mesh_name: String in sample.positions:
				var mesh: Node3D = model.find_child(mesh_name, true, false)
				check(mesh != null, "Missing mesh " + mesh_name)
				if mesh == null: continue
				var p: Array = sample.positions[mesh_name]
				var error: float = mesh.global_position.distance_to(Vector3(p[0],p[1],p[2]))
				worst = maxf(worst,error)
				check(error < 0.001, "%s / %s differs from Blender by %.4f m" % [clip,mesh_name,error])
			for mesh_name: String in sample.get("bounds", {}):
				var mesh: MeshInstance3D = model.find_child(mesh_name, true, false) as MeshInstance3D
				if mesh == null: continue
				var expected_min := Vector3(INF,INF,INF)
				var expected_max := Vector3(-INF,-INF,-INF)
				for corner: Array in sample.bounds[mesh_name]:
					var point := Vector3(corner[0],corner[1],corner[2])
					expected_min = expected_min.min(point)
					expected_max = expected_max.max(point)
				var actual_min := Vector3(INF,INF,INF)
				var actual_max := Vector3(-INF,-INF,-INF)
				for corner: int in range(8):
					var point: Vector3 = mesh.global_transform * mesh.get_aabb().get_endpoint(corner)
					actual_min = actual_min.min(point)
					actual_max = actual_max.max(point)
				check(actual_min.distance_to(expected_min) < 0.002 and actual_max.distance_to(expected_max) < 0.002, "%s / %s bounds must preserve Blender proportions" % [clip,mesh_name])
	print("PLAYER MODEL FIDELITY %s: %d checks; max error %.5f m" % ["PASSED" if failures == 0 else "FAILED",checks,worst])
	quit(0 if failures == 0 else 1)
