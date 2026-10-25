extends Node
var main: Node
@onready var root: Window = get_tree().root
var output := "res://test-results"
var temporary := "user://capture_avatar_%d" % OS.get_process_id()

func _ready() -> void:
	_run.call_deferred()

func frames(count := 6) -> void:
	for i in count:
		await get_tree().process_frame

func shot(title: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if picture == null or picture.is_empty():
		get_tree().quit(1)
		return
	picture.save_png(output + "/" + title + ".png")
	print("CAPTURE: ", title)

func face_mirror() -> void:
	var player: PlayerController = main.world.player
	player.position = Vector3(-11.7, 0.02, 10.25)
	player.rotation = Vector3(0, PI / 2, 0)
	player.head.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var ignored := FileAccess.open(output + "/.gdignore", FileAccess.WRITE)
	ignored.close()
	ignored = null
	var storage := root.get_node("Storage")
	var game := root.get_node("Game")
	var old_save: String = storage.save_path
	var old_settings: String = storage.settings_path
	storage.save_path = temporary + ".json"
	storage.settings_path = temporary + ".cfg"
	game.appearance = game.sanitize_appearance({})
	main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	get_tree().current_scene = main
	main.start_new_game()
	face_mirror()
	await shot("mirror_work")
	main.open_wardrobe(main.world.player)
	await shot("wardrobe_work")
	main.page.set_outfit("casual")
	await shot("wardrobe_personal")
	main._close_paused_page()
	await shot("mirror_personal")
	main.world.player.flashlight_controller.toggle()
	await get_tree().create_timer(0.83).timeout
	await shot("mirror_flashlight")
	main.world.player.head.rotation.x = -0.85
	await shot("hands_flashlight")
	main.world.player.flashlight_controller.toggle()
	await get_tree().create_timer(0.83).timeout
	await shot("belt_flashlight")
	game.shift = 2
	game.begin_session()
	main._start_work()
	var world: FactoryWorld = main.world
	for i in 2:
		world.take_raw(world.player)
		world.machine.load_raw(world.player)
		world.machine.start_machine()
		world.machine.advance(11.0)
		world.machine.take_product(world.player)
		world.pack_product(world.player)
		await frames(1)
	world.phone.interact(world.player)
	await shot("night2_phone")
	main._close_paused_page()
	world.player.position = Vector3(3.4, 0.02, 7.1)
	world.player.rotation.y = -0.646
	world.player.head.rotation.x = -0.025
	world.player.camera.rotation = Vector3.ZERO
	world.events.start_blackout()
	world.player.flashlight_controller.toggle()
	await get_tree().create_timer(0.83).timeout
	await shot("night2_blackout")
	world.events.restore_lights()
	world.journal.interact(world.player)
	await shot("night2_journal")
	main._close_paused_page()
	main.world.end_work()
	main.queue_free()
	for voice: Node in root.get_node("Audio").get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
	await get_tree().create_timer(0.15).timeout
	for suffix: String in [".json", ".json.bak", ".json.tmp", ".cfg"]:
		if FileAccess.file_exists(temporary + suffix):
			DirAccess.remove_absolute(temporary + suffix)
	storage.save_path = old_save
	storage.settings_path = old_settings
	get_tree().quit()
