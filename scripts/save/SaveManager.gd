extends Node
## Versioned saves; write to a temporary file before replacing the previous save.
signal save_failed(message: String)

const SAVE_VERSION := 1
var save_path := "user://shift13_save.json"
var settings_path := "user://shift13_settings.cfg"
var last_error := ""
var settings: Dictionary = {
	"volume": 0.7, "sensitivity": 0.0022, "fullscreen": false,
	"resolution": 0, "quality": 1,
}

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		for key: String in settings:
			settings[key] = config.get_value("settings", key, settings[key])
	settings.volume = clampf(float(settings.volume), 0.0, 1.0)
	settings.sensitivity = clampf(float(settings.sensitivity), 0.0005, 0.006)
	settings.resolution = clampi(int(settings.resolution), 0, 2)
	settings.quality = clampi(int(settings.quality), 0, 2)

func write_save(data: Dictionary) -> bool:
	last_error = ""
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return _fail("Не удалось открыть файл сохранения: %s" % error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _fail("Ошибка записи сохранения: %s" % error_string(write_error))
	# Retain the last complete save as a recovery copy.
	if FileAccess.file_exists(save_path):
		var backup_error := DirAccess.copy_absolute(save_path, save_path + ".bak")
		if backup_error != OK:
			return _fail("Не удалось сохранить резервную копию: %s" % error_string(backup_error))
	var result := DirAccess.rename_absolute(save_path + ".tmp", save_path)
	if result != OK:
		return _fail("Не удалось заменить сохранение: %s" % error_string(result))
	return true

func read_save() -> Dictionary:
	last_error = ""
	var data := _read_valid(save_path)
	if not data.is_empty():
		return data
	data = _read_valid(save_path + ".bak")
	if not data.is_empty():
		last_error = "Основной файл повреждён. Загружена резервная копия."
		return data
	if FileAccess.file_exists(save_path):
		last_error = "Сохранение повреждено или создано другой версией игры."
	return {}

func has_save() -> bool:
	return not read_save().is_empty()

func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	if data.get("version", 0) != SAVE_VERSION:
		return {}
	for key: String in ["shift", "money", "upgrades", "choices", "documents"]:
		if not data.has(key):
			return {}
	if not (data.shift is float or data.shift is int) or not (data.money is float or data.money is int):
		return {}
	if not data.upgrades is Array or not data.choices is Dictionary or not data.documents is Array:
		return {}
	data.shift = clampi(int(data.shift), 1, 999)
	data.money = clampi(int(data.money), 0, 999999)
	return data

func save_settings() -> Error:
	var config := ConfigFile.new()
	for key: String in settings:
		config.set_value("settings", key, settings[key])
	return config.save(settings_path)

func _fail(message: String) -> bool:
	last_error = message
	save_failed.emit(message)
	return false
