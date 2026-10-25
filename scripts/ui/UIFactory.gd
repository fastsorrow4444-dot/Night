class_name UIFactory
extends RefCounted
const FONT = preload("res://assets/fonts/DejaVuSans.ttf")
const MONO = preload("res://assets/fonts/DejaVuSansMono.ttf")
const BOLD = preload("res://assets/fonts/DejaVuSans-Bold.ttf")
const INK := Color("0e1a1c")
const PANEL := Color("162528")
const PAPER := Color("e2dfcd")
const MUTED := Color("94a69e")
const AMBER := Color("d4b16a")
const GREEN := Color("9cc7a5")

static func full(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func label(words: String, size := 18, color := PAPER, font: Font = FONT) -> Label:
	var item := Label.new()
	item.text = words
	item.add_theme_font_override("font", font)
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

static func paragraph(words: String, size := 18, color := MUTED) -> Label:
	var item := label(words, size, color)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return item

static func style(color := PANEL, border := Color("35463f"), padding := 24) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_border_width_all(1)
	box.border_color = border
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONT
	result.default_font_size = 18
	result.set_color("font_color", "Label", PAPER)
	result.set_stylebox("panel", "PanelContainer", style())
	result.set_stylebox("background", "ProgressBar", style(Color("253932"), Color.TRANSPARENT, 0))
	result.set_stylebox("fill", "ProgressBar", style(AMBER, Color.TRANSPARENT, 0))
	result.set_color("font_color", "OptionButton", PAPER)
	result.set_stylebox("normal", "OptionButton", style(Color("22352e"), Color("4f6455"), 12))
	result.set_stylebox("hover", "OptionButton", style(Color("34493b"), AMBER, 12))
	result.set_stylebox("focus", "OptionButton", style(Color("34493b"), AMBER, 12))
	var slider_track := style(Color("43594a"), Color.TRANSPARENT, 0)
	slider_track.set_border_width_all(0)
	slider_track.content_margin_top = 2
	slider_track.content_margin_bottom = 2
	var slider_fill := slider_track.duplicate() as StyleBoxFlat
	slider_fill.bg_color = AMBER
	result.set_stylebox("slider", "HSlider", slider_track)
	result.set_stylebox("grabber_area", "HSlider", slider_fill)
	result.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	result.set_stylebox("panel", "PopupMenu", style(PANEL, Color("52634f"), 12))
	return result

static func button(words: String, callback: Callable, primary := false) -> Button:
	var item := Button.new()
	item.text = words
	item.custom_minimum_size = Vector2(0, 52)
	item.add_theme_font_override("font", FONT)
	item.add_theme_font_size_override("font_size", 17)
	item.add_theme_stylebox_override("normal", style(AMBER if primary else Color("1a2b29"), AMBER if primary else Color("405449"), 16))
	item.add_theme_stylebox_override("hover", style(Color("e0c183") if primary else Color("344a3d"), AMBER, 16))
	item.add_theme_stylebox_override("pressed", style(Color("a28e5b"), AMBER, 16))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = PAPER
	focus.set_border_width_all(2)
	item.add_theme_stylebox_override("focus", focus)
	item.add_theme_stylebox_override("disabled", style(Color("182522"), Color("293e32"), 16))
	item.add_theme_color_override("font_color", INK if primary else PAPER)
	item.add_theme_color_override("font_hover_color", INK if primary else PAPER)
	item.add_theme_color_override("font_focus_color", INK if primary else PAPER)
	item.add_theme_color_override("font_pressed_color", INK)
	item.add_theme_color_override("font_disabled_color", Color("617567"))
	item.pressed.connect(func() -> void:
		Audio.effect("click", -16.0)
		callback.call())
	return item

static func dim(parent: Control, alpha := 0.82) -> ColorRect:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.04, alpha)
	parent.add_child(shade)
	full(shade)
	return shade

static func centered(parent: Control, width: float, height: float) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -width / 2.0
	panel.offset_right = width / 2.0
	panel.offset_top = -height / 2.0
	panel.offset_bottom = height / 2.0
	return panel

static func column(parent: Node, separation := 14) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	parent.add_child(column)
	return column

static func rule(parent: Node) -> void:
	var line := HSeparator.new()
	var separator := style(Color("3d5043"), Color.TRANSPARENT, 0)
	separator.content_margin_top = 1
	line.add_theme_stylebox_override("separator", separator)
	line.custom_minimum_size.y = 1
	parent.add_child(line)
