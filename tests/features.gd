extends Node
## New features are exercised through the real scene, UI, animation clock and save paths.
var checks := 0
var failures := 0
var main: Node
var test_path := "user://features_shift13_%d.json" % OS.get_process_id()
@onready var root: Window = get_tree().root

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, title: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", title)
	else:
		failures += 1
		push_error("FAIL: " + title)

func frames(count := 3) -> void:
	for i in count:
		await get_tree().process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func produce(world: FactoryWorld) -> void:
	world.take_raw(world.player)
	world.machine.load_raw(world.player)
	world.machine.start_machine()
	world.machine.advance(world.machine.batch_seconds + 1)
	world.machine.take_product(world.player)
	world.pack_product(world.player)
	await frames()

func meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child: Node in node.get_children():
		result.append_array(meshes(child))
	return result

func _run() -> void:
	var game := root.get_node("Game")
	var storage := root.get_node("Storage")
	var original_path: String = storage.save_path
	var original_settings_path: String = storage.settings_path
	var original_settings: Dictionary = storage.settings.duplicate(true)
	storage.save_path = test_path
	storage.settings_path = test_path + ".cfg"
	main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	get_tree().current_scene = main
	main.start_new_game()
	await frames()
	var world: FactoryWorld = main.world
	var player := world.player
	check(player.body_visual.parts.size() >= 30, "Original modular character imports with all articulated body parts")
	var textured := false
	for mesh: MeshInstance3D in meshes(player.body_visual.parts.TorsoWork):
		var material := mesh.get_active_material(0) as StandardMaterial3D
		if material != null and material.albedo_texture != null:
			textured = true
	check(textured, "Workwear uses real imported fabric textures")
	check(player.camera.cull_mask & 2 == 0 and player.camera.cull_mask & 4 != 0, "First-person camera hides the head and shows its own arms")
	check(meshes(player.body_visual.parts.ThighWorkL)[0].layers == 8, "Looking down can show the actual lower body")
	check(world.mirrors.size() == 2, "Locker room contains two actual mirrors")
	# Door/wardrobe dispatch is the same E interaction as the rest of the game.
	player.global_position = Vector3(-4.2, 0.02, 8.9)
	player.camera.look_at(Vector3(-4.2, 1.1, 6.65))
	await frames(5)
	check(player.interaction.target == world.wardrobe, "Physics ray finds the clothing locker")
	await key(KEY_E)
	check(main.mode == "wardrobe" and get_tree().paused, "E opens the wardrobe and pauses production")
	main.page.set_outfit("casual")
	check(game.appearance.top == "casual" and game.appearance.bottom == "casual" and not game.appearance.cap, "Personal outfit applies all selected clothing parts")
	check(player.body_visual.parts.TorsoCasual.visible and not player.body_visual.parts.TorsoWork.visible, "Full body actually changes to the personal hoodie")
	check(player.view_arms.parts.ForearmCasualR.visible and not player.view_arms.parts.ForearmWorkR.visible, "First-person sleeves change with the outfit")
	check(main.page.preview.parts.TorsoCasual.visible, "Live wardrobe preview matches the worn clothes")
	check(FileAccess.file_exists(storage.settings_path), "Clothing preference is saved immediately")
	main.page.draft.bottom = "work"
	main.page._apply()
	check(game.appearance.top == "casual" and game.appearance.bottom == "work", "Upper and lower clothing can be combined independently")
	await key(KEY_ESCAPE)
	check(main.mode == "play" and not get_tree().paused and player.active, "Escape closes the wardrobe and restores controls")
	# Put the observer in front of the full-length mirror and inspect its true geometry.
	player.global_position = Vector3(-11.6, 0.02, 10.25)
	player.rotation.y = PI / 2
	player.head.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	await frames(5)
	var mirror := world.mirrors[0]
	mirror.update_reflection()
	var normal := mirror.global_basis.z.normalized()
	var plane := mirror.surface.global_position
	var distance := normal.dot(player.camera.global_position - plane)
	var expected := player.camera.global_position - 2 * distance * normal
	check(mirror.rendering, "Mirror activates when the player looks into it")
	check(mirror.reflection_view.world_3d == world.get_world_3d(), "Mirror renders the actual factory world")
	check(mirror.reflection_camera.global_position.distance_to(expected) < 0.001, "Reflected camera is on the physically reflected side of the glass")
	check(mirror.reflection_camera.cull_mask & 2 != 0 and mirror.reflection_camera.cull_mask & 4 == 0, "Reflection includes the full character, with no duplicated first-person arms")
	check(mirror.reflection_camera.cull_mask & 16 == 0, "Mirrors exclude themselves and prevent recursive viewport rendering")
	var before := mirror.reflection_camera.global_position
	player.position.z += 0.4
	await frames()
	check(mirror.reflection_camera.global_position.distance_to(before) > 0.39, "Reflection viewpoint follows lateral player movement")
	player.rotate_y(PI)
	await frames()
	check(not mirror.rendering, "Offscreen mirror stops its additional render pass")
	# The light must wait for the button; draw/holster is not an instant visibility toggle.
	var lamp := player.flashlight_controller
	check(lamp.state == FlashlightController.State.HOLSTERED and not player.torch.visible, "Flashlight starts switched off on the belt")
	check(lamp.world_model.render_layer == 8 and not lamp.view_model.visible, "Holstered model belongs to the belt, with no floating hand torch")
	lamp.set_process(false)
	await key(KEY_F)
	check(lamp.state == FlashlightController.State.DRAWING and not lamp.is_lit, "F starts drawing the torch without switching the light on")
	lamp.advance(0.52)
	check(lamp.state == FlashlightController.State.PRESS_ON and not lamp.is_lit, "Drawing completes before the button is pressed")
	lamp.advance(0.15)
	await frames()
	check(lamp.is_lit and player.torch.visible and lamp.press_amount > 0.8, "Light turns on during the visible button-press animation")
	check(absf(player.body_visual.thumb.rotation.z) > 0.4, "The reflected hand's thumb physically presses the switch")
	lamp.advance(0.14)
	await frames()
	check(lamp.state == FlashlightController.State.ON and lamp.raise_amount == 1.0, "Flashlight reaches the stable held-on pose")
	check(lamp.world_model.render_layer == 2 and lamp.view_model.render_layer == 4 and lamp.view_model.visible, "World and first-person torch models use separate camera layers")
	check(player.view_arms.hands[1].global_basis.y.dot(Vector3.UP) > 0.9, "Holding pose closes the hand down around the torch rather than leaving fingers raised")
	world.take_raw(player)
	await frames()
	check(is_instance_valid(player.held_item) and player.hand.position.x < 0, "A box can be carried in the left hand while the right hand holds the torch")
	check(player.view_arms.elbows[0].rotation.x > 0.8, "Visible left arm adopts a carrying pose")
	player.consume_item(CarryItem.Kind.RAW)
	await key(KEY_F)
	check(lamp.state == FlashlightController.State.PRESS_OFF and lamp.is_lit, "Switching off starts with the hand pressing the still-lit torch")
	lamp.advance(0.14)
	check(not lamp.is_lit and lamp.raise_amount == 1.0, "Button switches off the light before the torch is put away")
	lamp.advance(0.65)
	check(lamp.state == FlashlightController.State.HOLSTERED and not lamp.view_model.visible, "Torch returns fully to the belt after switching off")
	lamp.toggle()
	lamp.toggle()
	lamp.toggle()
	lamp.advance(2.0)
	check(lamp.state == FlashlightController.State.ON and lamp.desired_on, "Rapid toggles finish in the last requested state without losing the model")
	lamp.toggle()
	lamp.advance(2.0)
	lamp.set_process(true)
	# A true pause also freezes animation time, not only the shift timer.
	lamp.toggle()
	await frames(3)
	main.pause_game()
	var elapsed: float = lamp.elapsed
	await frames(10)
	check(is_equal_approx(elapsed, lamp.elapsed), "Pause freezes an in-progress flashlight animation")
	main.resume_game()
	await frames(60)
	check(not world.events.enabled, "First shift does not accidentally run second-shift horror events")
	# Start shift two as normal campaign progression does, then produce real batches.
	game.shift = 2
	game.begin_session()
	main._start_work()
	await frames()
	world = main.world
	check(world.shift_manager.goal == 8 and world.shift_manager.duration == 1050.0, "Second shift has its own plan and duration")
	check(world.machine.batch_seconds == 10 and world.machine.target_temperature == 170, "Second shift applies its own production profile")
	check(world.events.enabled and world.journal.enabled and world.journal.visible, "Second shift activates its story and readable archive")
	check(not world.events.ringing, "Phone does not ring before the scripted production milestone")
	await produce(world)
	check(not world.events.ringing, "First box does not trigger the phone early")
	await produce(world)
	check(world.events.ringing and world.shift_manager.produced == 2, "Exactly the second packed box starts the telephone event")
	world.phone.interact(world.player)
	await frames()
	check(main.mode == "reading" and get_tree().paused and not world.events.ringing, "Answering the physical telephone opens its dialogue and stops ringing")
	check(game.choices.night2_phone == "answered", "Answering the call records the story decision")
	main._close_paused_page()
	await frames(365)
	check(world.events.blackout_active and world.environment.ambient_light_energy < 0.1, "The call is followed by a real temporary lighting blackout")
	check(world.lamps[0].light_energy < 0.1 and world.machine.power, "Lighting goes out while the production machine retains power")
	await frames(310)
	check(not world.events.blackout_active and world.lamps[0].light_energy > 0.5, "All factory lighting is restored after the blackout")
	world.journal.interact(world.player)
	await frames()
	check(main.mode == "reading" and NightEvents.JOURNAL_ID in game.documents, "Reading the physical journal adds its evidence to the save data")
	main._close_paused_page()
	for i in 6:
		await produce(world)
	check(world.shift_manager.produced == 8, "Second shift can complete all eight real production cycles")
	world.shift_manager.finish()
	var saved: Dictionary = storage.read_save()
	check(saved.appearance.top == "casual" and saved.appearance.bottom == "work", "Mixed clothing survives campaign autosave")
	check(NightEvents.JOURNAL_ID in saved.documents and saved.choices.night2_phone == "answered" and saved.choices.night2_blackout, "Journal and event decisions survive campaign autosave")
	game.change_appearance({"top": "work", "bottom": "work", "shoes": "work", "cap": true})
	check(game.continue_game() and game.appearance.top == "work", "Latest clothing preference survives Continue even when the last shift save wore different clothes")
	# Original saves lacking the new optional field remain loadable.
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("appearance")
	storage.write_save(legacy)
	check(game.continue_game(), "Existing version-one saves without clothing still load")
	check(game.appearance.top in ["work", "casual"], "Legacy save receives a valid outfit instead of failing")
	main.queue_free()
	await frames(3)
	for suffix: String in ["", ".bak", ".tmp", ".cfg"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(test_path + suffix)
	storage.save_path = original_path
	storage.settings_path = original_settings_path
	storage.settings = original_settings
	print("RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
