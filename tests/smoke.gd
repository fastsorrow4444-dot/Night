extends Node
## Runs the real scenes, physics ray, UI callbacks and save files without addons.
var failures := 0
var checks := 0
var main: Node
@onready var root: Window = get_tree().root
var test_save := "user://smoke_shift13_%d.json" % OS.get_process_id()
var original_save := ""
var original_settings := ""

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

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

func aim(player: PlayerController, from: Vector3, to: Vector3) -> void:
	player.global_position = from
	player.velocity = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.camera.look_at(to)
	await get_tree().physics_frame
	await frames(3)

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child: Node in node.get_children():
		var found := find_button(child, text)
		if found != null:
			return found
	return null

func _run() -> void:
	var storage := root.get_node("Storage")
	var game := root.get_node("Game")
	original_save = storage.save_path
	original_settings = storage.settings_path
	storage.save_path = test_save
	storage.settings_path = test_save + ".cfg"
	main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	get_tree().current_scene = main
	await frames()
	check(main.mode == "menu", "Main scene opens the menu")
	check(find_button(main.page, "ПРОДОЛЖИТЬ").disabled, "Continue is disabled without a save")
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "sprint", "crouch", "interact", "flashlight", "tasks", "drop_item"]:
		check(InputMap.has_action(action), "Input action exists: " + action)
	check((InputMap.action_get_events("sprint")[0] as InputEventKey).physical_keycode == KEY_SHIFT, "Shift key is bound correctly")
	check((InputMap.action_get_events("crouch")[0] as InputEventKey).physical_keycode == KEY_CTRL, "Ctrl key is bound correctly")
	main.start_new_game()
	await frames()
	var world: FactoryWorld = main.world
	var player := world.player
	check(player.active and player.camera.current, "New game activates the first-person player")
	check(main.hud.crosshair.position.distance_to(main.hud.size * 0.5) < 0.1, "Reticle matches the center of the interaction ray")
	check(world.shift_manager.active and world.shift_manager.produced == 0, "Production shift starts at zero")
	check(not world.shift_manager.finish(), "Cannot finish an incomplete shift")
	check(not world.machine.start_machine(), "Cannot start without raw material")
	world.pack_product(player)
	check(world.shift_manager.produced == 0, "Empty hands cannot create a delivered box")
	# Use the actual physics ray and input dispatch to open the locker-room door.
	await aim(player, Vector3(-3.8, 0.02, 9), Vector3(-2, 1.3, 9))
	check(player.interaction.target is FactoryDoor, "Interaction ray finds the closed door")
	var door: FactoryDoor = player.interaction.target
	await key(KEY_E)
	check(door.is_open, "E opens the door")
	await get_tree().create_timer(0.65).timeout
	var query := PhysicsRayQueryParameters3D.create(Vector3(-3, 1, 9), Vector3(-1, 1, 9), 1)
	check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Open door clears its physical passage")
	# Walking, sprint, crouch, flashlight and task overlay all go through InputMap.
	player.camera.rotation = Vector3.ZERO
	player.global_position = Vector3(0, 0.02, 5)
	player.rotation = Vector3.ZERO
	var before := player.position.z
	Input.action_press("move_forward")
	await frames(20)
	Input.action_release("move_forward")
	check(player.position.z < before - 0.3, "WASD drives CharacterBody3D physics movement")
	Input.action_press("crouch")
	await frames(8)
	check((player.body_shape.shape as CapsuleShape3D).height < 1.2, "Crouch reduces the physical capsule")
	Input.action_release("crouch")
	await frames(8)
	check((player.body_shape.shape as CapsuleShape3D).height > 1.7, "Player can stand back up")
	var torch_was_on := player.torch.visible
	await key(KEY_F)
	check(player.torch.visible != torch_was_on, "F toggles the flashlight")
	await key(KEY_TAB)
	check(main.hud.tasks_panel.visible, "Tab opens the operator instructions")
	await key(KEY_TAB)
	# Take a raw box, drop it and pick the same physical item up again.
	await aim(player, Vector3(-5.4, 0.02, 2.7), Vector3(-5.4, 1.0, 0.6))
	check(player.interaction.target == world.supply, "Ray finds the warehouse supply")
	await key(KEY_E)
	check(is_instance_valid(player.held_item) and player.held_item.kind == CarryItem.Kind.RAW, "E takes a raw box from the warehouse")
	var raw := player.held_item
	world.take_raw(player)
	check(player.held_item == raw, "Cannot carry two items")
	player.camera.rotation = Vector3.ZERO
	await key(KEY_G)
	check(player.held_item == null and not raw.freeze, "G releases a real physics object")
	await frames(3)
	check(player.pick_up(raw), "Dropped object can be picked up again")
	await aim(player, Vector3(5.35, 0.02, 4.15), Vector3(5.35, 0.95, 2.0))
	await key(KEY_E)
	check(world.machine.loaded and player.held_item == null, "E loads the hopper and consumes the carried raw box")
	# Open the real control panel, deliberately overheat, repair and finish a batch.
	await aim(player, Vector3(10.65, 0.02, 4.1), Vector3(10.65, 1.22, 2.05))
	await key(KEY_E)
	check(main.mode == "machine" and not player.active, "Control panel opens and releases mouse capture")
	main.page.temp_slider.value = 240
	find_button(main.page, "START").pressed.emit()
	world.machine.advance(2.1)
	check(world.machine.state == FactoryMachine.State.FAULT, "Unsafe temperature produces a real machine failure")
	check(world.shift_manager.mistakes == 1, "A failure adds one salary penalty")
	check(not world.machine.reset_machine(), "RESET refuses parameters that are still unsafe")
	main.page.temp_slider.value = 160
	find_button(main.page, "RESET").pressed.emit()
	find_button(main.page, "START").pressed.emit()
	world.machine.advance(4.0)
	world.machine.stop_machine()
	var paused_progress := world.machine.progress
	world.machine.advance(2.0)
	check(is_equal_approx(world.machine.progress, paused_progress), "STOP retains progress without running production")
	world.machine.start_machine()
	world.machine.advance(12.0)
	check(world.machine.state == FactoryMachine.State.READY, "Corrected machine completes the batch")
	await key(KEY_ESCAPE)
	check(main.mode == "play" and player.active, "Escape closes machine controls and resumes walking")
	await aim(player, Vector3(8, 0.02, 5.5), Vector3(8, 0.8, 3.45))
	await key(KEY_E)
	check(is_instance_valid(player.held_item) and player.held_item.kind == CarryItem.Kind.PRODUCT, "E collects the finished product")
	await aim(player, Vector3(9, 0.02, 6.5), Vector3(9, 0.85, 8.8))
	await key(KEY_E)
	check(world.shift_manager.produced == 1 and player.held_item == null, "Packaging consumes the product and increments the plan")
	world.pack_product(player)
	check(world.shift_manager.produced == 1, "Cannot count the same product twice")
	# Exercise remaining batches with the same production APIs; no fake goal changes.
	for i in 5:
		world.take_raw(player)
		world.machine.load_raw(player)
		world.machine.start_machine()
		world.machine.advance(13.0)
		world.machine.take_product(player)
		world.pack_product(player)
		await frames()
	check(world.shift_manager.produced == 6, "Six complete raw → machine → product → package cycles meet the plan")
	world.take_raw(player)
	check(player.held_item == null, "Warehouse stops issuing raw material after the goal")
	# Persistent fields are round-tripped, including later story and upgrade data.
	game.upgrades = ["test_flashlight"]
	game.choices = {"room13": "ignored"}
	game.documents = ["safety_note"]
	await aim(player, Vector3(-4.8, 0.02, 9.65), Vector3(-4.8, 1.3, 11.7))
	await key(KEY_E)
	check(main.mode == "results", "Terminal opens the shift results")
	check(game.money == 130, "Salary is $100 + $40 bonus − $10 penalty")
	check(game.shift == 2 and storage.has_save(), "Completion autosaves the next shift")
	var saved: Dictionary = storage.read_save()
	check(saved.money == 130 and saved.shift == 2, "Saved salary and shift round-trip")
	check(saved.upgrades == ["test_flashlight"] and saved.documents == ["safety_note"] and saved.choices.room13 == "ignored", "Upgrades, documents and story choices round-trip")
	check(not world.shift_manager.finish() and game.money == 130, "Finishing twice cannot award a second salary")
	main.show_menu()
	await frames()
	check(not find_button(main.page, "ПРОДОЛЖИТЬ").disabled, "Continue becomes enabled after the autosave")
	main._continue_game()
	await frames()
	check(main.mode == "play" and game.shift == 2 and main.world.shift_manager.produced == 0, "Continue starts the saved next shift with a fresh production state")
	main.pause_game()
	var remaining: float = main.world.shift_manager.remaining
	await get_tree().create_timer(0.1, true).timeout
	check(is_equal_approx(main.world.shift_manager.remaining, remaining), "Pause freezes the shift timer")
	main.open_settings()
	await frames()
	main.page.volume.value = 50
	main.page.sensitivity.value = 25
	main.page._apply()
	check(is_equal_approx(storage.settings.volume, 0.5) and FileAccess.file_exists(storage.settings_path), "Settings apply and persist separately from the game save")
	main._close_settings()
	check(main.mode == "pause" and get_tree().paused, "Closing settings restores the paused state")
	main.resume_game()
	# Verify each supported machine diagnosis and the physical breaker.
	check(MachineFailure.detect(160, 1, 1, true) == MachineFailure.Kind.PRESSURE, "Low pressure is diagnosed")
	check(MachineFailure.detect(160, 4, 1.8, true) == MachineFailure.Kind.JAM, "Excessive speed is diagnosed")
	world = main.world
	world.take_raw(world.player)
	world.machine.load_raw(world.player)
	world.machine.start_machine()
	world.breaker.interact(world.player)
	check(world.machine.state == FactoryMachine.State.FAULT and not world.machine.power, "Breaker cuts power and faults the running machine")
	world.breaker.interact(world.player)
	check(world.machine.reset_machine(), "Restoring power permits a safe reset")
	# A timeout must also produce results and save, with no unearned plan bonus.
	world.shift_manager.remaining = 0.01
	await frames(3)
	check(main.mode == "results" and game.last_result.timed_out, "An expired shift opens a timeout result")
	check(game.last_result.bonus == 0 and game.last_result.produced == 0, "An incomplete plan earns no production bonus")
	check(storage.write_save(game.serialize()), "Repeated saves replace the prior complete file")
	var corrupt := FileAccess.open(test_save, FileAccess.WRITE)
	corrupt.store_string("{broken json")
	corrupt.close()
	check(not storage.read_save().is_empty() and not storage.last_error.is_empty(), "A corrupted primary save recovers from its backup")
	# Isolated test files never overwrite a player's actual save.
	for suffix: String in ["", ".bak", ".tmp", ".cfg"]:
		if FileAccess.file_exists(test_save + suffix):
			DirAccess.remove_absolute(test_save + suffix)
	storage.save_path = original_save
	storage.settings_path = original_settings
	print("RESULT: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await frames(2)
	get_tree().quit(0 if failures == 0 else 1)
