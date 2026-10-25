extends Node
## Optional graphical inspection. Requires a real display and OpenGL renderer.
var main: Node
@onready var root: Window = get_tree().root
var output := "res://test-results"
var capture_save := "user://capture_shift13_%d.json" % OS.get_process_id()

func _ready() -> void:
	_run.call_deferred()

func frames(count := 8) -> void:
	for i in count:
		await get_tree().process_frame

func shot(name: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Graphical capture is unavailable")
		get_tree().quit(1)
		return
	image.save_png(output + "/" + name + ".png")
	print("CAPTURE: ", name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var ignore := FileAccess.open(output + "/.gdignore", FileAccess.WRITE)
	ignore.close()
	var storage := root.get_node("Storage")
	var original_save: String = storage.save_path
	storage.save_path = capture_save
	main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	get_tree().current_scene = main
	await shot("menu")
	main.start_new_game()
	main.world.player.global_position = Vector3(3.4, 0.02, 7.1)
	main.world.player.camera.look_at(Vector3(8, 1.4, 1))
	await shot("gameplay")
	main.world.player.flashlight_controller.toggle()
	await get_tree().create_timer(0.83).timeout
	await shot("gameplay_flashlight")
	main.open_console(main.world.machine)
	await shot("console")
	main._close_console()
	main.pause_game()
	main.open_settings()
	await shot("settings")
	main._close_settings()
	main.resume_game()
	# Produce a real result using an isolated save, never the player's campaign.
	var world: FactoryWorld = main.world
	for i in 6:
		world.take_raw(world.player)
		world.machine.load_raw(world.player)
		world.machine.start_machine()
		world.machine.advance(13.0)
		world.machine.take_product(world.player)
		world.pack_product(world.player)
		await frames(1)
	world.shift_manager.finish()
	await shot("results")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(capture_save + suffix):
			DirAccess.remove_absolute(capture_save + suffix)
	storage.save_path = original_save
	main.queue_free()
	await frames(2)
	get_tree().quit()
