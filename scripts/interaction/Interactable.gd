class_name Interactable
extends StaticBody3D
## Universal interaction contract. The ray hits physics, then calls these methods.
signal interacted(actor: PlayerController)
@export var title := "Объект"
@export var action := "Использовать"
@export var enabled := true

func get_prompt(_actor: PlayerController) -> String:
	return action if enabled else ""

func interact(actor: PlayerController) -> void:
	if enabled:
		interacted.emit(actor)

func add_box(size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
