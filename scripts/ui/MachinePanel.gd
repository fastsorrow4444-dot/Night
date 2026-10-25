extends Control
signal closed
var machine: FactoryMachine
var temperature: Label
var pressure: Label
var state: Label
var progress: ProgressBar
var failure: Label
var temp_slider: HSlider
var pressure_slider: HSlider
var speed_slider: HSlider

func _ready() -> void:
	UIFactory.full(self)
	theme = UIFactory.theme()
	UIFactory.dim(self, 0.78)
	var panel := UIFactory.centered(self, 900, 640)
	var root := UIFactory.column(panel, 18)
	root.add_child(UIFactory.label("СЕВЕРТЕХПРОМ  /  ПУЛЬТ ОПЕРАТОРА", 13, UIFactory.AMBER, UIFactory.MONO))
	root.add_child(UIFactory.label("М–13 / Линия обработки", 30, UIFactory.PAPER, UIFactory.BOLD))
	UIFactory.rule(root)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	root.add_child(columns)
	var gauges := UIFactory.column(columns, 12)
	gauges.custom_minimum_size.x = 300
	state = UIFactory.label("", 15, UIFactory.GREEN, UIFactory.MONO)
	gauges.add_child(state)
	gauges.add_child(UIFactory.label("ТЕМПЕРАТУРА / ФАКТ", 11, UIFactory.MUTED, UIFactory.MONO))
	temperature = UIFactory.label("", 42, UIFactory.PAPER, UIFactory.MONO)
	gauges.add_child(temperature)
	gauges.add_child(UIFactory.label("ДАВЛЕНИЕ / ФАКТ", 11, UIFactory.MUTED, UIFactory.MONO))
	pressure = UIFactory.label("", 42, UIFactory.PAPER, UIFactory.MONO)
	gauges.add_child(pressure)
	gauges.add_child(UIFactory.label("ГОТОВНОСТЬ ПАРТИИ", 11, UIFactory.MUTED, UIFactory.MONO))
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 22
	gauges.add_child(progress)
	var controls := UIFactory.column(columns, 12)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(UIFactory.label("РЕЦЕПТ A / РАБОЧИЕ ПРЕДЕЛЫ", 12, UIFactory.GREEN, UIFactory.MONO))
	temp_slider = _setting(controls, "Температура", "°C", 80, 240, 10, machine.target_temperature)
	temp_slider.value_changed.connect(func(value: float) -> void: machine.target_temperature = value)
	pressure_slider = _setting(controls, "Давление", "бар", 1, 9, 0.5, machine.target_pressure)
	pressure_slider.value_changed.connect(func(value: float) -> void: machine.target_pressure = value)
	speed_slider = _setting(controls, "Скорость", "×", 0.5, 1.8, 0.1, machine.speed)
	speed_slider.value_changed.connect(func(value: float) -> void: machine.speed = value)
	controls.add_child(UIFactory.paragraph("Температура: 130–180 °C\nДавление: 3–6 бар · Скорость: 0.8–1.2×\nРекомендуется: 160 °C / 4 бар / 1.0×", 14))
	failure = UIFactory.paragraph("", 15, UIFactory.AMBER)
	failure.custom_minimum_size.y = 45
	root.add_child(failure)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	root.add_child(buttons)
	for entry: Array in [["START", machine.start_machine], ["STOP", machine.stop_machine], ["RESET", machine.reset_machine]]:
		var button := UIFactory.button(entry[0], entry[1], entry[0] == "START")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
	root.add_child(UIFactory.button("ОТОЙТИ ОТ ПУЛЬТА   /   ESC", func() -> void: closed.emit()))

func _setting(parent: VBoxContainer, title: String, unit: String, minimum: float, maximum: float, step: float, initial: float) -> HSlider:
	var caption := UIFactory.label("%s: %.1f %s" % [title, initial, unit], 17)
	parent.add_child(caption)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size.y = 28
	slider.value_changed.connect(func(value: float) -> void: caption.text = "%s: %.1f %s" % [title, value, unit])
	parent.add_child(slider)
	return slider

func _process(_delta: float) -> void:
	if not is_instance_valid(machine):
		return
	temperature.text = "%03d °C" % machine.temperature
	pressure.text = "%.1f бар" % machine.pressure
	state.text = machine.state_text()
	state.modulate = UIFactory.AMBER if machine.state == FactoryMachine.State.FAULT else Color.WHITE
	progress.value = machine.progress * 100.0
	failure.text = MachineFailure.description(machine.failure) if machine.state == FactoryMachine.State.FAULT else "Питание: %s  ·  Сырьё: %s" % ["ВКЛ" if machine.power else "ВЫКЛ", "загружено" if machine.loaded else "нет"]
