class_name ImpactEffects
extends Node3D
## Bounded, run-scoped particles; ownership handles restart cleanup.

func spawn_particles(at: Vector3, color: Color, count: int) -> void:
	if get_child_count() >= 35:
		return
	var effect: CPUParticles3D = CPUParticles3D.new()
	effect.position = at
	effect.amount = mini(count, 12)
	effect.lifetime = 0.32
	effect.one_shot = true
	effect.explosiveness = 1.0
	effect.direction = Vector3.UP
	effect.spread = 75
	effect.initial_velocity_min = 2.0
	effect.initial_velocity_max = 5.0
	effect.gravity = Vector3(0, -13, 0)
	effect.scale_amount_min = 0.045
	effect.scale_amount_max = 0.1
	var mesh: BoxMesh = BoxMesh.new()
	mesh.material = PrototypeMeshes.material(color, true)
	effect.mesh = mesh
	effect.name = "Impact"
	add_child(effect, true)
	effect.finished.connect(effect.queue_free)
	effect.emitting = true
