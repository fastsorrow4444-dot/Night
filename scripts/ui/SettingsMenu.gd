extends Control
signal closed
signal applied
var resolution: OptionButton
var fullscreen: CheckButton
var volume: HSlider
var sensitivity: HSlider
var quality: OptionButton
var message: Label
const RESOLUTIONS := [Vector2i(1280, 800), Vector2i(1600, 900), Vector2i(1920, 1080)]

func _ready() -> void:
	UIFactory.full(self)
	theme = UIFactory.theme()
	UIFactory.dim(self)
	var panel := UIFactory.centered(self, 660, 610)
	var column := UIFactory.column(panel, 18)
	column.add_child(UIFactory.label("ЛИЧНЫЕ ПАРАМЕТРЫ", 12, UIFactory.AMBER, UIFactory.MONO))
	column.add_child(UIFactory.label("Настройки", 34, UIFactory.PAPER, UIFactory.BOLD))
	UIFactory.rule(column)
	resolution = OptionButton.new()
	for value: Vector2i in RESOLUTIONS:
		resolution.add_item("%d × %d" % [value.x, value.y])
	resolution.select(int(Storage.settings.resolution))
	_row(column, "Разрешение окна", resolution)
	fullscreen = CheckButton.new()
	fullscreen.text = "Полный экран"
	fullscreen.button_pressed = bool(Storage.settings.fullscreen)
	_row(column, "Режим экрана", fullscreen)
	volume = _slider(0, 100, 1, float(Storage.settings.volume) * 100)
	_row(column, "Общая громкость", volume)
	sensitivity = _slider(5, 60, 1, float(Storage.settings.sensitivity) * 10000)
	_row(column, "Чувствительность мыши", sensitivity)
	quality = OptionButton.new()
	for text: String in ["Низкое · без теней", "Среднее · MSAA 2×", "Высокое · MSAA 4×"]:
		quality.add_item(text)
	quality.select(int(Storage.settings.quality))
	_row(column, "Качество графики", quality)
	message = UIFactory.paragraph("Настройки применяются сразу, без перезапуска.", 14)
	column.add_child(message)
	column.add_child(UIFactory.button("ПРИМЕНИТЬ", _apply, true))
	column.add_child(UIFactory.button("НАЗАД   /   ESC", func() -> void: closed.emit()))

func _row(parent: VBoxContainer, text: String, input: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var caption := UIFactory.label(text, 16)
	caption.custom_minimum_size.x = 260
	row.add_child(caption)
	input.custom_minimum_size = Vector2(280, 38)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)

func _slider(minimum: float, maximum: float, increment: float, initial: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.value = initial
	return slider

func _apply() -> void:
	Storage.settings.volume = volume.value / 100.0
	Storage.settings.sensitivity = sensitivity.value / 10000.0
	Storage.settings.fullscreen = fullscreen.button_pressed
	Storage.settings.resolution = resolution.selected
	Storage.settings.quality = quality.selected
	apply_runtime()
	var result := Storage.save_settings()
	message.text = "Настройки сохранены." if result == OK else "Настройки применены, но запись не удалась: " + error_string(result)
	applied.emit()

static func apply_runtime() -> void:
	Audio.apply_volume()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(Storage.settings.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED)
		if not bool(Storage.settings.fullscreen):
			DisplayServer.window_set_size(RESOLUTIONS[int(Storage.settings.resolution)])
	var viewport := Engine.get_main_loop().root as Window
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(Storage.settings.quality)]
	for light: Node in Engine.get_main_loop().get_nodes_in_group("quality_lights"):
		(light as Light3D).shadow_enabled = int(Storage.settings.quality) > 0
