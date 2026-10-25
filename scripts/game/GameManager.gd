extends Node
## Persistent campaign data. Shift simulation lives in ShiftManager, not here.
signal notification(message: String)
signal session_started
signal shift_completed(result: Dictionary)

var shift := 1
var money := 0
var upgrades: Array = []
var choices: Dictionary = {}
var documents: Array = []
var last_result: Dictionary = {}
var session_active := false

func new_game() -> void:
	shift = 1
	money = 0
	upgrades.clear()
	choices.clear()
	documents.clear()
	last_result.clear()
	begin_session()

func continue_game() -> bool:
	var data := Storage.read_save()
	if data.is_empty():
		return false
	shift = int(data.shift)
	money = int(data.money)
	upgrades = data.upgrades.duplicate()
	choices = data.choices.duplicate(true)
	documents = data.documents.duplicate()
	last_result = data.get("last_result", {}).duplicate(true)
	begin_session()
	return true

func begin_session() -> void:
	session_active = true
	session_started.emit()

func complete_shift(produced: int, goal: int, mistakes: int, timed_out: bool) -> Dictionary:
	if not session_active:
		return last_result
	session_active = false
	var base := 100 if produced >= goal else 40
	var bonus := 40 if produced >= goal else 0
	var penalty := mini(mistakes * 10, base + bonus)
	var result := {
		"shift": shift, "produced": produced, "goal": goal, "mistakes": mistakes,
		"base": base, "bonus": bonus, "penalty": penalty,
		"total": base + bonus - penalty, "timed_out": timed_out,
	}
	money += int(result.total)
	shift += 1
	last_result = result.duplicate(true)
	result["saved"] = Storage.write_save(serialize())
	shift_completed.emit(result)
	return result

func serialize() -> Dictionary:
	return {"shift": shift, "money": money, "upgrades": upgrades.duplicate(),
		"choices": choices.duplicate(true), "documents": documents.duplicate(),
		"last_result": last_result.duplicate(true)}

func notify(message: String) -> void:
	notification.emit(message)
