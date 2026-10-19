class_name CursorProjection
extends RefCounted
## Cursor intersections use world coordinates and an explicit global Y plane.


static func project(camera: Camera3D, cursor: Vector2, plane_y: float = 0.0) -> Variant:
	if camera == null:
		return null
	var origin: Vector3 = camera.project_ray_origin(cursor)
	var ray: Vector3 = camera.project_ray_normal(cursor)
	if absf(ray.y) <= 0.0001:
		return null
	var distance: float = (plane_y - origin.y) / ray.y
	if distance < 0.0:
		return null
	return origin + ray * distance
