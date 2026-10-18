class_name HordeNavigation
extends Node
## Shared flow field, rebuilt once for the entire horde instead of per enemy.

var target: Node3D
var obstacles: Array[Rect2] = []
var blocked: Dictionary = {}
var flow: Dictionary = {}
var _clock: float = 0.0

func configure(rectangles: Array[Rect2]) -> void:
	obstacles = rectangles.duplicate()
	blocked.clear()
	_build_blocked()

func set_target(actor: Node3D) -> void:
	target = actor
	_clock = 0.0
	rebuild()

func _physics_process(delta: float) -> void:
	_clock -= delta
	if _clock <= 0.0:
		_clock = 0.3
		rebuild()

func _build_blocked() -> void:
	for x in range(-18, 19):
		for z in range(-18, 19):
			var cell: Vector2i = Vector2i(x, z)
			if absi(x) >= 18 or absi(z) >= 18:
				blocked[cell] = true
			for rect in obstacles:
				if rect.has_point(Vector2(x, z)):
					blocked[cell] = true

func rebuild() -> void:
	flow.clear()
	if not is_instance_valid(target):
		return
	var start: Vector2i = Vector2i(roundi(target.position.x), roundi(target.position.z))
	var queue: Array[Vector2i] = [start]
	flow[start] = Vector2i.ZERO
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if absi(next.x) > 18 or absi(next.y) > 18 or blocked.has(next) or flow.has(next):
				continue
			flow[next] = -step
			queue.append(next)

func get_direction(from: Vector3, to: Vector3) -> Vector3:
	var flat: Vector3 = to - from
	flat.y = 0
	var a: Vector2 = Vector2(from.x, from.z)
	var b: Vector2 = Vector2(to.x, to.z)
	var clear: bool = true
	for rect in obstacles:
		if _segment_hits_rect(a, b, rect):
			clear = false
			break
	if clear:
		return flat.normalized()
	var cell: Vector2i = Vector2i(roundi(from.x), roundi(from.z))
	if flow.has(cell):
		var step: Vector2i = flow[cell]
		var waypoint: Vector3 = Vector3(cell.x + step.x, 0, cell.y + step.y)
		return (waypoint - Vector3(from.x, 0, from.z)).normalized()
	# A large zombie may be pushed into an inflated cell: seek its closest open neighbour.
	var best: Vector3 = flat.normalized()
	var nearest: float = INF
	for x in range(-2, 3):
		for z in range(-2, 3):
			var next: Vector2i = cell + Vector2i(x, z)
			if flow.has(next):
				var waypoint: Vector3 = Vector3(next.x, 0, next.y)
				var dist: float = waypoint.distance_to(from)
				if dist < nearest:
					nearest = dist
					best = (waypoint - from).normalized()
	return best

func _segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var p: Vector2 = rect.position
	var q: Vector2 = rect.end
	return Geometry2D.segment_intersects_segment(a, b, p, Vector2(q.x, p.y)) != null or Geometry2D.segment_intersects_segment(a, b, Vector2(q.x, p.y), q) != null or Geometry2D.segment_intersects_segment(a, b, q, Vector2(p.x, q.y)) != null or Geometry2D.segment_intersects_segment(a, b, Vector2(p.x, q.y), p) != null
