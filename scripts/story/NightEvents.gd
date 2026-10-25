class_name NightEvents
extends Node
## Shift two: phone after the second box, a short blackout, and a persistent journal.
signal reading_requested(title: String, text: String)
const JOURNAL_ID := "missing_operator_13"
var world: FactoryWorld
var enabled := false
var ringing := false
var answered := false
var blackout_started := false
var blackout_active := false
var countdown := -1.0
var blackout_left := 0.0
var lamp_energy: Array[float] = []
var ring_player: AudioStreamPlayer3D
var ambient_energy := 0.52

func _ready() -> void:
	ring_player = AudioStreamPlayer3D.new()
	ring_player.name = "TelephoneRing"
	var stream := load("res://assets/audio/phone.wav") as AudioStreamWAV
	stream = stream.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	ring_player.stream = stream
	ring_player.volume_db = -5
	ring_player.unit_size = 5.0
	ring_player.max_distance = 45.0
	world.phone.add_child(ring_player)
	world.shift_manager.changed.connect(_production_changed)
	world.phone.interacted.connect(answer_phone)
	world.journal.interacted.connect(read_journal)

func start() -> void:
	enabled = Game.shift == 2
	world.journal.visible = enabled
	world.journal.enabled = enabled
	lamp_energy.clear()
	ambient_energy = world.environment.ambient_light_energy
	for lamp: OmniLight3D in world.lamps:
		lamp_energy.append(lamp.light_energy)

func _production_changed() -> void:
	if enabled and world.shift_manager.produced >= 2 and not ringing and not answered:
		ringing = true
		if Audio.playback_enabled:
			ring_player.play()
		Game.notify("Звонит телефон в комнате управления. На проходной сказали, что линия отключена.")

func answer_phone(_actor: PlayerController) -> void:
	if not ringing:
		Game.notify("В трубке только гудок. Ваш звонок очень важен для производства.")
		return
	ringing = false
	answered = true
	ring_player.stop()
	Game.choices["night2_phone"] = "answered"
	countdown = 6.0
	reading_requested.emit("Входящий вызов / номер не определён", "Сначала слышен шум оборудования. Такого же, как за вашей спиной.\n\n«Ты сегодня опять остался один?»\n\nВы спрашиваете, кто говорит. На другом конце щёлкает выключатель. Связь обрывается.\n\nНа столе рядом с телефоном лежит старый журнал смен.")

func read_journal(_actor: PlayerController) -> void:
	if not enabled:
		return
	if not JOURNAL_ID in Game.documents:
		Game.documents.append(JOURNAL_ID)
	reading_requested.emit("Журнал смен / лист 13", "Участок 04. Архивная запись.\n\nОператор: А. Серов.\nСмена №13. План выполнен.\n\n23:47 — отключено освещение. Линия М–13 продолжает работать без питания. Оператор направлен в помещение №13.\n\n07:00 — смена принята. Сотрудник с территории не выходил.\n\nНиже другим почерком:\n«Не отвечай, если из трубки слышно твой цех».\n\nЛист зарегистрирован как производственный брак.")

func _process(delta: float) -> void:
	if not enabled or not world.shift_manager.active:
		return
	if countdown >= 0.0 and not blackout_started:
		countdown -= delta
		if countdown <= 0.0:
			start_blackout()
	# Ignoring the call does not block production or the atmospheric sequence.
	if world.shift_manager.produced >= 4 and not blackout_started and not answered:
		Game.choices["night2_phone"] = "ignored"
		start_blackout()
	if blackout_active:
		blackout_left -= delta
		if blackout_left <= 0.0:
			restore_lights()

func start_blackout() -> void:
	if blackout_started:
		return
	blackout_started = true
	blackout_active = true
	blackout_left = 5.0
	for lamp: OmniLight3D in world.lamps:
		lamp.light_energy = 0.015
		if lamp.has_meta("fixture_material"):
			(lamp.get_meta("fixture_material") as StandardMaterial3D).emission_energy_multiplier = 0.0
	world.environment.ambient_light_energy = 0.055
	Audio.effect("knock", -8.0)
	Game.notify("Освещение участка отключено. М–13 продолжает работать. Фонарик — F.")

func restore_lights() -> void:
	for i in mini(world.lamps.size(), lamp_energy.size()):
		if is_instance_valid(world.lamps[i]):
			world.lamps[i].light_energy = lamp_energy[i]
			if world.lamps[i].has_meta("fixture_material"):
				(world.lamps[i].get_meta("fixture_material") as StandardMaterial3D).emission_energy_multiplier = 2.5
	blackout_active = false
	world.environment.ambient_light_energy = ambient_energy
	Game.choices["night2_blackout"] = true

func stop() -> void:
	ringing = false
	ring_player.stop()
	if blackout_active:
		restore_lights()
	enabled = false
