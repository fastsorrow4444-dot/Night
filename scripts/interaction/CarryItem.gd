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
	shape.size = Vector3(0.32, 0.26, 0.30)
	collider.shape = shape
	add_child(collider)
	var asset := (load("res://assets/player/Cartons.glb") as PackedScene).instantiate()
	var model := asset.find_child("RawBox" if kind == Kind.RAW else "ProductBox", true, false) as Node3D
	ViewArt.clear_owner(model)
	model.reparent(self, false)
	asset.free()
	_apply_paper(model)
	WorldBuilder.text(self, "СЫРЬЁ A" if kind == Kind.RAW else "ПРОДУКТ A", Vector3(0, -0.047, 0.155), 0.025, Color("363b31"))
	add_to_group("carry_items")

func _apply_paper(node: Node) -> void:
	if node is MeshInstance3D and node.name.begins_with("Carton"):
		var material := (node.get_active_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		material.albedo_texture = load("res://assets/player/textures/" + ("cardboard" if kind == Kind.RAW else "coated") + ".png")
		material.albedo_color = Color.WHITE if kind == Kind.RAW else Color("719e91")
		material.roughness = 0.92
		node.material_override = material
	for child: Node in node.get_children():
		_apply_paper(child)

func get_prompt(actor: PlayerController) -> String:
	if is_instance_valid(actor.held_item):
		return "Руки заняты · G — положить предмет"
	return "Взять сырьё" if kind == Kind.RAW else "Взять продукт A"

func interact(actor: PlayerController) -> void:
	actor.pick_up(self)
