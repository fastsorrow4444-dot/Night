extends Node
var model: CharacterVisual
var camera: Camera3D
@onready var root: Window = get_tree().root

func _ready() -> void:
	_run.call_deferred()

func shot(title: String) -> void:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/" + title + ".png")
	print("CAPTURE: ", title)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-results")
	var stage := Node3D.new()
	add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("232a32")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c1cfdf")
	settings.ambient_light_energy = 0.5
	environment.environment = settings
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 150, 0)
	light.light_color = Color("ffe1bd")
	light.light_energy = 1.0
	light.shadow_enabled = true
	stage.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1, 1.7, -1.3)
	fill.light_color = Color("bdcde5")
	fill.light_energy = 1.2
	stage.add_child(fill)
	model = CharacterVisual.new()
	stage.add_child(model)
	model.apply_appearance({"top":"work", "bottom":"work", "shoes":"work", "cap":false})
	camera = Camera3D.new()
	camera.cull_mask = 1 | 2
	camera.position = Vector3(0.7, 1.2, -3.1)
	camera.fov = 38
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.95, 0))
	camera.current = true
	await shot("character_work_full")
	camera.position = Vector3(0.36, 1.61, -1.0)
	camera.look_at(Vector3(0, 1.56, 0))
	await shot("character_face")
	camera.position = Vector3(0.36, 1.61, 1.0)
	camera.look_at(Vector3(0, 1.56, 0))
	await shot("character_back")
	model.apply_appearance({"top":"casual", "bottom":"casual", "shoes":"casual", "cap":false})
	camera.position = Vector3(-0.7, 1.2, -3.1)
	camera.look_at(Vector3(0, 0.95, 0))
	await shot("character_casual_full")
	stage.queue_free()
	for voice: Node in get_tree().root.get_node("Audio").get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
	for i in 3:
		await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()
