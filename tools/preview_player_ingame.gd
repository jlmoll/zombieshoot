extends SceneTree
## Render the real run, UI, weapons and enemies at game scale and at review distance.
var game: Game
var ticks: int = 0


func _initialize() -> void:
	call_deferred("setup")


func _process(dt: float) -> bool:
	if game == null:
		return false
	ticks += 1
	if game.mode == Game.Mode.PAUSED:
		game.resume_run()
	paused = false
	var player: Survivor = game.session.player
	player.visuals.animate(dt, player.aim_direction, 6.4, 0.0, 0.0, Vector3.RIGHT)
	if ticks in [20, 40]:
		player.weapon_controller.advance(1.0)
		player.try_shoot()
	if ticks == 21:
		root.get_texture().get_image().save_png("res://assets/models/player_technician_ingame.png")
	if ticks == 30:
		game.camera_rig.camera.size = 8.0
	if ticks == 41:
		root.get_texture().get_image().save_png(
			"res://assets/models/player_technician_ingame_close.png"
		)
	if ticks > 43:
		quit()
	return false


func setup() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_run()
	game.audio.set_muted(true)
	game.session.waves.running = false
	game.session.player.set_physics_process(false)
	game.session.player.aim_direction = Vector3(0.70710678, 0, 0.70710678)
	game.session.player.select_weapon(1)
	game.camera_rig.set_process(false)
	game.camera_rig.camera.position = Vector3(23, 28, 23)
	game.camera_rig.camera.look_at(Vector3.ZERO)
	game.camera_rig.camera.size = 26
	game.hud.set_banner("", "", 0.0)
	for i in range(4):
		var enemy: Zombie = game.session.enemies.spawn(
			["walker", "runner", "brute", "spitter"][i],
			[Vector3(-3, 0, -2), Vector3(2.7, 0, -2.5), Vector3(4, 0, 1), Vector3(-4, 0, 2.5)][i],
			1
		)
		enemy.set_physics_process(false)
		enemy.visuals.animate(
			1.0, 0.0, enemy.speed, 0.0, enemy.position.direction_to(Vector3.ZERO), 0.0, 0.0
		)
