extends Node
## Visual demo of the actual controller/rig, for Godot --write-movie (30 fps).
var stage: Node3D
var actor: PlayerController
var camera: Camera3D
var frame := 0

func _ready() -> void:
	stage = Node3D.new()
	add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("232a32")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c1cfdf")
	settings.ambient_light_energy = 0.45
	environment.environment = settings
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 150, 0)
	key.light_color = Color("ffe3c2")
	key.light_energy = 1.1
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1, 1.5, -1.2)
	fill.light_color = Color("bccfe5")
	fill.light_energy = 0.6
	stage.add_child(fill)
	WorldBuilder.box(stage, Vector3(0, -0.04, 0), Vector3(4, 0.08, 4), Color("424951"))
	actor = (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	stage.add_child(actor)
	actor.set_active(false)
	actor.apply_appearance({"top":"work", "bottom":"work", "shoes":"work", "cap":false})
	actor.camera.current = false
	camera = Camera3D.new()
	camera.position = Vector3(0.9, 1.18, -3.4)
	camera.fov = 36
	camera.cull_mask = 1 | 2
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.94, 0))
	camera.current = true

func _process(_delta: float) -> void:
	frame += 1
	if frame >= 210:
		if frame == 210:
			stage.queue_free()
			for voice: Node in get_tree().root.get_node("Audio").get_children():
				if voice is AudioStreamPlayer:
					voice.stop()
		if frame >= 214:
			get_tree().quit()
		return
	if frame == 25:
		actor.velocity = Vector3(0, 0, -2.0)
	if frame == 82:
		actor.velocity = Vector3.ZERO
	if frame == 98:
		actor.flashlight_controller.toggle()
	if frame >= 128 and frame < 152:
		actor.head.position.y = lerpf(actor.head.position.y, 0.91, 0.2)
	if frame >= 152:
		actor.head.position.y = lerpf(actor.head.position.y, 1.64, 0.2)
	if frame == 174:
		actor.flashlight_controller.toggle()
