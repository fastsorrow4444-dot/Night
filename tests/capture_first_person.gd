extends Node
var main: Node
@onready var root: Window = get_tree().root

func _ready() -> void:
	_run.call_deferred()

func frames(count := 8) -> void:
	for i in count:
		await get_tree().process_frame

func shot(name: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/" + name + ".png")
	print("CAPTURE: ", name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-results")
	var ignore := FileAccess.open("res://test-results/.gdignore", FileAccess.WRITE)
	ignore.close()
	ignore = null
	main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	get_tree().current_scene = main
	main.start_new_game()
	main.hud.toast_seconds = 0
	var world: FactoryWorld = main.world
	var player := world.player
	player.position = Vector3(4.0, 0.02, 6.4)
	player.rotation.y = -0.54
	player.head.rotation = Vector3.ZERO
	await shot("graphics_factory")
	world.take_raw(player)
	player.flashlight_controller.toggle()
	await get_tree().create_timer(0.85).timeout
	await shot("carry_forward")
	for value: float in [-0.7, -1.15, -1.45]:
		player.head.rotation.x = value
		await shot("carry_down_%d" % roundi(absf(value)*100))
	Input.action_press("crouch")
	await frames(25)
	await shot("carry_crouch")
	Input.action_release("crouch")
	await frames(25)
	player.consume_item(CarryItem.Kind.RAW)
	await shot("legs_clear")
	player.head.rotation.x = 0
	world.take_raw(player)
	world.machine.load_raw(player)
	world.machine.start_machine()
	await get_tree().create_timer(1.0).timeout
	await shot("graphics_machine_running")
	player.position = Vector3(-11.7,0.02,10.25)
	player.rotation.y = PI / 2
	player.head.rotation.x = 0
	await shot("mirror_new_grip")
	main.world.end_work()
	main.queue_free()
	for voice: Node in root.get_node("Audio").get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()
