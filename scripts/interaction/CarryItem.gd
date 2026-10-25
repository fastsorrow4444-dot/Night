class_name CarryItem
extends RigidBody3D
enum Kind { RAW, PRODUCT }
@export var kind := Kind.RAW
var held := false

func _ready() -> void:
	mass = 2.0
	continuous_cd = true
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.42, 0.36, 0.42)
	collider.shape = shape
	add_child(collider)
	var color := Color("b29469") if kind == Kind.RAW else Color("588c82")
	WorldBuilder.box(self, Vector3.ZERO, shape.size, color, false)
	WorldBuilder.box(self, Vector3(0, 0.184, 0), Vector3(0.09, 0.008, 0.42), Color("d5c4a0"), false)
	WorldBuilder.text(self, "СЫРЬЁ A" if kind == Kind.RAW else "ПРОДУКТ A", Vector3(0, 0, 0.216), 0.065, Color("203735"))
	add_to_group("carry_items")

func get_prompt(actor: PlayerController) -> String:
	if is_instance_valid(actor.held_item):
		return "Руки заняты · G — положить предмет"
	return "Взять сырьё" if kind == Kind.RAW else "Взять продукт A"

func interact(actor: PlayerController) -> void:
	actor.pick_up(self)
