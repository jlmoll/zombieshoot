extends SceneTree
## Cursor projection explicitly intersects world planes under translated parents.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CURSOR: " + description)


func run() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	parent.position = Vector3(12.0, 3.0, -9.0)
	var camera := Camera3D.new()
	parent.add_child(camera)
	camera.position = Vector3(2.0, 8.0, 4.0)
	camera.look_at(camera.global_position + Vector3.DOWN, Vector3.FORWARD)
	camera.make_current()
	var center: Vector2 = root.get_visible_rect().get_center()
	var ground: Variant = CursorProjection.project(camera, center)
	check(ground != null and (ground as Vector3).is_equal_approx(Vector3(14.0, 0.0, -5.0)),
		"projection uses the global floor even under translated parents")
	var muzzle: Variant = CursorProjection.project(camera, center, 0.95)
	check(muzzle != null and is_equal_approx((muzzle as Vector3).y, 0.95),
		"aiming can select an explicit global muzzle-height plane")
	check(CursorProjection.project(camera, center, 12.0) == null,
		"planes behind the camera produce no target")
	camera.rotation = Vector3.ZERO
	check(CursorProjection.project(camera, center) == null,
		"parallel rays produce no target")
	check(CursorProjection.project(null, center) == null,
		"a missing camera safely produces no target")
	parent.queue_free()
	await process_frame
	print("CURSOR %s: %d checks, %d failures" % [
		"PASSED" if failures == 0 else "FAILED", checks, failures,
	])
	quit(0 if failures == 0 else 1)
