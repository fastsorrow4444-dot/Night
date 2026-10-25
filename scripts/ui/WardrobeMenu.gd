extends Control
signal closed
var actor: PlayerController
var preview: CharacterVisual
var draft: Dictionary
var selectors: Dictionary = {}
var cap: CheckButton
var feedback: Label

func _ready() -> void:
	UIFactory.full(self)
	theme = UIFactory.theme()
	UIFactory.dim(self, 0.88)
	draft = Game.appearance.duplicate(true)
	var panel := UIFactory.centered(self, 1050, 720)
	var column := UIFactory.column(panel, 16)
	column.add_child(UIFactory.label("РАЗДЕВАЛКА / ЛИЧНЫЙ ШКАФ 07", 12, UIFactory.AMBER, UIFactory.MONO))
	column.add_child(UIFactory.label("До начала работы", 32, UIFactory.PAPER, UIFactory.BOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	column.add_child(row)
	var preview_box := SubViewportContainer.new()
	preview_box.custom_minimum_size = Vector2(410, 490)
	preview_box.stretch = true
	row.add_child(preview_box)
	_build_preview(preview_box)
	var controls := UIFactory.column(row, 16)
	controls.custom_minimum_size.x = 470
	controls.add_child(UIFactory.label("ВАША ОДЕЖДА", 13, UIFactory.AMBER, UIFactory.MONO))
	_add_selector(controls, "top", "Верх", ["Рабочая куртка / Севертехпром", "Личное худи / бордовый хлопок"])
	_add_selector(controls, "bottom", "Брюки", ["Рабочие брюки / карго", "Личные джинсы / индиго"])
	_add_selector(controls, "shoes", "Обувь", ["Защитные рабочие ботинки", "Личная обувь / тёмный текстиль"])
	cap = CheckButton.new()
	cap.text = "Рабочая кепка"
	cap.button_pressed = bool(draft.cap)
	cap.toggled.connect(func(value: bool) -> void:
		draft.cap = value
		_apply())
	controls.add_child(cap)
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	controls.add_child(presets)
	for entry: Array in [["РАБОЧИЙ КОМПЛЕКТ", "work"], ["ЛИЧНЫЙ КОМПЛЕКТ", "casual"]]:
		var id: String = entry[1]
		var button := UIFactory.button(entry[0], func() -> void: set_outfit(id))
		button.add_theme_font_size_override("font_size", 12)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		presets.add_child(button)
	feedback = UIFactory.paragraph("Одежду видно на руках и на персонаже в зеркалах. Элементы можно сочетать.", 14)
	controls.add_child(feedback)
	column.add_child(UIFactory.button("ГОТОВО / ПОСМОТРЕТЬ В ЗЕРКАЛО   ·   ESC", func() -> void: closed.emit(), true))

func _add_selector(parent: VBoxContainer, key: String, caption: String, entries: Array) -> void:
	parent.add_child(UIFactory.label(caption, 15, UIFactory.MUTED))
	var selector := OptionButton.new()
	selector.custom_minimum_size.y = 43
	for title: String in entries:
		selector.add_item(title)
	selector.select(0 if draft[key] == "work" else 1)
	selector.item_selected.connect(func(index: int) -> void:
		draft[key] = "work" if index == 0 else "casual"
		_apply())
	parent.add_child(selector)
	selectors[key] = selector

func set_outfit(id: String) -> void:
	for key: String in ["top", "bottom", "shoes"]:
		draft[key] = id
		(selectors[key] as OptionButton).select(0 if id == "work" else 1)
	draft.cap = id == "work"
	cap.set_pressed_no_signal(bool(draft.cap))
	_apply()

func _apply() -> void:
	var result := Game.change_appearance(draft)
	actor.apply_appearance(Game.appearance)
	preview.apply_appearance(Game.appearance)
	feedback.text = "Комплект сохранён. Посмотрите на себя в зеркало." if result == OK else "Одежда изменена. Сохранить настройки не удалось: " + error_string(result)

func _build_preview(container: SubViewportContainer) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(410, 490)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("232a32")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c1cfdf")
	settings.ambient_light_energy = 0.45
	environment.environment = settings
	stage.add_child(environment)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-25, 150, 0)
	key_light.light_color = Color("fce5c5")
	key_light.light_energy = 1.1
	stage.add_child(key_light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.2, 1.6, -1.2)
	fill.light_color = Color("bdcde5")
	fill.light_energy = 0.7
	fill.omni_range = 5.0
	stage.add_child(fill)
	preview = CharacterVisual.new()
	preview.process_mode = Node.PROCESS_MODE_ALWAYS
	stage.add_child(preview)
	var camera := Camera3D.new()
	camera.position = Vector3(1.1, 1.18, -2.8)
	camera.cull_mask = 1 | 2 | 8
	camera.fov = 42
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.94, 0))
	camera.current = true
	WorldBuilder.cylinder(stage, Vector3(0, -0.045, 0), 0.55, 0.08, Color("3f4e48"))
