class_name ShiftManager
extends Node
signal changed
signal finished

@export var goal := 6
@export var duration := 900.0
var remaining := 900.0
var produced := 0
var mistakes := 0
var active := false

func start() -> void:
	remaining = duration
	produced = 0
	mistakes = 0
	active = true
	changed.emit()

func _process(delta: float) -> void:
	if not active:
		return
	remaining = maxf(remaining - delta, 0.0)
	if remaining <= 0.0:
		finish(true)

func deliver() -> bool:
	if not active or produced >= goal:
		return false
	produced += 1
	changed.emit()
	if produced == goal:
		Game.notify("План выполнен. Отметьтесь на терминале в раздевалке.")
	return true

func record_mistake() -> void:
	if active:
		mistakes += 1
		changed.emit()

func finish(timed_out := false) -> bool:
	if not active:
		return false
	if produced < goal and not timed_out:
		Game.notify("Сначала выполните план: %d / %d коробок." % [produced, goal])
		return false
	active = false
	Game.complete_shift(produced, goal, mistakes, timed_out)
	finished.emit()
	return true

func time_text() -> String:
	var seconds := ceili(remaining)
	return "%02d:%02d" % [seconds / 60, seconds % 60]
