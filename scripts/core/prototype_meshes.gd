class_name PrototypeMeshes
extends RefCounted
## Shared primitive construction; contains no gameplay state.


static func material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.7
	return mat


static func box(
	parent: Node3D, size: Vector3, at: Vector3, color: Color, emissive: bool = false
) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material(color, emissive)
	mesh.position = at
	mesh.name = "Block"
	parent.add_child(mesh, true)
	return mesh
