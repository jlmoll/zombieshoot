extends SceneTree
## Bake tiny chamfers into static props; collision dimensions remain unchanged.


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/meshes")
	_bake(Vector3(1.5, 2.6, 1.5), 0.09, "pillar")
	_bake(Vector3(3.5, 1.6, 1.7), 0.1, "barricade")
	quit()


func _bake(size: Vector3, bevel: float, label: String) -> void:
	var planes: Array[Plane] = []
	var half := size * 0.5
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var normal := Vector3(x, y, z)
				var axes: int = absi(x) + absi(y) + absi(z)
				if axes == 0:
					continue
				var distance: float = normal.abs().dot(half) - bevel * (axes - 1)
				planes.append(Plane(normal.normalized(), distance / normal.length()))
	var vertices: Array[Vector3] = []
	for a in planes.size():
		for b in range(a + 1, planes.size()):
			for c in range(b + 1, planes.size()):
				var point: Variant = planes[a].intersect_3(planes[b], planes[c])
				if point == null:
					continue
				var inside: bool = true
				for plane in planes:
					if plane.distance_to(point) > 0.0001:
						inside = false
						break
				if inside:
					var duplicate: bool = false
					for vertex in vertices:
						if vertex.distance_to(point) < 0.0001:
							duplicate = true
							break
					if not duplicate:
						vertices.append(point)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plane in planes:
		var face: Array[Vector3] = []
		var center := Vector3.ZERO
		for vertex in vertices:
			if absf(plane.distance_to(vertex)) < 0.0001:
				face.append(vertex)
				center += vertex
		if face.size() < 3:
			continue
		center /= face.size()
		var axis := plane.normal.cross(Vector3.UP).normalized()
		if axis.length_squared() < 0.5:
			axis = plane.normal.cross(Vector3.RIGHT).normalized()
		var other := plane.normal.cross(axis)
		face.sort_custom(
			func(a: Vector3, b: Vector3) -> bool:
				var va := a - center
				var vb := b - center
				return atan2(va.dot(other), va.dot(axis)) > atan2(vb.dot(other), vb.dot(axis))
		)
		for index in range(1, face.size() - 1):
			for vertex in [face[0], face[index], face[index + 1]]:
				surface.set_normal(plane.normal)
				surface.add_vertex(vertex)
	var error := ResourceSaver.save(surface.commit(), "res://assets/meshes/%s_beveled.tres" % label)
	if error != OK:
		push_error("Could not bake " + label)
