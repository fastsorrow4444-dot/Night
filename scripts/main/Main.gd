extends Node
const MENU = preload("res://scenes/ui/MainMenu.tscn")
const SETTINGS = preload("res://scenes/ui/SettingsMenu.tscn")
const HUD_SCENE = preload("res://scenes/ui/HUD.tscn")
const MACHINE_PANEL = preload("res://scenes/ui/MachinePanel.tscn")
const RESULTS = preload("res://scenes/ui/ResultsScreen.tscn")
var world: FactoryWorld
var canvas: CanvasLayer
var page: Control
var hud: Control
var mode := "menu"
var settings_return := "menu"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var film_layer := CanvasLayer.new()
	film_layer.layer = 5
	add_child(film_layer)
	var film := ColorRect.new()
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/film.gdshader")
	film.material = material
	film_layer.add_child(film)
	UIFactory.full(film)
	Game.shift_completed.connect(_on_shift_completed)
	preload("res://scripts/ui/SettingsMenu.gd").apply_runtime()
	show_menu()

func _new_world() -> void:
	if is_instance_valid(world):
		world.end_work()
		remove_child(world)
		world.queue_free()
	world = preload("res://scenes/world/Factory.tscn").instantiate()
	add_child(world)
	world.player.torch.add_to_group("quality_lights")
	world.player.torch.shadow_enabled = int(Storage.settings.quality) > 0
	world.console_requested.connect(open_console)

func _clear_page() -> void:
	if is_instance_valid(page):
		canvas.remove_child(page)
		page.queue_free()
	page = null

func show_menu() -> void:
	get_tree().paused = false
	Game.session_active = false
	_clear_page()
	if is_instance_valid(hud):
		hud.queue_free()
		hud = null
	_new_world()
	mode = "menu"
	page = MENU.instantiate()
	page.new_requested.connect(_confirm_new_game)
	page.continue_requested.connect(_continue_game)
	page.settings_requested.connect(open_settings)
	page.exit_requested.connect(func() -> void: get_tree().quit())
	canvas.add_child(page)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _confirm_new_game() -> void:
	if not Storage.has_save():
		start_new_game()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Начать новую игру?"
	dialog.dialog_text = "После завершения новой смены прежнее сохранение будет заменено."
	dialog.ok_button_text = "Начать"
	dialog.cancel_button_text = "Отмена"
	dialog.confirmed.connect(start_new_game)
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	canvas.add_child(dialog)
	dialog.popup_centered(Vector2i(560, 160))

func start_new_game() -> void:
	Game.new_game()
	_start_work()

func _continue_game() -> void:
	if Game.continue_game():
		var recovery_message := Storage.last_error
		_start_work()
		if not recovery_message.is_empty():
			Game.notify(recovery_message)
	else:
		var dialog := AcceptDialog.new()
		dialog.dialog_text = Storage.last_error if not Storage.last_error.is_empty() else "Сохранённой смены пока нет."
		canvas.add_child(dialog)
		dialog.confirmed.connect(dialog.queue_free)
		dialog.popup_centered()

func _start_work() -> void:
	get_tree().paused = false
	_clear_page()
	if is_instance_valid(hud):
		hud.queue_free()
	_new_world()
	hud = HUD_SCENE.instantiate()
	hud.world = world
	canvas.add_child(hud)
	mode = "play"
	world.start_work()

func open_console(machine: FactoryMachine) -> void:
	if mode != "play":
		return
	mode = "machine"
	world.player.set_active(false)
	page = MACHINE_PANEL.instantiate()
	page.machine = machine
	page.closed.connect(_close_console)
	canvas.add_child(page)

func _close_console() -> void:
	_clear_page()
	mode = "play"
	world.player.set_active(true)

func pause_game() -> void:
	mode = "pause"
	world.player.set_active(false)
	get_tree().paused = true
	page = Control.new()
	canvas.add_child(page)
	UIFactory.full(page)
	page.theme = UIFactory.theme()
	UIFactory.dim(page)
	var panel := UIFactory.centered(page, 500, 420)
	var column := UIFactory.column(panel, 16)
	column.add_child(UIFactory.label("ПРОИЗВОДСТВО ПРИОСТАНОВЛЕНО", 12, UIFactory.AMBER, UIFactory.MONO))
	column.add_child(UIFactory.label("Технический перерыв", 26, UIFactory.PAPER, UIFactory.BOLD))
	column.add_child(UIFactory.button("ВЕРНУТЬСЯ К РАБОТЕ", resume_game, true))
	column.add_child(UIFactory.button("НАСТРОЙКИ", open_settings))
	column.add_child(UIFactory.button("В ГЛАВНОЕ МЕНЮ", _confirm_menu))
	column.add_child(UIFactory.paragraph("Текущая смена сохранится после её завершения. Здесь время остановлено.", 14))

func _confirm_menu() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Закончить перерыв?"
	dialog.dialog_text = "Прогресс текущей смены будет потерян. Последнее автосохранение останется."
	dialog.ok_button_text = "В меню"
	dialog.cancel_button_text = "Остаться"
	dialog.confirmed.connect(show_menu)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	canvas.add_child(dialog)
	dialog.popup_centered(Vector2i(580, 160))

func resume_game() -> void:
	_clear_page()
	get_tree().paused = false
	mode = "play"
	world.player.set_active(true)

func open_settings() -> void:
	settings_return = mode
	_clear_page()
	mode = "settings"
	page = SETTINGS.instantiate()
	page.closed.connect(_close_settings)
	canvas.add_child(page)

func _close_settings() -> void:
	_clear_page()
	if settings_return == "pause":
		pause_game()
	else:
		show_menu()

func _on_shift_completed(result: Dictionary) -> void:
	get_tree().paused = false
	_clear_page()
	mode = "results"
	world.end_work()
	if is_instance_valid(hud):
		hud.hide()
	page = RESULTS.instantiate()
	page.result = result
	page.continue_requested.connect(func() -> void:
		Game.begin_session()
		_start_work())
	page.menu_requested.connect(show_menu)
	canvas.add_child(page)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		match mode:
			"play": pause_game()
			"pause": resume_game()
			"machine": _close_console()
			"settings": _close_settings()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tasks") and mode == "play":
		hud.toggle_tasks()
		get_viewport().set_input_as_handled()
