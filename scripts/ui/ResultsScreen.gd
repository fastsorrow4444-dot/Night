extends Control
signal continue_requested
signal menu_requested
var result: Dictionary

func _ready() -> void:
	UIFactory.full(self)
	theme = UIFactory.theme()
	UIFactory.dim(self, 0.9)
	var panel := UIFactory.centered(self, 720, 744)
	panel.add_theme_stylebox_override("panel", UIFactory.style(Color("ded8c1"), Color("a69f85"), 34))
	var column := UIFactory.column(panel, 13)
	column.add_child(UIFactory.label("С / Т    РАСЧЁТНЫЙ ЛИСТОК    №%04d" % int(result.shift), 12, Color("5c6655"), UIFactory.MONO))
	column.add_child(UIFactory.label("СМЕНА %02d" % int(result.shift), 28, UIFactory.INK, UIFactory.BOLD))
	column.add_child(UIFactory.label("ПРИНЯТА." if int(result.produced) >= int(result.goal) else "ЗАВЕРШЕНА.", 50, Color("354b36"), UIFactory.BOLD))
	column.add_child(UIFactory.label("Время вышло. План не закрыт." if bool(result.timed_out) and int(result.produced) < int(result.goal) else "Производство благодарит за отсутствие вопросов.", 15, Color("626953")))
	UIFactory.rule(column)
	_row(column, "Произведено коробок", "%d / %d" % [result.produced, result.goal])
	_row(column, "Базовая оплата", "$%d" % result.base)
	_row(column, "Премия за план", "+ $%d" % result.bonus)
	_row(column, "Ошибки оборудования (%d)" % result.mistakes, "− $%d" % result.penalty)
	UIFactory.rule(column)
	_row(column, "К ВЫПЛАТЕ", "$%d" % result.total, 30)
	_row(column, "На вашем счёте", "$%d" % Game.money)
	var save_message := "✓ Сохранено. Следующая смена — %02d." % Game.shift if bool(result.saved) else "Сохранение не удалось: " + Storage.last_error
	column.add_child(UIFactory.paragraph(save_message, 14, Color("53694c")))
	column.add_child(UIFactory.button("ПРОДОЛЖИТЬ РАБОТУ   →", func() -> void: continue_requested.emit(), true))
	column.add_child(UIFactory.button("В ГЛАВНОЕ МЕНЮ", func() -> void: menu_requested.emit()))
	column.add_child(UIFactory.paragraph("Подготовлены две смены. Во второй: новый план, телефон, сбой освещения и архивный журнал. После неё производство можно повторять.", 12, Color("686c57")))

func _row(parent: VBoxContainer, title: String, value: String, font_size := 17) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var caption := UIFactory.label(title, font_size, UIFactory.INK)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	row.add_child(UIFactory.label(value, font_size, UIFactory.INK, UIFactory.MONO))
