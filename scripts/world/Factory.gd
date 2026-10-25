class_name FactoryWorld
extends Node3D
signal console_requested(machine: FactoryMachine)
signal wardrobe_requested(actor: PlayerController)
signal reading_requested(title: String, text: String)
var preview_mode := true
var player: PlayerController
var machine: FactoryMachine
var shift_manager: ShiftManager
var menu_camera: Camera3D
var packing: Interactable
var terminal: Interactable
var supply: Interactable
var breaker: Interactable
var lamps: Array[OmniLight3D] = []
var mirrors: Array[PlanarMirror] = []
var wardrobe: Interactable
var phone: Interactable
var journal: Interactable
var events: NightEvents
var profile: Dictionary
var environment: Environment

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	profile = ShiftDefinition.for_number(Game.shift)
	_build_environment()
	_build_shell()
	_build_furnishings()
	_build_workflow()
	player = preload("res://scenes/player/Player.tscn").instantiate()
	player.position = Vector3(-7.5, 0.08, 9.0)
	player.rotation.y = -PI / 2.0
	add_child(player)
	_build_locker_features()
	events = NightEvents.new()
	events.world = self
	add_child(events)
	events.reading_requested.connect(func(title: String, text: String) -> void: reading_requested.emit(title, text))
	menu_camera = Camera3D.new()
	menu_camera.position = Vector3(4.0, 2.75, 10.6)
	menu_camera.fov = 66.0
	add_child(menu_camera)
	menu_camera.look_at(Vector3(8.3, 1.4, 1.0))
	menu_camera.current = true

func start_work() -> void:
	preview_mode = false
	menu_camera.current = false
	player.camera.current = true
	player.set_active(true)
	shift_manager.start()
	events.start()
	Game.notify("Смена %02d / %s. План — %d коробок. Одежда — шкаф 07, инструкция — Tab." % [Game.shift, profile.title, shift_manager.goal])

func end_work() -> void:
	player.set_active(false)
	machine.stop_machine()
	shift_manager.active = false
	if is_instance_valid(events):
		events.stop()

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111f20")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8ea59c")
	env.ambient_light_energy = 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("314842")
	env.fog_light_energy = 0.5
	env.fog_density = 0.012
	world_env.environment = env
	environment = env
	add_child(world_env)

func _build_shell() -> void:
	var floor_node := WorldBuilder.box(self, Vector3(0, -0.16, 0), Vector3(28.4, 0.32, 24.4), Color("454e47"))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/floor.gdshader")
	(floor_node.get_child(0) as MeshInstance3D).material_override = mat
	WorldBuilder.box(self, Vector3(0, -0.16, -14), Vector3(4, 0.32, 4), Color("343e38"))
	WorldBuilder.box(self, Vector3(0, 4.3, 0), Vector3(28.2, 0.2, 24.2), Color("25332f"))
	for x: float in [-14.0, 14.0]:
		WorldBuilder.box(self, Vector3(x, 2.1, 0), Vector3(0.25, 4.2, 24.2), Color("59675d"))
		WorldBuilder.box(self, Vector3(x - signf(x) * 0.14, 0.55, 0), Vector3(0.03, 1.1, 24), Color("344c42"), false)
	WorldBuilder.box(self, Vector3(0, 2.1, 12), Vector3(28, 4.2, 0.25), Color("59675d"))
	for x: float in [-8.0, 8.0]:
		WorldBuilder.box(self, Vector3(x, 2.1, -12), Vector3(12, 4.2, 0.25), Color("59675d"))
	_divider_x(-2.0, [-7.0, 2.0, 9.0])
	_divider_x(2.0, [-8.0, 5.0])
	for z: float in [-2.0, 6.0]:
		WorldBuilder.box(self, Vector3(-8, 2.1, z), Vector3(12, 4.2, 0.18), Color("56665b"))
	WorldBuilder.box(self, Vector3(8, 2.1, -4), Vector3(12, 4.2, 0.18), Color("56665b"))
	# A real, blocked room at the end of the corridor. No invisible level exits.
	for x: float in [-2.0, 2.0]:
		WorldBuilder.box(self, Vector3(x, 2.1, -14), Vector3(0.2, 4.2, 4), Color("313d37"))
	WorldBuilder.box(self, Vector3(0, 2.1, -16), Vector3(4, 4.2, 0.2), Color("313d37"))
	WorldBuilder.box(self, Vector3(0, 4.3, -14), Vector3(4, 0.2, 4), Color("25332f"))
	for x: float in [-1.55, 1.55]:
		WorldBuilder.box(self, Vector3(x, 2.1, -12), Vector3(0.9, 4.2, 0.2), Color("414f44"))
	WorldBuilder.box(self, Vector3(0, 3.4, -12), Vector3(2.2, 1.6, 0.2), Color("414f44"))
	_door(Vector3(-2, 0, 9), -PI / 2, "РАЗДЕВАЛКА")
	_door(Vector3(-2, 0, 2), -PI / 2, "02 / СКЛАД")
	_door(Vector3(-2, 0, -7), -PI / 2, "ТЕХНИЧЕСКАЯ")
	_door(Vector3(2, 0, 5), PI / 2, "01 / ЦЕХ")
	_door(Vector3(2, 0, -8), PI / 2, "УПРАВЛЕНИЕ")
	_door(Vector3(0, 0, -12), 0, "13", true)
	for z in range(-10, 12, 4):
		WorldBuilder.box(self, Vector3(0, 0.012, z), Vector3(0.06, 0.012, 2.6), Color("b89e5e"), false)
		lamps.append(WorldBuilder.lamp(self, Vector3(0, 3.9, z), z < -5, 1.5))
	for x: float in [-1.68, 1.68]:
		WorldBuilder.cylinder(self, Vector3(x, 3.4, 0), 0.09, 23.5, Color("728178"), Vector3(PI / 2, 0, 0))
	for z in range(-12, 13, 4):
		WorldBuilder.box(self, Vector3(0, 3.9, z), Vector3(27.9, 0.18, 0.22), Color("293d34"), false)
	for pos: Vector3 in [Vector3(7, 3.9, 0), Vector3(11, 3.9, 7), Vector3(-8, 3.9, 9), Vector3(-8, 3.9, 2), Vector3(-8, 3.9, -7), Vector3(8, 3.9, -8)]:
		lamps.append(WorldBuilder.lamp(self, pos, pos.x > 2, 2.5))
	WorldBuilder.text(self, "13 / ДОСТУП ЗАПРЕЩЁН", Vector3(0, 2.9, -11.86), 0.17, Color("c4a778"))
	WorldBuilder.text(self, "01  ПРОИЗВОДСТВО  →", Vector3(1.88, 2.9, 5), 0.16, Color("d9ceb0"), Vector3(0, -PI / 2, 0))
	WorldBuilder.text(self, "←  02  СКЛАД", Vector3(-1.88, 2.9, 2), 0.17, Color("d9ceb0"), Vector3(0, PI / 2, 0))
	WorldBuilder.text(self, "СЕВЕР / ТЕХПРОМ\nПРОИЗВОДСТВЕННЫЙ УЧАСТОК 04", Vector3(8, 3.1, -3.87), 0.22, Color("bdc7ae"))
	WorldBuilder.text(self, "ОБРАБОТКА / М–13", Vector3(8, 0.024, 5.1), 0.3, Color("afa16d"), Vector3(-PI / 2, 0, 0))

func _divider_x(x: float, openings: Array) -> void:
	var previous := -12.0
	for opening: float in openings:
		var length := opening - 1.05 - previous
		WorldBuilder.box(self, Vector3(x, 2.1, previous + length / 2), Vector3(0.18, 4.2, length), Color("526458"))
		WorldBuilder.box(self, Vector3(x, 3.45, opening), Vector3(0.18, 1.5, 2.1), Color("526458"))
		previous = opening + 1.05
	var length := 12.0 - previous
	WorldBuilder.box(self, Vector3(x, 2.1, previous + length / 2), Vector3(0.18, 4.2, length), Color("526458"))

func _door(pos: Vector3, yaw: float, caption: String, locked := false) -> void:
	var door := FactoryDoor.new()
	door.position = pos
	door.rotation.y = yaw
	door.title = caption
	door.locked = locked
	door.swing = -105.0
	add_child(door)

func _build_furnishings() -> void:
	# Locker room: banks of lockers, a wooden bench, safety notice.
	for i in 7:
		var x := -12.8 + i * 0.9
		WorldBuilder.box(self, Vector3(x, 1.1, 6.55), Vector3(0.83, 2.2, 0.75), Color("49635c"))
		WorldBuilder.text(self, "%02d" % (i + 1 if i < 6 else 8), Vector3(x, 1.7, 6.94), 0.11, Color("d5cfaf"))
		WorldBuilder.box(self, Vector3(x + 0.22, 1.15, 6.96), Vector3(0.04, 0.18, 0.04), Color("bdbda7"), false)
	WorldBuilder.box(self, Vector3(-10, 0.55, 9), Vector3(3.6, 0.15, 0.6), Color("997c4c"))
	for x: float in [-11.4, -8.6]:
		WorldBuilder.box(self, Vector3(x, 0.25, 9), Vector3(0.12, 0.5, 0.5), Color("334d40"))
	WorldBuilder.text(self, "ТВОЯ СМЕНА / ИХ БУДУЩЕЕ", Vector3(-11.0, 3.4, 11.84), 0.19, Color("ccba7c"), Vector3(0, PI, 0))
	# Warehouse: shelves with individually modelled boxes.
	for z: float in [-0.8, 4.8]:
		for x: float in [-12.8, -6.2]:
			WorldBuilder.box(self, Vector3(x, 1.5, z), Vector3(0.12, 3.0, 1.2), Color("3b5144"))
		for height: float in [0.35, 1.4, 2.45]:
			WorldBuilder.box(self, Vector3(-9.5, height, z), Vector3(6.8, 0.12, 1.2), Color("778573"))
			for i in 7:
				WorldBuilder.box(self, Vector3(-12.2 + i * 0.85, height + 0.35, z), Vector3(0.68, 0.58, 0.7), Color("958263"))
	WorldBuilder.text(self, "02 / СКЛАД СЫРЬЯ\nБЕЗ НАКЛАДНОЙ НЕ ВЫДАВАТЬ*", Vector3(-8, 3.35, -1.88), 0.2, Color("d3c6a4"))
	# Painted hazard perimeter around the machine.
	for i in 14:
		for z: float in [-1.5, 4.5]:
			var strip := WorldBuilder.box(self, Vector3(4.5 + i * 0.5, 0.012, z), Vector3(0.24, 0.012, 0.35), Color("b8a152"), false)
			strip.rotation.y = 0.4
	for z in range(-2, 4):
		WorldBuilder.box(self, Vector3(12.8, 2.5, z), Vector3(0.08, 0.1, 0.12), Color("8c9d89"), false)
	WorldBuilder.cylinder(self, Vector3(12.9, 2.75, 0), 0.11, 7.0, Color("8c9d89"), Vector3(PI / 2, 0, 0))
	WorldBuilder.box(self, Vector3(4.5, 0.75, 10.8), Vector3(0.7, 1.5, 0.7), Color("936454"))
	WorldBuilder.text(self, "ОГНЕТУШИТЕЛЬ", Vector3(4.5, 1.7, 11.05), 0.11, Color("d8bea2"))
	# Control room: a deliberately offline camera feed, decorative in this MVP.
	WorldBuilder.box(self, Vector3(8.5, 0.65, -10.5), Vector3(5.5, 1.3, 1.4), Color("465d50"))
	for x: float in [6.7, 8.5, 10.3]:
		WorldBuilder.box(self, Vector3(x, 1.8, -10.5), Vector3(1.5, 1.0, 0.28), Color("263e32"))
		WorldBuilder.box(self, Vector3(x, 1.8, -10.34), Vector3(1.32, 0.81, 0.02), Color("152f26"), false)
		WorldBuilder.text(self, "КАМЕРА %02d\nНЕТ СИГНАЛА" % int(x), Vector3(x, 1.8, -10.3), 0.11, Color("7c9d7e"))
	WorldBuilder.text(self, "Наблюдение ведётся.\nДаже когда не ведётся.", Vector3(8, 3.0, -11.83), 0.2, Color("c9bb93"))
	for i in 4:
		WorldBuilder.box(self, Vector3(-13.5 + i * 1.4, 1.5, -10.5), Vector3(1.0, 3.0, 1.4), Color("536454"))
		WorldBuilder.text(self, "ЩР–%d" % (i + 1), Vector3(-13.5 + i * 1.4, 2.4, -9.77), 0.13, Color("d2c79c"))

func _build_workflow() -> void:
	shift_manager = ShiftManager.new()
	shift_manager.name = "ShiftManager"
	shift_manager.goal = int(profile.goal)
	shift_manager.duration = float(profile.duration)
	add_child(shift_manager)
	machine = preload("res://scenes/machines/Machine.tscn").instantiate()
	machine.position = Vector3(8, 0, 1)
	machine.shift_manager = shift_manager
	machine.batch_seconds = float(profile.batch_seconds)
	machine.target_temperature = float(profile.temperature)
	machine.target_pressure = float(profile.pressure)
	add_child(machine)
	machine.panel_requested.connect(func(m: FactoryMachine) -> void: console_requested.emit(m))
	supply = WorldBuilder.action_point(self, Vector3(-5.4, 1.0, 0.6), Vector3(1.2, 1.0, 1.1), "Выдача сырья A", "Взять коробку сырья A", Color("a88e5c"))
	WorldBuilder.text(supply, "СЫРЬЁ A\nE / ВЫДАЧА", Vector3(0, 0.07, 0.57), 0.15, Color("253a2b"))
	supply.interacted.connect(take_raw)
	packing = WorldBuilder.action_point(self, Vector3(9.0, 0.65, 8.8), Vector3(3.8, 1.3, 1.4), "Упаковочный стол", "Упаковать продукт A", Color("697960"))
	WorldBuilder.box(packing, Vector3(0, 0.7, 0), Vector3(4.0, 0.12, 1.6), Color("b5aa7b"), false)
	WorldBuilder.text(packing, "03 / УПАКОВКА", Vector3(0, 0.08, 0.72), 0.22, Color("dfe1bf"))
	WorldBuilder.text(self, "ГОТОВЫЕ ИЗДЕЛИЯ", Vector3(9, 2.6, 11.84), 0.24, Color("c3bea1"), Vector3(0, PI, 0))
	packing.interacted.connect(pack_product)
	terminal = WorldBuilder.action_point(self, Vector3(-4.8, 1.3, 11.7), Vector3(1.3, 1.2, 0.35), "Табельный терминал", "Завершить смену", Color("354f40"))
	terminal.rotation.y = PI
	WorldBuilder.box(terminal, Vector3(0, 0.15, 0.19), Vector3(1.0, 0.68, 0.02), Color("1a3025"), false)
	WorldBuilder.text(terminal, "ТАБЕЛЬ УЧЁТА\nЗАКРЫТЬ СМЕНУ\n[ E ]", Vector3(0, 0.15, 0.21), 0.13, Color("b6c997"))
	terminal.interacted.connect(func(_actor: PlayerController) -> void: shift_manager.finish())
	WorldBuilder.text(self, "ОПЕРАТОРУ\nПЛАН: %d КОРОБОК ПРОДУКТА A\nМ–13: %d °C / %.1f БАР / 1.0×\nПОРЯДОК РАБОТЫ — TAB\n\nПЕРЕРАБОТКИ НЕ СУЩЕСТВУЕТ.\nСУЩЕСТВУЕТ ЛОЯЛЬНОСТЬ." % [profile.goal, profile.temperature, profile.pressure], Vector3(-8.0, 2.3, 11.83), 0.16, Color("dbd1ac"), Vector3(0, PI, 0))
	breaker = WorldBuilder.action_point(self, Vector3(-5.3, 1.5, -11.7), Vector3(0.9, 1.3, 0.35), "Главный рубильник", "Переключить питание М-13", Color("a08b4f"))
	WorldBuilder.text(breaker, "ПИТАНИЕ\nМ–13\n[ E ]", Vector3(0, 0.1, 0.19), 0.14, Color("203a2a"))
	breaker.interacted.connect(func(_actor: PlayerController) -> void:
		machine.set_power(not machine.power)
		Game.notify("Питание М-13 " + ("включено. При аварии нажмите RESET на пульте." if machine.power else "отключено."))
		Audio.effect("click", -5.0))
	phone = WorldBuilder.action_point(self, Vector3(11.0, 1.42, -10.0), Vector3(0.65, 0.22, 0.43), "Служебный телефон", "Поднять трубку", Color("313b36"))
	WorldBuilder.box(phone, Vector3(0, 0.17, 0), Vector3(0.67, 0.10, 0.13), Color("202b27"), false)
	for x: float in [-0.26, 0.26]:
		WorldBuilder.box(phone, Vector3(x, 0.13, 0), Vector3(0.11, 0.16, 0.17), Color("202b27"), false)
	for x in 3:
		for y in 3:
			WorldBuilder.box(phone, Vector3(-0.08 + x * 0.08, 0.12, 0.07 + y * 0.04), Vector3(0.05, 0.012, 0.025), Color("a19a7e"), false)
	journal = WorldBuilder.action_point(self, Vector3(5.95, 1.335, -10.2), Vector3(0.59, 0.035, 0.43), "Архивный журнал смен", "Прочитать лист №13", Color("b8ad85"))
	WorldBuilder.text(journal, "ЖУРНАЛ / 13", Vector3(0, 0.025, 0), 0.055, Color("383d2b"), Vector3(-PI / 2, 0, 0))
	journal.visible = false
	journal.enabled = false

func _build_locker_features() -> void:
	wardrobe = WorldBuilder.action_point(self, Vector3(-4.2, 1.1, 6.65), Vector3(1.15, 2.2, 0.65), "Личный шкаф 07", "Переодеться · рабочая / личная одежда", Color("40585a"))
	WorldBuilder.box(wardrobe, Vector3(0, 0, 0.34), Vector3(0.018, 2.1, 0.025), Color("1b3030"), false)
	WorldBuilder.box(wardrobe, Vector3(0.39, 0.05, 0.36), Vector3(0.04, 0.18, 0.05), Color("aaa68b"), false)
	WorldBuilder.text(wardrobe, "07 / ВАШ ШКАФ", Vector3(0, 0.70, 0.34), 0.11, Color("dfd5b7"))
	wardrobe.interacted.connect(func(actor: PlayerController) -> void: wardrobe_requested.emit(actor))
	for description: Dictionary in [
		{"position": Vector3(-13.78, 1.60, 10.25), "yaw": PI / 2, "size": Vector2(2.4, 2.3)},
		{"position": Vector3(-2.15, 1.65, 10.9), "yaw": -PI / 2, "size": Vector2(0.85, 1.3)},
	]:
		var mirror := PlanarMirror.new()
		mirror.position = description.position
		mirror.rotation.y = float(description.yaw)
		mirror.dimensions = description.size
		mirror.observer = player.camera
		add_child(mirror)
		mirrors.append(mirror)
	lamps.append(WorldBuilder.lamp(self, Vector3(-12.6, 3.6, 10.2), false, 2.0))
	WorldBuilder.text(self, "ПРОВЕРЬТЕ ВНЕШНИЙ ВИД", Vector3(-13.64, 2.97, 10.25), 0.12, Color("c9c4aa"), Vector3(0, PI / 2, 0))

func take_raw(actor: PlayerController) -> void:
	if is_instance_valid(actor.held_item):
		Game.notify("Руки заняты. G — положить предмет.")
		return
	if not shift_manager.active or shift_manager.produced >= shift_manager.goal:
		Game.notify("Производственный план уже закрыт.")
		return
	var item := CarryItem.new()
	item.kind = CarryItem.Kind.RAW
	add_child(item)
	actor.pick_up(item)

func pack_product(actor: PlayerController) -> void:
	if not is_instance_valid(actor.held_item) or actor.held_item.kind != CarryItem.Kind.PRODUCT:
		Game.notify("Нужен готовый продукт из зелёного лотка М-13.")
		return
	if shift_manager.deliver():
		actor.consume_item(CarryItem.Kind.PRODUCT)
		Audio.effect("success", -14.0)
		Game.notify("Упаковано: %d / %d. %s" % [shift_manager.produced, shift_manager.goal,
			"Вернитесь в раздевалку и закройте смену." if shift_manager.produced >= shift_manager.goal else "Следующая партия ждёт."])
