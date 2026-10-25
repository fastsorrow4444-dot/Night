class_name MachineFailure
extends RefCounted
enum Kind { NONE, OVERHEAT, PRESSURE, JAM, POWER, SENSOR }

static func description(kind: Kind) -> String:
	match kind:
		Kind.OVERHEAT: return "ПЕРЕГРЕВ · установите 130–180 °C, затем RESET"
		Kind.PRESSURE: return "ДАВЛЕНИЕ · установите 3–6 бар, затем RESET"
		Kind.JAM: return "ЗАКЛИНИВАНИЕ · скорость 0.8–1.2×, затем RESET"
		Kind.POWER: return "НЕТ ПИТАНИЯ · включите рубильник в технической"
		Kind.SENSOR: return "ДАТЧИК · остановите машину и нажмите RESET"
	return "Нет неисправностей"

static func detect(temperature: float, pressure: float, speed: float, power: bool) -> Kind:
	if not power: return Kind.POWER
	if temperature < 130.0 or temperature > 180.0: return Kind.OVERHEAT
	if pressure < 3.0 or pressure > 6.0: return Kind.PRESSURE
	if speed < 0.8 or speed > 1.2: return Kind.JAM
	return Kind.NONE
