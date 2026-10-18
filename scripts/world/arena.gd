class_name Arena
extends Node3D
## Immutable arena geometry and the navigation obstacle description.

@onready var navigation: HordeNavigation = $Navigation
var obstacles: Array[Rect2] = []

func _ready() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("0c1520")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8db6c4")
	env.environment.ambient_light_energy = 0.65
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "KeyLight"
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("c4dce5")
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	add_child(sun)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-35, 145, 0)
	fill.light_color = Color("4eaea6")
	fill.light_energy = 0.45
	add_child(fill)
	PrototypeMeshes.box($Ground, Vector3(38, 0.8, 38), Vector3(0, -0.55, 0), Color("111f2a")).name = "Foundation"
	for x in range(-6, 6):
		for z in range(-6, 6):
			var shade: Color = Color("263a42") if (x + z) % 2 == 0 else Color("2a3e45")
			PrototypeMeshes.box($Ground, Vector3(2.96, 0.12, 2.96), Vector3(x * 3 + 1.5, -0.09, z * 3 + 1.5), shade).name = "Tile_%02d_%02d" % [x + 6, z + 6]
	for edge in [-1, 1]:
		_obstacle(Vector3(0, 0.7, edge * 18.4), Vector3(37, 1.4, 0.8), Color("263743"), false)
		_obstacle(Vector3(edge * 18.4, 0.7, 0), Vector3(0.8, 1.4, 37), Color("263743"), false)
		PrototypeMeshes.box($Perimeter, Vector3(36, 0.06, 0.08), Vector3(0, 1.43, edge * 18), Color("51bdba"), true).name = "EdgeLightZ%d" % edge
		PrototypeMeshes.box($Perimeter, Vector3(0.08, 0.06, 36), Vector3(edge * 18, 1.43, 0), Color("51bdba"), true).name = "EdgeLightX%d" % edge
	for entry in [Vector3(-7, 0, -6), Vector3(7, 0, 6), Vector3(7, 0, -7), Vector3(-7, 0, 7)]:
		var barricade: StaticBody3D = _obstacle(entry + Vector3.UP * 0.8, Vector3(3.5, 1.6, 1.7), Color("42565b"))
		PrototypeMeshes.box(barricade, Vector3(3.15, 0.06, 1.36), Vector3.UP * 0.83, Color("526b6b")).name = "TopPlate"
		for n in [-1, 0, 1]:
			PrototypeMeshes.box(barricade, Vector3(0.35, 0.05, 1.35), Vector3(n * 1.0, 0.88, 0), Color("d7a654")).name = "HazardStripe%d" % (n + 1)
	for p in [Vector3(-12, 0, 1), Vector3(12, 0, -1), Vector3(1, 0, -12), Vector3(-1, 0, 12)]:
		var pillar: StaticBody3D = _obstacle(p + Vector3.UP * 1.3, Vector3(1.5, 2.6, 1.5), Color("344b55"))
		PrototypeMeshes.box(pillar, Vector3(1.55, 0.09, 1.55), Vector3.UP * 1.1, Color("60d1c2"), true).name = "PillarLight"
	for p in [Vector3(0, 0.02, -16.8), Vector3(0, 0.02, 16.8), Vector3(-16.8, 0.02, 0), Vector3(16.8, 0.02, 0)]:
		PrototypeMeshes.box($Markings, Vector3(3.5, 0.04, 3.5), p, Color("524b3e"))
		for i in range(5):
			PrototypeMeshes.box($Markings, Vector3(0.19, 0.05, 3.3), p + Vector3(-1.4 + i * 0.7, 0.04, 0), Color("dca653"))
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "ContainmentRing"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 3.9
	torus.outer_radius = 3.96
	ring.mesh = torus
	ring.material_override = PrototypeMeshes.material(Color("4d777a"), true)
	ring.position.y = 0.015
	ring.scale.y = 0.15
	$Markings.add_child(ring)
	_floor_text("07", Vector3(0, 0.025, 0), 5.5, Color("5b7a7d"))
	_floor_text("CONTENCIÓN  /  SECTOR", Vector3(0, 0.028, 3.3), 0.6, Color("64878a"))
	navigation.configure(obstacles)

func _obstacle(at: Vector3, size: Vector3, color: Color, navigable: bool = true) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = at
	body.collision_layer = GameRules.WALL_LAYER
	body.collision_mask = 0
	body.name = "Cover" if navigable else "Wall"
	($Cover if navigable else $Perimeter).add_child(body, true)
	PrototypeMeshes.box(body, size, Vector3.ZERO, color)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collider.name = "CollisionShape3D"
	collider.shape = shape
	body.add_child(collider)
	if navigable:
		obstacles.append(Rect2(Vector2(at.x - size.x * 0.5, at.z - size.z * 0.5), Vector2(size.x, size.z)).grow(0.75))
	return body

func _floor_text(text: String, at: Vector3, height: float, color: Color) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = height / 96.0
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.position = at
	label.rotation.x = -PI / 2.0
	label.name = "FloorText"
	$Markings.add_child(label, true)
