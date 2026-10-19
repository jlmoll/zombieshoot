extends SceneTree
var actor: Zombie
var camera: Camera3D
var ticks: int = 0
var shots: Array = [
	["Rest", "", 0.0],
	["Idle", "Idle", 0.6],
	["Walk", "Walk", 0.25],
	["Attack", "Attack", 0.59],
	["Death", "Death", 1.6]
]
var index: int = 0


func _initialize() -> void:
	call_deferred("setup")


func _process(_dt: float) -> bool:
	if actor == null:
		return false
	ticks += 1
	if ticks == 4:
		var shot: Array = shots[index]
		var ap: AnimationPlayer = actor.visuals._animation
		if shot[1] != "":
			ap.play(shot[1], 0.0)
			ap.seek(shot[2], true)
			ap.pause()
	if ticks == 8:
		root.get_texture().get_image().save_png(
			"res://assets/models/qa_godot_%s.png" % shots[index][0]
		)
		index += 1
		ticks = 0
		if index == shots.size():
			quit()
	return false


func setup() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("27313b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.65
	environment.environment = env
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	stage.add_child(light)
	actor = load("res://scenes/enemies/walker.tscn").instantiate()
	stage.add_child(actor)
	actor.set_physics_process(false)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(2.8, 2.5, 6)
	camera.look_at(Vector3(0, 1.0, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0
	camera.current = true
	actor.visuals._animation.stop()
