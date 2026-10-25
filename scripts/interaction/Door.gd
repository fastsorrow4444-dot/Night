class_name FactoryDoor
extends Interactable
@export var locked := false
@export var swing := 105.0
var is_open := false
var pivot: Node3D
var animating := false

func _ready() -> void:
	# The moving leaf carries its own collider; the root is the interaction target.
	pivot = Node3D.new()
	pivot.position.x = -0.85
	add_child(pivot)
	WorldBuilder.box(pivot, Vector3(0.85, 1.12, 0), Vector3(1.7, 2.24, 0.12), Color("3a5350"))
	WorldBuilder.box(pivot, Vector3(0.85, 1.7, 0.072), Vector3(1.32, 0.08, 0.018), Color("bd9a55"), false)
	WorldBuilder.box(pivot, Vector3(1.5, 1.03, 0.13), Vector3(0.18, 0.06, 0.1), Color("d0c5a9"), false)
	WorldBuilder.text(pivot, title, Vector3(0.85, 1.55, 0.075), 0.15, Color("e0e3ce"))
	WorldBuilder.text(pivot, title, Vector3(0.85, 1.55, -0.075), 0.15, Color("e0e3ce"), Vector3(0, PI, 0))
	for x: float in [-0.96, 0.96]:
		WorldBuilder.box(self, Vector3(x, 1.22, 0), Vector3(0.2, 2.44, 0.25), Color("222f2f"))
	WorldBuilder.box(self, Vector3(0, 2.44, 0), Vector3(2.12, 0.18, 0.25), Color("222f2f"))

func get_prompt(_actor: PlayerController) -> String:
	if locked:
		return "Помещение №13 · доступ запрещён"
	return ("Закрыть · " if is_open else "Открыть · ") + title

func interact(_actor: PlayerController) -> void:
	if locked:
		Game.notify("«Любопытство не входит в должностные обязанности».")
		return
	if animating:
		return
	is_open = not is_open
	animating = true
	Audio.effect("door", -9.0)
	var tween := create_tween()
	tween.tween_property(pivot, "rotation:y", deg_to_rad(swing) if is_open else 0.0, 0.55).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(func() -> void: animating = false)
