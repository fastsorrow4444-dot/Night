class_name PlayerInteraction
extends Node
signal prompt_changed(text: String, title: String)
var target: Node
var ray: RayCast3D
var last_prompt := ""
@onready var player: PlayerController = get_parent()

func _ready() -> void:
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.8)
	ray.collision_mask = 1
	ray.add_exception(player)
	player.get_node("Head/Camera3D").add_child.call_deferred(ray)

func _physics_process(_delta: float) -> void:
	if not player.active or not ray.is_inside_tree():
		return
	ray.force_raycast_update()
	target = null
	var collider: Node = ray.get_collider() as Node
	while collider != null:
		if collider.has_method("get_prompt") and collider.has_method("interact"):
			target = collider
			break
		collider = collider.get_parent()
	var prompt := ""
	var title := ""
	if is_instance_valid(target):
		prompt = target.get_prompt(player)
		if target is Interactable:
			title = target.title
		elif target is CarryItem:
			title = "Сырьё A" if target.kind == CarryItem.Kind.RAW else "Продукт A"
	if prompt != last_prompt:
		last_prompt = prompt
		prompt_changed.emit(prompt, title)

func _unhandled_input(event: InputEvent) -> void:
	if player.active and event.is_action_pressed("interact") and not event.is_echo():
		if is_instance_valid(target):
			target.interact(player)
			get_viewport().set_input_as_handled()

func clear_target() -> void:
	target = null
	last_prompt = ""
	prompt_changed.emit("", "")
