class_name HordeNavigation
extends Node
## Shared flow field rasterized from the map's actual collision shapes.
var target: Node3D
var obstacles: Array[Rect2] = []
var polygons: Array[PackedVector2Array] = []
var blocked: Dictionary = {}
var flow: Dictionary = {}
var bounds := Rect2(-18, -18, 36, 36)
var cell_size: float = 1.0
var playable_polygon := PackedVector2Array()
var _clock: float = 0.0
var _minimum: Vector2i
var _maximum: Vector2i


func _physics_process(delta: float) -> void:
	_clock -= delta
	if _clock <= 0.0:
		_clock = 0.3
		rebuild()


func configure_map(
	map: Node3D, area: CollisionShape3D, resolution: float, clearance: float
) -> void:
	cell_size = maxf(resolution, 0.25)
	var box := area.shape as BoxShape3D
	var corners := _box_polygon(area.global_transform, box.size)
	var inset: Array[PackedVector2Array] = Geometry2D.offset_polygon(corners, -clearance)
	playable_polygon = inset[0] if not inset.is_empty() else PackedVector2Array()
	bounds = Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(corner)
	_minimum = _cell(Vector3(bounds.position.x, 0, bounds.position.y))
	_maximum = _cell(Vector3(bounds.end.x, 0, bounds.end.y))
	polygons.clear()
	obstacles.clear()
	_collect_shapes(map, clearance)
	blocked.clear()
	for x in range(_minimum.x, _maximum.x + 1):
		for z in range(_minimum.y, _maximum.y + 1):
			var cell := Vector2i(x, z)
			var point := Vector2(x, z) * cell_size
			if (
				not Geometry2D.is_point_in_polygon(point, playable_polygon)
				or _inside_obstacle(point)
			):
				blocked[cell] = true
	rebuild()


func is_walkable(point: Vector3) -> bool:
	return (
		Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), playable_polygon)
		and not blocked.has(_cell(point))
		and not _inside_obstacle(Vector2(point.x, point.z))
	)


func can_reach_target(point: Vector3) -> bool:
	return is_walkable(point) and flow.has(_cell(point))


func set_target(actor: Node3D) -> void:
	target = actor
	_clock = 0.0
	rebuild()


func rebuild() -> void:
	flow.clear()
	if not is_instance_valid(target):
		return
	var start := _cell(target.global_position)
	var queue: Array[Vector2i] = [start]
	flow[start] = Vector2i.ZERO
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if (
				next.x < _minimum.x
				or next.x > _maximum.x
				or next.y < _minimum.y
				or next.y > _maximum.y
				or blocked.has(next)
				or flow.has(next)
			):
				continue
			flow[next] = -step
			queue.append(next)


func get_direction(from: Vector3, to: Vector3) -> Vector3:
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var clear: bool = true
	for polygon in polygons:
		if Geometry2D.is_point_in_polygon(a, polygon) or Geometry2D.is_point_in_polygon(b, polygon):
			clear = false
			break
		for index in range(polygon.size()):
			if (
				Geometry2D.segment_intersects_segment(
					a, b, polygon[index], polygon[(index + 1) % polygon.size()]
				)
				!= null
			):
				clear = false
				break
		if not clear:
			break
	if clear:
		return flat.normalized()
	var cell := _cell(from)
	if flow.has(cell):
		var step: Vector2i = flow[cell]
		return (
			(Vector3(cell.x + step.x, 0, cell.y + step.y) * cell_size - Vector3(from.x, 0, from.z))
			. normalized()
		)
	var best := flat.normalized()
	var nearest: float = INF
	for x in range(-2, 3):
		for z in range(-2, 3):
			var next := cell + Vector2i(x, z)
			if flow.has(next):
				var waypoint := Vector3(next.x, 0, next.y) * cell_size
				var distance := waypoint.distance_to(from)
				if distance < nearest:
					nearest = distance
					best = (waypoint - from).normalized()
	return best


func _box_polygon(transform: Transform3D, size: Vector3) -> PackedVector2Array:
	var points := PackedVector2Array()
	for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
		var point: Vector3 = transform * (corner * size * 0.5)
		points.append(Vector2(point.x, point.z))
	return points


func _collect_shapes(node: Node, clearance: float) -> void:
	if node is CollisionShape3D and not node.disabled and node.get_parent() is StaticBody3D:
		var body := node.get_parent() as StaticBody3D
		if body.collision_layer & GameRules.WALL_LAYER:
			_add_shape(node.shape, node.global_transform, clearance)
	elif (
		node is GridMap
		and node.mesh_library != null
		and node.collision_layer & GameRules.WALL_LAYER
	):
		for cell: Vector3i in node.get_used_cells():
			var orientation: Basis = node.get_basis_with_orthogonal_index(
				node.get_cell_item_orientation(cell)
			)
			var cell_transform := Transform3D(
				orientation.scaled(Vector3.ONE * node.cell_scale), node.map_to_local(cell)
			)
			var shapes: Array = node.mesh_library.get_item_shapes(node.get_cell_item(cell))
			for index in range(0, shapes.size(), 2):
				_add_shape(
					shapes[index],
					node.global_transform * cell_transform * shapes[index + 1],
					clearance
				)
	for child in node.get_children():
		_collect_shapes(child, clearance)


func _add_shape(shape: Shape3D, transform: Transform3D, clearance: float) -> void:
	var polygon := PackedVector2Array()
	if shape is BoxShape3D:
		polygon = _box_polygon(transform, shape.size)
	elif shape is SphereShape3D or shape is CapsuleShape3D or shape is CylinderShape3D:
		for index in range(24):
			var angle: float = TAU * index / 24.0
			var p: Vector3 = (
				transform * Vector3(cos(angle) * shape.radius, 0, sin(angle) * shape.radius)
			)
			polygon.append(Vector2(p.x, p.z))
	else:
		push_warning(
			"Navigation: unsupported collision shape; use boxes, spheres, capsules or cylinders."
		)
	if not polygon.is_empty():
		for inflated in Geometry2D.offset_polygon(polygon, clearance):
			polygons.append(inflated)
			var rect := Rect2(inflated[0], Vector2.ZERO)
			for point in inflated:
				rect = rect.expand(point)
			obstacles.append(rect)


func _inside_obstacle(point: Vector2) -> bool:
	for polygon in polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


func _cell(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x / cell_size), roundi(point.z / cell_size))
