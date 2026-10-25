extends Node
const SOUNDS := {
	"click": "res://assets/audio/click.wav",
	"step": "res://assets/audio/step.wav",
	"door": "res://assets/audio/door.wav",
	"success": "res://assets/audio/success.wav",
	"alarm": "res://assets/audio/alarm.wav",
}
var ambience: AudioStreamPlayer
var playback_enabled := true

func _ready() -> void:
	playback_enabled = DisplayServer.get_name() != "headless"
	apply_volume()
	ambience = AudioStreamPlayer.new()
	ambience.stream = looping_hum()
	ambience.volume_db = -19.0
	add_child(ambience)
	if playback_enabled:
		ambience.play()

func looping_hum() -> AudioStreamWAV:
	var stream: AudioStreamWAV = load("res://assets/audio/ambience.wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream

func _exit_tree() -> void:
	if is_instance_valid(ambience):
		ambience.stop()
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			child.stop()

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(Storage.settings.volume), 0.0001)))

func effect(id: String, volume_db := -12.0) -> void:
	if not playback_enabled or not SOUNDS.has(id):
		return
	var voice := AudioStreamPlayer.new()
	voice.stream = load(SOUNDS[id])
	voice.volume_db = volume_db
	voice.pitch_scale = randf_range(0.94, 1.06) if id == "step" else 1.0
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()
