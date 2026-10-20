extends SceneTree
## Actual renderer captures, with frozen actors and the same camera for all presets.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_run()
	game.audio.set_muted(true)
	game.session.waves.running = false
	game.session.player.set_physics_process(false)
	game.camera_rig.set_process(false)
	game.camera_rig.camera.position = Vector3(23, 28, 23)
	game.camera_rig.camera.look_at(Vector3.ZERO)
	game.camera_rig.camera.size = 36
	game.hud.set_banner("", "", 0.0)
	for index in range(4):
		var enemy: Zombie = (
			game
			. session
			. enemies
			. spawn(
				["walker", "runner", "brute", "spitter"][index],
				[Vector3(-3, 0, -2), Vector3(2.7, 0, -2.5), Vector3(4, 0, 1), Vector3(-4, 0, 2.5)][index],
				1
			)
		)
		enemy.set_physics_process(false)
	game.pause_run()
	game.hud.menus.hide()
	DirAccess.make_dir_recursive_absolute("res://.godot/qa/lighting")
	for preset in range(3):
		game.lighting.select_preset(preset, false)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/qa/lighting/mode_%d.png" % preset)
	game.hud.set_lighting_preset(0)
	game.hud.show_pause()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/qa/lighting/menu.png")
	game.show_title()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/qa/lighting/title.png")
	game.queue_free()
	await process_frame
	quit()
