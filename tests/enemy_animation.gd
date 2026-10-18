extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: PackedScene = load("res://scenes/actors/enemy.tscn")
	for kind in ["walker", "runner", "brute", "spitter", "boss"]:
		var enemy: Zombie = scene.instantiate()
		enemy.configure(kind, 1)
		root.add_child(enemy)
		var capsule: CapsuleShape3D = enemy.get_node("CollisionShape3D").shape
		assert(is_equal_approx(capsule.radius, enemy.radius), "hit radius stays generous as model shrinks")
		assert(capsule.height >= 2.14 * enemy._visual_scale, "hit capsule covers the head")
		var visuals: ZombieVisuals = enemy.visuals
		var player: AnimationPlayer = visuals._animation
		for clip in ["Idle", "Walk", "Attack", "Death"]:
			assert(player.has_animation(clip), "%s missing %s" % [kind, clip])
			assert(player.get_animation(clip).get_track_count() > 0)
		assert(player.get_animation("Walk").loop_mode == Animation.LOOP_LINEAR)
		visuals.animate(0.1, 0.0, enemy.speed, 1.0, Vector3.FORWARD, 0.0, 0.0)
		assert(player.current_animation == "Walk")
		visuals.play_attack(0.65)
		assert(player.current_animation == "Attack")
		player.advance(5.0)
		visuals.animate(0.1, 0.0, enemy.speed, 0.0, Vector3.FORWARD, 0.0, 0.0)
		assert(player.current_animation == "Idle")
		enemy.take_damage(99999)
		assert(enemy.dead and enemy.collision_layer == 0)
		assert(player.current_animation == "Death")
		assert(player.get_animation("Death").length / player.get_playing_speed() <= 0.75)
		assert(not enemy.is_queued_for_deletion())
		await create_timer(1.1).timeout
		assert(not is_instance_valid(enemy), "corpse must be cleaned up")
	print("BLOCKY ANIMATION TEST PASSED: five variants, four imported clips, transitions, non-colliding death and corpse cleanup")
	quit()

