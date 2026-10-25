class_name FactoryMachine
extends Node3D
signal changed
signal panel_requested(machine: FactoryMachine)
enum State { IDLE, RUNNING, STOPPED, FAULT, READY }

@export var batch_seconds := 12.0
var state := State.IDLE
var loaded := false
var power := true
var temperature := 22.0
var pressure := 0.0
var target_temperature := 160.0
var target_pressure := 4.0
var speed := 1.0
var progress := 0.0
var unsafe_seconds := 0.0
var failure := MachineFailure.Kind.NONE
var shift_manager: ShiftManager
var status_label: Label3D
var status_light: OmniLight3D
var rotor: MeshInstance3D
var sound: AudioStreamPlayer3D

func _ready() -> void:
	_build_model()
	_refresh_display()

func _build_model() -> void:
	WorldBuilder.box(self, Vector3(0, 0.14, 0), Vector3(4.4, 0.28, 3.1), Color("263734"))
	WorldBuilder.box(self, Vector3(0, 1.17, 0), Vector3(3.8, 1.95, 2.55), Color("47615b"), true, 0.4)
	WorldBuilder.box(self, Vector3(0, 2.3, -0.35), Vector3(3.5, 0.38, 2.0), Color("344742"))
	for x: float in [-1.5, 1.5]:
		WorldBuilder.box(self, Vector3(x, 1.25, 1.3), Vector3(0.12, 1.65, 0.08), Color("233d37"), false)
	WorldBuilder.box(self, Vector3(0, 1.6, 1.31), Vector3(2.2, 0.55, 0.08), Color("162824"), false)
	WorldBuilder.text(self, "М–13", Vector3(-0.9, 2.32, 0.68), 0.3, Color("e1cf9a"))
	WorldBuilder.text(self, "СЕВЕР / ТЕХПРОМ", Vector3(0.6, 2.34, 0.68), 0.09, Color("9aaea0"))
	for i in 10:
		WorldBuilder.box(self, Vector3(-1.2 + i * 0.27, 0.58, 1.3), Vector3(0.16, 0.3, 0.025), Color("20342e"), false)
	WorldBuilder.cylinder(self, Vector3(0, 2.8, -0.5), 0.32, 0.8, Color("7c8680"))
	WorldBuilder.cylinder(self, Vector3(0.4, 3.19, -0.5), 0.32, 0.85, Color("7c8680"), Vector3(0, 0, PI / 2))
	rotor = WorldBuilder.cylinder(self, Vector3(0, 1.59, 1.4), 0.22, 0.09, Color("c99f57"), Vector3(PI / 2, 0, 0))
	WorldBuilder.box(rotor, Vector3(0, 0.06, 0), Vector3(0.34, 0.03, 0.06), Color("283a32"), false)
	var hopper := WorldBuilder.action_point(self, Vector3(-2.65, 0.95, 1.0), Vector3(1.1, 1.1, 1.3), "Приёмник сырья", "Загрузить сырьё A", Color("b38c46"))
	WorldBuilder.text(hopper, "01 / СЫРЬЁ", Vector3(0, 0.15, 0.66), 0.12, Color("212e28"))
	hopper.interacted.connect(load_raw)
	var panel := WorldBuilder.action_point(self, Vector3(2.65, 1.22, 1.05), Vector3(1.15, 1.1, 0.45), "Пульт М-13", "Открыть пульт управления", Color("3a4c44"))
	WorldBuilder.box(panel, Vector3(0, 0.18, 0.24), Vector3(0.95, 0.52, 0.018), Color("13261f"), false)
	status_label = WorldBuilder.text(panel, "", Vector3(0, 0.19, 0.256), 0.085, Color("9ed7ac"))
	for i in 3:
		WorldBuilder.cylinder(panel, Vector3(-0.3 + i * 0.3, -0.28, 0.25), 0.065, 0.04, [Color("7ca477"), Color("ae6455"), Color("c4ad70")][i], Vector3(PI / 2, 0, 0))
	panel.interacted.connect(func(_actor: PlayerController) -> void: panel_requested.emit(self))
	WorldBuilder.box(self, Vector3(0, 0.56, 2.2), Vector3(1.45, 0.12, 1.6), Color("69766b"))
	for i in 7:
		WorldBuilder.cylinder(self, Vector3(0, 0.66, 1.55 + i * 0.2), 0.055, 1.35, Color("9ca394"), Vector3(0, 0, PI / 2))
	var output := WorldBuilder.action_point(self, Vector3(0, 0.8, 2.45), Vector3(1.25, 0.3, 0.8), "Выходной лоток", "Забрать готовый продукт", Color("436a53"))
	WorldBuilder.text(output, "02 / ПРОДУКТ", Vector3(0, -0.1, 0.42), 0.1, Color("d1dec4"))
	output.interacted.connect(take_product)
	status_light = OmniLight3D.new()
	status_light.position = Vector3(1.65, 2.5, 1.0)
	status_light.omni_range = 2.8
	status_light.light_energy = 0.7
	add_child(status_light)
	sound = AudioStreamPlayer3D.new()
	sound.stream = Audio.looping_hum()
	sound.pitch_scale = 1.45
	sound.volume_db = -9.0
	sound.unit_size = 3.0
	sound.max_distance = 18.0
	add_child(sound)

func _exit_tree() -> void:
	if is_instance_valid(sound):
		sound.stop()

func _process(delta: float) -> void:
	if state == State.RUNNING:
		rotor.rotate_y(delta * 5.0 * speed)
		advance(delta)
	else:
		temperature = move_toward(temperature, 22.0, delta * 4.0)
		pressure = move_toward(pressure, 0.0, delta * 0.4)

func advance(delta: float) -> void:
	if state != State.RUNNING:
		return
	temperature = move_toward(temperature, target_temperature, delta * 45.0)
	pressure = move_toward(pressure, target_pressure, delta * 2.0)
	var detected := MachineFailure.detect(target_temperature, target_pressure, speed, power)
	if detected != MachineFailure.Kind.NONE:
		unsafe_seconds += delta
		if unsafe_seconds >= 2.0 or detected == MachineFailure.Kind.POWER:
			trigger_failure(detected)
		return
	unsafe_seconds = 0.0
	progress = minf(progress + delta * speed / batch_seconds, 1.0)
	if progress >= 1.0:
		state = State.READY
		loaded = false
		sound.stop()
		Audio.effect("success", -10.0)
		Game.notify("М-13: партия готова. Заберите продукт из зелёного лотка.")
	_refresh_display()

func load_raw(actor: PlayerController) -> void:
	if shift_manager != null and (not shift_manager.active or shift_manager.produced >= shift_manager.goal):
		Game.notify("План уже закрыт. Вернитесь к табельному терминалу.")
		return
	if loaded or state in [State.RUNNING, State.READY, State.FAULT]:
		Game.notify("Приёмник занят. Сначала завершите текущую партию.")
		return
	if not actor.consume_item(CarryItem.Kind.RAW):
		Game.notify("Нужно сырьё A. Возьмите коробку на складе.")
		return
	loaded = true
	progress = 0.0
	state = State.IDLE
	var recipe := ShiftDefinition.for_number(Game.shift)
	Game.notify("Сырьё загружено. Пульт справа: %d °C / %.1f бар / 1.0× / START." % [recipe.temperature, recipe.pressure])
	_refresh_display()

func start_machine() -> bool:
	if not loaded:
		Game.notify("Сначала загрузите сырьё в жёлтый приёмник.")
		return false
	if state == State.FAULT:
		Game.notify("Устраните причину неисправности и нажмите RESET.")
		return false
	if not power:
		trigger_failure(MachineFailure.Kind.POWER)
		return false
	if state == State.RUNNING:
		return true
	state = State.RUNNING
	unsafe_seconds = 0.0
	if Audio.playback_enabled:
		sound.play()
	_refresh_display()
	return true

func stop_machine() -> void:
	if state == State.RUNNING:
		state = State.STOPPED
	sound.stop()
	_refresh_display()

func reset_machine() -> bool:
	if state == State.RUNNING:
		Game.notify("Перед RESET нажмите STOP.")
		return false
	var detected := MachineFailure.detect(target_temperature, target_pressure, speed, power)
	if detected != MachineFailure.Kind.NONE:
		Game.notify(MachineFailure.description(detected))
		return false
	if state == State.READY:
		Game.notify("Заберите готовый продукт перед сбросом.")
		return false
	failure = MachineFailure.Kind.NONE
	state = State.IDLE
	unsafe_seconds = 0.0
	Game.notify("М-13: неисправность устранена. Сырьё и прогресс сохранены.")
	_refresh_display()
	return true

func trigger_failure(kind: MachineFailure.Kind) -> void:
	if state == State.FAULT:
		return
	failure = kind
	state = State.FAULT
	sound.stop()
	if shift_manager != null:
		shift_manager.record_mistake()
	Audio.effect("alarm", -12.0)
	Game.notify(MachineFailure.description(failure))
	_refresh_display()

func set_power(value: bool) -> void:
	power = value
	if not power and state == State.RUNNING:
		trigger_failure(MachineFailure.Kind.POWER)
	_refresh_display()

func take_product(actor: PlayerController) -> void:
	if state != State.READY:
		Game.notify("Лоток пуст. Запустите производство и дождитесь партии.")
		return
	if is_instance_valid(actor.held_item):
		Game.notify("Освободите руки: G — положить предмет.")
		return
	var item := CarryItem.new()
	item.kind = CarryItem.Kind.PRODUCT
	actor.world_parent.add_child(item)
	if actor.pick_up(item):
		state = State.IDLE
		progress = 0.0
		_refresh_display()
	else:
		item.queue_free()

func state_text() -> String:
	match state:
		State.RUNNING: return "ПРОИЗВОДСТВО"
		State.STOPPED: return "ПАУЗА"
		State.FAULT: return "АВАРИЯ"
		State.READY: return "ПАРТИЯ ГОТОВА"
	return "СЫРЬЁ ЗАГРУЖЕНО" if loaded else "ОЖИДАНИЕ СЫРЬЯ"

func _refresh_display() -> void:
	if status_label != null:
		status_label.text = "%s\n%03d °C  /  %.1f БАР" % [state_text(), temperature, pressure]
		status_light.light_color = Color("e58b62") if state == State.FAULT else Color("91c89a")
	changed.emit()
