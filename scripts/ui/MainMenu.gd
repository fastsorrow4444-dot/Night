extends Control
signal new_requested
signal continue_requested
signal settings_requested
signal exit_requested

func _ready() -> void:
	UIFactory.full(self)
	theme = UIFactory.theme()
	var gradient := ColorRect.new()
	gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/menu_gradient.gdshader")
	gradient.material = material
	add_child(gradient)
	UIFactory.full(gradient)
	var top := UIFactory.label("С / Т     СЕВЕРТЕХПРОМ", 16, UIFactory.PAPER, UIFactory.MONO)
	add_child(top)
	top.position = Vector2(68, 42)
	var status := UIFactory.label("ОБЪЕКТ 04   /   НОЧНАЯ СМЕНА", 14, UIFactory.MUTED, UIFactory.MONO)
	add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status.position += Vector2(-410, 46)
	var column := UIFactory.column(self, 10)
	column.position = Vector2(68, 166)
	column.custom_minimum_size.x = 420
	column.add_child(UIFactory.label("ПРОПУСК ДЕЙСТВИТЕЛЕН ДО УТРА", 12, UIFactory.AMBER, UIFactory.MONO))
	column.add_child(UIFactory.label("СМЕНА", 76, UIFactory.PAPER, UIFactory.BOLD))
	var number := UIFactory.label("№ 13", 112, UIFactory.PAPER, UIFactory.BOLD)
	number.add_theme_constant_override("outline_size", 0)
	column.add_child(number)
	column.add_child(UIFactory.label("Ночная работа. Сдельная реальность.", 17, UIFactory.MUTED))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	column.add_child(spacer)
	var start := UIFactory.button("НАЧАТЬ СМЕНУ                       →", func() -> void: new_requested.emit(), true)
	column.add_child(start)
	var resume := UIFactory.button("ПРОДОЛЖИТЬ", func() -> void: continue_requested.emit())
	resume.disabled = not Storage.has_save()
	resume.tooltip_text = "Продолжение с начала следующей смены. Автосохранение после результатов."
	column.add_child(resume)
	column.add_child(UIFactory.button("НАСТРОЙКИ", func() -> void: settings_requested.emit()))
	column.add_child(UIFactory.button("ВЫХОД", func() -> void: exit_requested.emit()))
	var footer := UIFactory.label("ДВЕ СМЕНЫ  /  0.2\nНаушники рекомендованы. Сверхурочные — нет.", 13, UIFactory.MUTED)
	add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position += Vector2(68, -76)
	var camera_label := UIFactory.label("●  REC     КАМЕРА 01\nПРОИЗВОДСТВЕННЫЙ УЧАСТОК\n23:47:13  /  СИГНАЛ СТАБИЛЕН", 14, UIFactory.MUTED, UIFactory.MONO)
	add_child(camera_label)
	camera_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	camera_label.position += Vector2(-410, -108)
	start.grab_focus()
