extends Node3D
## Owns the run, arena, spawning, progression, navigation and procedural audio.

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const BULLET_SCRIPT = preload("res://scripts/projectile.gd")
const HUD_SCRIPT = preload("res://scripts/hud.gd")
const LAST_WAVE: int = 8
const SAVE_PATH: String = "user://dead_shift.cfg"
const UPGRADES: Array[Dictionary] = [
	{"id": "damage", "title": "PUNTA HUECA", "description": "+25% de daño con todas las armas."},
	{"id": "speed", "title": "PASO LIGERO", "description": "+15% de velocidad de movimiento."},
	{"id": "fire_rate", "title": "GATILLO RÁPIDO", "description": "+20% de cadencia de disparo."},
	{"id": "health", "title": "SEGUNDO ALIENTO", "description": "+25 de vida máxima y recuperación total."},
	{"id": "reload", "title": "MANOS RÁPIDAS", "description": "Recargas un 20% más rápidas."},
	{"id": "dash", "title": "REFLEJOS", "description": "Recuperas la esquiva un 20% más rápido."},
]

var mode: String = "title"
var player: CharacterBody3D
var hud: CanvasLayer
var camera: Camera3D
var runtime: Node3D
var score: int = 0
var best_score: int = 0
var wave: int = 0
var kills: int = 0
var elapsed: float = 0.0
var spawn_left: int = 0
var spawn_clock: float = 0.0
var intermission: float = 0.0
var wave_finished: bool = false
var spawn_serial: int = 0
var trauma: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var drops: Array[Dictionary] = []
var obstacles: Array[Rect2] = []
var blocked: Dictionary = {}
var flow: Dictionary = {}
var navigation_clock: float = 0.0
var audio_pool: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var sound_index: int = 0
var muted: bool = false
var camera_target: Vector3 = Vector3.ZERO
var damage_health_cache: float = 100.0
var _effect_count: int = 0
var _reticle: ImageTexture
var _cursor_playing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_load_save()
	_build_environment()
	_build_audio()
	_build_reticle()
	hud = HUD_SCRIPT.new()
	add_child(hud)
	hud.set_muted(muted)
	hud.start_requested.connect(_request_start)
	hud.restart_requested.connect(_request_start)
	hud.resume_requested.connect(_resume)
	hud.menu_requested.connect(_show_title)
	hud.upgrade_selected.connect(_choose_upgrade)
	hud.mute_toggled.connect(_toggle_mute)
	_new_runtime()
	_show_title()
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("_run_smoke_test")

func _new_runtime() -> void:
	if is_instance_valid(runtime):
		remove_child(runtime)
		runtime.queue_free()
	runtime = Node3D.new()
	runtime.name = "Run"
	runtime.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(runtime)
	drops.clear()
	_effect_count = 0
	player = PLAYER_SCRIPT.new()
	runtime.add_child(player)
	player.died.connect(_on_player_died)
	damage_health_cache = player.health

func _request_start() -> void:
	call_deferred("_start_run")

func _start_run() -> void:
	get_tree().paused = false
	_new_runtime()
	score = 0
	kills = 0
	wave = 0
	elapsed = 0.0
	spawn_serial = 0
	trauma = 0.0
	camera_target = Vector3.ZERO
	mode = "playing"
	hud.show_gameplay()
	_start_wave()

func _show_title() -> void:
	mode = "title"
	get_tree().paused = true
	hud.show_title(best_score)

func is_gameplay_active() -> bool:
	return mode == "playing" and not get_tree().paused

func _pause() -> void:
	if mode != "playing":
		return
	mode = "paused"
	get_tree().paused = true
	hud.show_pause()

func _resume() -> void:
	if mode != "paused":
		return
	mode = "playing"
	get_tree().paused = false
	hud.show_gameplay()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			if mode == "playing":
				_pause()
			elif mode == "paused":
				_resume()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER and mode == "title":
			_request_start()
		elif event.keycode == KEY_F11:
			var fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.keycode == KEY_M:
			_toggle_mute(not muted)
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			if mode == "playing":
				_pause()
			elif mode == "paused":
				_resume()
			elif mode == "title":
				_request_start()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "playing":
		_pause()

func _process(delta: float) -> void:
	var gameplay_cursor: bool = mode == "playing"
	if gameplay_cursor != _cursor_playing:
		_cursor_playing = gameplay_cursor
		Input.set_custom_mouse_cursor(_reticle if gameplay_cursor else null, Input.CURSOR_ARROW, Vector2(16, 16) if gameplay_cursor else Vector2.ZERO)
	var target: Vector3 = Vector3.ZERO
	if mode != "title" and is_instance_valid(player):
		target = player.position * 0.76
	camera_target = camera_target.lerp(target, 1.0 - exp(-delta * 5.0))
	trauma = maxf(0.0, trauma - delta * 1.7)
	var shake: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.4, 0.4), rng.randf_range(-1.0, 1.0)) * trauma * trauma * 0.28
	camera.position = camera_target + Vector3(23, 28, 23) + shake
	camera.look_at(camera_target)
	camera.size = lerpf(camera.size, 34.0 if mode == "title" else 26.0, 1.0 - exp(-delta * 3.0))
	if is_instance_valid(player) and mode != "title":
		if player.health < damage_health_cache:
			hud.set_damage_flash()
		damage_health_cache = player.health
		var weapon: Dictionary = player.weapons[player.weapon_index]
		hud.update_stats({
			"health": player.health, "max_health": player.max_health, "score": score,
			"wave": wave, "kills": kills, "enemies": _living_enemies() + spawn_left,
			"ammo": player.ammo, "magazine": player.magazine_size,
			"reloading": player.reloading,
			"reload_progress": 1.0 - player.reload_left / maxf(player.reload_duration, 0.01),
			"weapon": weapon.get("name", "ARMA"),
			"dash_ready": player.dash_cooldown <= 0.0,
			"dash_progress": 1.0 - player.dash_cooldown / maxf(player.DASH_COOLDOWN * player.dash_multiplier, 0.01),
			"time": elapsed,
		})

func _physics_process(delta: float) -> void:
	if not is_gameplay_active():
		return
	elapsed += delta
	navigation_clock -= delta
	if navigation_clock <= 0.0:
		navigation_clock = 0.3
		_build_flow()
	if intermission > 0.0:
		intermission -= delta
		if intermission <= 0.0:
			_start_wave()
	elif spawn_left > 0:
		spawn_clock -= delta
		if spawn_clock <= 0.0 and _living_enemies() < 65:
			_spawn_next()
			spawn_clock = maxf(0.16, 0.8 - wave * 0.065)
	elif not wave_finished and _living_enemies() == 0:
		wave_finished = true
		_finish_wave.call_deferred()
	_update_drops(delta)

func _start_wave() -> void:
	wave += 1
	wave_finished = false
	spawn_left = 9 + wave * 5
	spawn_clock = 1.6
	if wave == 4 or wave == LAST_WAVE:
		_spawn_enemy("boss", Vector3(0, 0, -15))
	hud.set_banner("OLEADA %02d / %02d" % [wave, LAST_WAVE], "ELIMINA LA AMENAZA" if wave % 4 != 0 else "ALERTA · ABOMINACIÓN DETECTADA", 3.0)
	play_sound("wave")
	_build_flow()

func _spawn_next() -> void:
	spawn_left -= 1
	spawn_serial += 1
	var kind: String = "walker"
	if wave >= 2 and spawn_serial % 4 == 0:
		kind = "runner"
	if wave >= 3 and spawn_serial % 7 == 0:
		kind = "spitter"
	if wave >= 3 and spawn_serial % 9 == 0:
		kind = "brute"
	var edge: int = rng.randi_range(0, 3)
	var p: Vector3 = Vector3.ZERO
	for attempt in range(12):
		var offset: float = rng.randf_range(-13, 13)
		match edge:
			0: p = Vector3(offset, 0, -16.2)
			1: p = Vector3(16.2, 0, offset)
			2: p = Vector3(offset, 0, 16.2)
			3: p = Vector3(-16.2, 0, offset)
		if p.distance_to(player.position) > 8.0:
			break
		edge = (edge + 1) % 4
	_spawn_enemy(kind, p)

func _spawn_enemy(kind: String, at: Vector3) -> Node3D:
	var enemy: CharacterBody3D = ENEMY_SCRIPT.new()
	enemy.configure(kind, wave)
	runtime.add_child(enemy)
	enemy.position = at
	spawn_particles(at + Vector3.UP * 0.2, Color("eeb25d"), 5)
	return enemy

func _living_enemies() -> int:
	var count: int = 0
	if not is_instance_valid(runtime):
		return 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.get_parent() == runtime and not enemy.is_queued_for_deletion() and enemy.health > 0:
			count += 1
	return count

func enemy_killed(enemy: Node3D) -> void:
	if mode != "playing":
		return
	kills += 1
	player.kills = kills
	score += enemy.score_value * (1 + int(wave / 3.0))
	if enemy.kind == "boss" or kills % 13 == 0 or (player.health < player.max_health * 0.4 and kills % 5 == 0):
		_spawn_drop(enemy.position, "health")
	elif kills % 8 == 0:
		_spawn_drop(enemy.position, "ammo")
	if kills % 5 == 0:
		play_sound("kill")

func _finish_wave() -> void:
	if mode != "playing":
		return
	score += 250 * wave
	_clear_projectiles()
	if wave >= LAST_WAVE:
		_end_run(true)
		return
	player.heal(12)
	mode = "upgrades"
	get_tree().paused = true
	var choices: Array = UPGRADES.duplicate(true)
	choices.shuffle()
	hud.show_upgrades(choices.slice(0, 3))

func _choose_upgrade(id: String) -> void:
	if mode != "upgrades":
		return
	player.apply_upgrade(id)
	mode = "playing"
	get_tree().paused = false
	hud.show_gameplay()
	hud.set_banner("SECTOR DESPEJADO", "SIGUIENTE OLEADA EN 3 SEGUNDOS", 2.5)
	intermission = 3.0
	play_sound("upgrade")

func _on_player_died() -> void:
	_end_run(false)

func _end_run(victory: bool) -> void:
	if mode != "playing":
		return
	mode = "victory" if victory else "dead"
	get_tree().paused = true
	best_score = maxi(best_score, score)
	_save()
	hud.show_game_over(score, wave, best_score, victory)
	play_sound("upgrade" if victory else "death")

func spawn_player_bullet(origin: Vector3, direction: Vector3, damage: float, speed: float, pierce: int = 0) -> void:
	var bullet: Node3D = BULLET_SCRIPT.new()
	bullet.configure(origin, direction, damage, speed, true, pierce)
	runtime.add_child(bullet)
	bullet.add_to_group("projectiles")

func spawn_enemy_bullet(origin: Vector3, direction: Vector3, damage: float, speed: float) -> void:
	var bullet: Node3D = BULLET_SCRIPT.new()
	bullet.configure(origin, direction, damage, speed, false, 0)
	runtime.add_child(bullet)
	bullet.add_to_group("projectiles")

func _clear_projectiles() -> void:
	for node in get_tree().get_nodes_in_group("projectiles"):
		node.queue_free()

func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func _spawn_drop(at: Vector3, kind: String) -> void:
	var root: Node3D = Node3D.new()
	runtime.add_child(root)
	root.position = at + Vector3.UP * 0.5
	var color: Color = Color("7fea9c") if kind == "health" else Color("ffc16c")
	_box(root, Vector3(0.65, 0.32, 0.65), Vector3.ZERO, Color("183a3b"))
	_box(root, Vector3(0.45, 0.06, 0.16), Vector3(0, 0.19, 0), color, true)
	if kind == "health":
		_box(root, Vector3(0.16, 0.06, 0.45), Vector3(0, 0.19, 0), color, true)
	drops.append({"node": root, "kind": kind, "life": 22.0, "phase": rng.randf() * TAU})

func _update_drops(delta: float) -> void:
	for i in range(drops.size() - 1, -1, -1):
		var d: Dictionary = drops[i]
		var node: Node3D = d.node
		d.life -= delta
		node.rotation.y += delta
		node.position.y = 0.5 + sin(elapsed * 3 + d.phase) * 0.12
		if node.position.distance_to(player.position + Vector3.UP * 0.5) < 1.25:
			if d.kind == "health":
				player.heal(25)
			else:
				player.refill_ammo()
			play_sound("upgrade")
			d.life = 0.0
		if d.life <= 0.0:
			node.queue_free()
			drops.remove_at(i)

func _build_environment() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("0c1520")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8db6c4")
	env.environment.ambient_light_energy = 0.65
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("c4dce5")
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	add_child(sun)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 145, 0)
	fill.light_color = Color("4eaea6")
	fill.light_energy = 0.45
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 34
	camera.far = 150
	camera.position = Vector3(23, 28, 23)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	_box(self, Vector3(38, 0.8, 38), Vector3(0, -0.55, 0), Color("111f2a"))
	for x in range(-6, 6):
		for z in range(-6, 6):
			var shade: Color = Color("263a42") if (x + z) % 2 == 0 else Color("2a3e45")
			_box(self, Vector3(2.96, 0.12, 2.96), Vector3(x * 3 + 1.5, -0.09, z * 3 + 1.5), shade)
	for edge in [-1, 1]:
		_obstacle(Vector3(0, 0.7, edge * 18.4), Vector3(37, 1.4, 0.8), Color("263743"), false)
		_obstacle(Vector3(edge * 18.4, 0.7, 0), Vector3(0.8, 1.4, 37), Color("263743"), false)
		_box(self, Vector3(36, 0.06, 0.08), Vector3(0, 1.43, edge * 18), Color("51bdba"), true)
		_box(self, Vector3(0.08, 0.06, 36), Vector3(edge * 18, 1.43, 0), Color("51bdba"), true)
	for entry in [Vector3(-7, 0, -6), Vector3(7, 0, 6), Vector3(7, 0, -7), Vector3(-7, 0, 7)]:
		_obstacle(entry + Vector3.UP * 0.8, Vector3(3.5, 1.6, 1.7), Color("42565b"))
		_box(self, Vector3(3.15, 0.06, 1.36), entry + Vector3.UP * 1.63, Color("526b6b"))
		for n in [-1, 0, 1]:
			_box(self, Vector3(0.35, 0.05, 1.35), entry + Vector3(n * 1.0, 1.68, 0), Color("d7a654"))
	for p in [Vector3(-12, 0, 1), Vector3(12, 0, -1), Vector3(1, 0, -12), Vector3(-1, 0, 12)]:
		_obstacle(p + Vector3.UP * 1.3, Vector3(1.5, 2.6, 1.5), Color("344b55"))
		_box(self, Vector3(1.55, 0.09, 1.55), p + Vector3.UP * 2.4, Color("60d1c2"), true)
	for p in [Vector3(0, 0.02, -16.8), Vector3(0, 0.02, 16.8), Vector3(-16.8, 0.02, 0), Vector3(16.8, 0.02, 0)]:
		_box(self, Vector3(3.5, 0.04, 3.5), p, Color("524b3e"))
		for i in range(5):
			_box(self, Vector3(0.19, 0.05, 3.3), p + Vector3(-1.4 + i * 0.7, 0.04, 0), Color("dca653"))
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 3.9
	torus.outer_radius = 3.96
	ring.mesh = torus
	ring.material_override = _material(Color("4d777a"), true)
	ring.position.y = 0.015
	ring.scale.y = 0.15
	add_child(ring)
	_floor_text("07", Vector3(0, 0.025, 0), 5.5, Color("5b7a7d"))
	_floor_text("CONTENCIÓN  /  SECTOR", Vector3(0, 0.028, 3.3), 0.6, Color("64878a"))
	_build_blocked()

func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.7
	return mat

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color, emissive)
	mesh.position = at
	parent.add_child(mesh)
	return mesh

func _obstacle(at: Vector3, size: Vector3, color: Color, navigable: bool = true) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = at
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	_box(body, size, Vector3.ZERO, color)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	if navigable:
		obstacles.append(Rect2(Vector2(at.x - size.x * 0.5, at.z - size.z * 0.5), Vector2(size.x, size.z)).grow(0.75))

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
	add_child(label)

func _build_blocked() -> void:
	for x in range(-18, 19):
		for z in range(-18, 19):
			var cell: Vector2i = Vector2i(x, z)
			if absi(x) >= 18 or absi(z) >= 18:
				blocked[cell] = true
			for rect in obstacles:
				if rect.has_point(Vector2(x, z)):
					blocked[cell] = true

func _build_flow() -> void:
	flow.clear()
	if not is_instance_valid(player):
		return
	var start: Vector2i = Vector2i(roundi(player.position.x), roundi(player.position.z))
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

func get_navigation_direction(from: Vector3, to: Vector3) -> Vector3:
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

func spawn_particles(at: Vector3, color: Color, count: int) -> void:
	if _effect_count >= 35 or not is_instance_valid(runtime):
		return
	_effect_count += 1
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
	mesh.material = _material(color, true)
	effect.mesh = mesh
	runtime.add_child(effect)
	effect.finished.connect(func() -> void:
		_effect_count = maxi(0, _effect_count - 1)
		effect.queue_free()
	)
	effect.emitting = true

func _build_reticle() -> void:
	var bitmap: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	bitmap.fill(Color.TRANSPARENT)
	for y in range(32):
		for x in range(32):
			var horizontal: bool = absi(y - 16) <= 1 and absi(x - 16) >= 5 and absi(x - 16) <= 11
			var vertical: bool = absi(x - 16) <= 1 and absi(y - 16) >= 5 and absi(y - 16) <= 11
			if horizontal or vertical or Vector2(x - 16, y - 16).length() < 1.8:
				bitmap.set_pixel(x, y, Color("edfff7"))
	_reticle = ImageTexture.create_from_image(bitmap)

func _build_audio() -> void:
	for i in range(16):
		var audio: AudioStreamPlayer = AudioStreamPlayer.new()
		audio.volume_db = -15
		add_child(audio)
		audio_pool.append(audio)
	var specs: Dictionary = {
		"shoot": [190.0, 0.07, 0.65], "shotgun": [95.0, 0.13, 0.8],
		"smg": [250.0, 0.05, 0.6], "hit": [110.0, 0.08, 0.5],
		"kill": [520.0, 0.09, 0.15], "dash": [380.0, 0.16, 0.35],
		"reload": [800.0, 0.06, 0.3], "hurt": [80.0, 0.2, 0.6],
		"wave": [240.0, 0.5, 0.05], "upgrade": [660.0, 0.24, 0.0],
		"death": [70.0, 0.65, 0.35], "spit": [145.0, 0.15, 0.4],
	}
	for kind in specs:
		var spec: Array = specs[kind]
		var data: PackedByteArray = PackedByteArray()
		var samples: int = int(float(spec[1]) * 22050)
		data.resize(samples * 2)
		for i in range(samples):
			var t: float = float(i) / 22050.0
			var envelope: float = pow(1.0 - float(i) / samples, 2.0)
			var tone: float = sin(TAU * float(spec[0]) * t * (1.0 - t * 1.2))
			var sample: float = lerpf(tone, rng.randf_range(-1, 1), float(spec[2])) * envelope * 0.6
			data.encode_s16(i * 2, int(sample * 32767))
		var stream: AudioStreamWAV = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = data
		sounds[kind] = stream

func play_sound(kind: String) -> void:
	if muted or audio_pool.is_empty():
		return
	var aliases: Dictionary = {"pistol": "shoot", "fire": "shoot", "damage": "hurt", "enemy_hit": "hit", "enemy_death": "kill", "pickup": "upgrade", "boss": "wave", "warning": "wave", "enemy_shoot": "spit", "reload_done": "reload", "switch": "reload"}
	kind = aliases.get(kind, kind)
	if not sounds.has(kind):
		return
	var audio: AudioStreamPlayer = audio_pool[sound_index % audio_pool.size()]
	sound_index += 1
	audio.stream = sounds[kind]
	audio.pitch_scale = rng.randf_range(0.92, 1.08)
	audio.play()

func _toggle_mute(enabled: bool) -> void:
	muted = enabled
	AudioServer.set_bus_mute(0, muted)
	if is_instance_valid(hud):
		hud.set_muted(muted)
	_save()

func _load_save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = int(cfg.get_value("run", "best", 0))
		muted = bool(cfg.get_value("settings", "muted", false))
	AudioServer.set_bus_mute(0, muted)

func _save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("run", "best", best_score)
	cfg.set_value("settings", "muted", muted)
	cfg.save(SAVE_PATH)

func _run_smoke_test() -> void:
	# Real engine integration check, called only by the explicit test CLI flag.
	_start_run()
	await get_tree().process_frame
	assert(is_instance_valid(player) and player.health > 0)
	for kind in ["walker", "runner", "brute", "spitter", "boss"]:
		var enemy: Node3D = _spawn_enemy(kind, Vector3(5, 0, -4))
		enemy.take_damage(100000)
	await get_tree().process_frame
	assert(kills == 5, "Enemy kill callback must fire once for every archetype")
	spawn_player_bullet(Vector3(0, 0.7, 0), Vector3.RIGHT, 10, 20)
	spawn_enemy_bullet(Vector3(8, 0.7, 0), Vector3.LEFT, 10, 8)
	player.take_damage(20)
	player.heal(10)
	for upgrade in UPGRADES:
		player.apply_upgrade(upgrade.id)
	_spawn_drop(Vector3.ZERO, "health")
	_spawn_drop(Vector3.ZERO, "ammo")
	await get_tree().create_timer(0.6).timeout
	_pause()
	assert(get_tree().paused)
	_resume()
	assert(not get_tree().paused)
	get_tree().paused = false
	print("SMOKE TEST PASSED: arena, five enemies, projectiles, damage, healing, upgrades, pickups, pause")
	get_tree().quit(0)
