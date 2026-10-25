class_name TaskManager
extends RefCounted

static func current(shift: ShiftManager, machine: FactoryMachine, player: PlayerController) -> String:
	if shift.produced >= shift.goal:
		return "Отметьтесь на табельном терминале в раздевалке"
	if is_instance_valid(player.held_item):
		if player.held_item.kind == CarryItem.Kind.RAW:
			return "Загрузите сырьё в жёлтый приёмник машины М-13"
		return "Отнесите продукт на стол упаковки в цехе"
	if machine.state == FactoryMachine.State.FAULT:
		return "Устраните неисправность и нажмите RESET на пульте"
	if machine.state == FactoryMachine.State.READY:
		return "Заберите продукт из зелёного лотка машины"
	if machine.state == FactoryMachine.State.RUNNING:
		return "Дождитесь партии · следите за параметрами на пульте"
	if machine.loaded:
		return "Откройте пульт М-13 и нажмите START"
	return "Возьмите сырьё на складе · указатели 02"
