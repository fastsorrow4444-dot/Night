extends Control
var world: FactoryWorld
var task: Label
var count: Label
var clock: Label
var prompt: Label
var object_title: Label
var held: Label
var crosshair: Control
var progress: ProgressBar
var toast: PanelContainer
var toast_text: Label
var toast_seconds := 0.0
var tasks_panel: PanelContainer

func _ready() -> void:
	UIFactory.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIFactory.theme()
	var header := UIFactory.column(self, 8)
	header.position = Vector2(38, 30)
	header.custom_minimum_size.x = 620
	header.add_child(UIFactory.label("С / Т   |   СМЕНА %02d   ·   ОПЕРАТОР", 13, UIFactory.AMBER, UIFactory.MONO))
	(header.get_child(0) as Label).text = "С / Т   |   СМЕНА %02d   ·   ОПЕРАТОР" % Game.shift
	task = UIFactory.paragraph("", 18, UIFactory.PAPER)
	header.add_child(task)
	var timer_box := UIFactory.column(self, 5)
	timer_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	timer_box.position += Vector2(-255, 30)
	timer_box.add_child(UIFactory.label("ДО КОНЦА СМЕНЫ", 12, UIFactory.MUTED, UIFactory.MONO))
	clock = UIFactory.label("15:00", 38, UIFactory.PAPER, UIFactory.MONO)
	timer_box.add_child(clock)
	var production := UIFactory.column(self, 6)
	production.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	production.position += Vector2(38, -150)
	production.custom_minimum_size.x = 260
	production.add_child(UIFactory.label("ПРОДУКТ A / КОРОБОК", 12, UIFactory.MUTED, UIFactory.MONO))
	count = UIFactory.label("00 / 06", 40, UIFactory.PAPER, UIFactory.MONO)
	production.add_child(count)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 4
	progress.show_percentage = false
	production.add_child(progress)
	held = UIFactory.label("Руки свободны", 13, UIFactory.MUTED)
	production.add_child(held)
	var controls := UIFactory.label("[ F ]  ФОНАРЬ\n[ TAB ]  ПАМЯТКА\n[ ESC ]  ПАУЗА", 13, UIFactory.MUTED, UIFactory.MONO)
	add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	controls.position += Vector2(-225, -112)
	crosshair = Control.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.draw.connect(func() -> void:
		crosshair.draw_circle(Vector2.ZERO, 3.2, Color(0.02, 0.04, 0.03, 0.85))
		crosshair.draw_circle(Vector2.ZERO, 1.7, UIFactory.PAPER))
	var interaction := UIFactory.column(self, 4)
	interaction.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	interaction.position += Vector2(-340, 90)
	interaction.custom_minimum_size.x = 680
	object_title = UIFactory.label("", 12, UIFactory.AMBER, UIFactory.MONO)
	object_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction.add_child(object_title)
	prompt = UIFactory.label("", 17)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction.add_child(prompt)
	toast = PanelContainer.new()
	add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.offset_left = -400
	toast.offset_right = 400
	toast.offset_top = -100
	toast.offset_bottom = -35
	toast.add_theme_stylebox_override("panel", UIFactory.style(Color(0.06, 0.1, 0.08, 0.96), Color("7c8055"), 16))
	toast_text = UIFactory.paragraph("", 16, UIFactory.PAPER)
	toast_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_child(toast_text)
	toast.hide()
	_build_tasks()
	world.player.interaction.prompt_changed.connect(_prompt_changed)
	Game.notification.connect(notify)

func _process(delta: float) -> void:
	if not is_instance_valid(world):
		return
	clock.text = world.shift_manager.time_text()
	clock.modulate = UIFactory.AMBER if world.shift_manager.remaining < 120 else Color.WHITE
	count.text = "%02d / %02d" % [world.shift_manager.produced, world.shift_manager.goal]
	progress.value = float(world.shift_manager.produced) / world.shift_manager.goal * 100.0
	task.text = TaskManager.current(world.shift_manager, world.machine, world.player)
	var item := world.player.held_item
	held.text = ("Сырьё A" if item.kind == CarryItem.Kind.RAW else "Продукт A") + "   [ G ] положить" if is_instance_valid(item) else "Руки свободны"
	toast_seconds = maxf(toast_seconds - delta, 0.0)
	toast.visible = toast_seconds > 0.0

func _prompt_changed(text: String, title: String) -> void:
	prompt.text = "[ E ]  " + text if not text.is_empty() else ""
	object_title.text = title.to_upper()
	crosshair.modulate = UIFactory.AMBER if not text.is_empty() else Color.WHITE

func notify(text: String) -> void:
	toast_text.text = text
	toast_seconds = 6.0
	toast.show()

func toggle_tasks() -> void:
	tasks_panel.visible = not tasks_panel.visible

func _build_tasks() -> void:
	tasks_panel = PanelContainer.new()
	add_child(tasks_panel)
	tasks_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	tasks_panel.offset_left = -495
	tasks_panel.offset_right = -30
	tasks_panel.offset_top = -270
	tasks_panel.offset_bottom = 270
	var column := UIFactory.column(tasks_panel, 16)
	column.add_child(UIFactory.label("ПАМЯТКА ОПЕРАТОРА", 13, UIFactory.AMBER, UIFactory.MONO))
	column.add_child(UIFactory.label("Не усложняйте работу", 24, UIFactory.PAPER, UIFactory.BOLD))
	UIFactory.rule(column)
	column.add_child(UIFactory.paragraph("01   СКЛАД\nВозьмите сырьё A с выдачи.\n\n02   ЦЕХ / М–13\nЗагрузите жёлтый приёмник. На пульте:\n%d °C · %.1f бар · 1.0× → START.\n\n03   ВЫХОДНОЙ ЛОТОК\nЧерез %d секунд заберите продукт.\n\n04   УПАКОВКА\nОтнесите продукт на стол в цехе.\nПовторите, пока не будет %d коробок.\n\n05   РАЗДЕВАЛКА\nЗакройте смену на табельном терминале." % [world.profile.temperature, world.profile.pressure, world.profile.batch_seconds, world.shift_manager.goal], 16, UIFactory.PAPER))
	column.add_child(UIFactory.paragraph("Авария: исправьте параметры → RESET.\nНет питания: рубильник в технической.\n\nWASD — идти · Shift — бег · Ctrl — присесть\nМышь — обзор · E — действие · G — положить", 13))
	tasks_panel.hide()
