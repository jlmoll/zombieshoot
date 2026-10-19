extends SceneTree
## Run without --headless to render a close view of each imported player clip.
var actor: Node3D
var ap: AnimationPlayer
var camera: Camera3D
var ticks: int = 0
var index: int = 0
var shots: Array = [
	["Idle", 0.6], ["Aim", 0.6], ["Walk", 0.2], ["Dash", 0.17], ["Reload", 0.45], ["Death", 0.65]
]


func _initialize() -> void:
	call_deferred("setup")


func _process(_dt: float) -> bool:
	if actor == null:
		return false
	ticks += 1
	if ticks == 3:
		var shot: Array = shots[index]
		if not ap.has_animation(shot[0]):
			push_error("Missing QA clip: " + shot[0])
			quit(1)
			return false
		ap.play(shot[0], 0.0)
		ap.seek(minf(shot[1], ap.get_animation(shot[0]).length), true)
		ap.pause()
		root.get_node("ClipName").text = shot[0]
	if ticks == 7:
		root.get_texture().get_image().save_png(
			"res://assets/models/qa_player_%s.png" % shots[index][0]
		)
		index += 1
		ticks = 0
		if index == shots.size():
			quit()
	return false


func setup() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(900, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("26333c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bfcdd6")
	env.ambient_light_energy = 0.65
	environment.environment = env
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_energy = 1.5
	stage.add_child(light)
	actor = load("res://assets/models/player_technician.glb").instantiate()
	stage.add_child(actor)
	ap = actor.find_child("AnimationPlayer", true, false)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(3.2, 2.6, 6)
	camera.look_at(Vector3(0, .85, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.35
	camera.current = true
	var label := Label.new()
	label.name = "ClipName"
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 28)
	root.add_child(label)
