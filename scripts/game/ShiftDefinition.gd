class_name ShiftDefinition
extends RefCounted

static func for_number(number: int) -> Dictionary:
	if number <= 1:
		return {"title": "Вводная смена", "goal": 6, "duration": 900.0,
			"batch_seconds": 12.0, "temperature": 160.0, "pressure": 4.0}
	return {"title": "В журнале вас нет", "goal": 8, "duration": 1050.0,
		"batch_seconds": 10.0, "temperature": 170.0, "pressure": 4.5}
