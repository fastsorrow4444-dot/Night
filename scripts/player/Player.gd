class_name PlayerController
extends CharacterBody3D
signal held_changed

@export var walk_speed := 2.25
@export var sprint_speed := 4.2
@export var crouch_speed := 1.2
var active := false
var held_item: CarryItem
var world_parent: Node3D
var footstep_distance := 0.0
var bob_phase := 0.0
var body_visual: CharacterVisual
var view_arms: FirstPersonRig
var flashlight_controller: FlashlightController

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var hand: Marker3D = $Head/Camera3D/Hand
@onready var torch: SpotLight3D = $Head/Camera3D/Flashlight
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var interaction: PlayerInteraction = $Interaction

func _ready() -> void:
	body_shape.shape = body_shape.shape.duplicate()
	world_parent = get_parent()
	# Full avatar belongs to mirror cameras; the gameplay camera uses a fitted hand rig.
	camera.cull_mask = 1 | 4 | 16
	body_visual = CharacterVisual.new()
	body_visual.name = "BodyVisual"
	body_visual.actor = self
	add_child(body_visual)
	view_arms = FirstPersonRig.new()
	view_arms.name = "FirstPersonArms"
	view_arms.actor = self
	camera.add_child(view_arms)
	flashlight_controller = FlashlightController.new()
	flashlight_controller.name = "FlashlightController"
	add_child(flashlight_controller)
	held_changed.connect(_refresh_hand_pose)

func set_active(value: bool) -> void:
	active = value
	velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if active else Input.MOUSE_MODE_VISIBLE
	if not active:
		interaction.clear_target()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		view_arms.add_look_input(event.relative)
		rotate_y(-event.relative.x * float(Storage.settings.sensitivity))
		head.rotation.x = clampf(head.rotation.x - event.relative.y * float(Storage.settings.sensitivity), -1.45, 1.45)
	if event.is_action_pressed("flashlight"):
		flashlight_controller.toggle()
	if event.is_action_pressed("drop_item"):
		drop_item()

func _physics_process(delta: float) -> void:
	if not active:
		return
	var crouching := Input.is_action_pressed("crouch")
	if not crouching and (body_shape.shape as CapsuleShape3D).height < 1.7:
		crouching = not _can_stand()
	var height := 1.05 if crouching else 1.78
	(body_shape.shape as CapsuleShape3D).height = height
	body_shape.position.y = height * 0.5
	head.position.y = move_toward(head.position.y, height - 0.14, delta * 4.0)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := crouch_speed if crouching else (sprint_speed if Input.is_action_pressed("sprint") else walk_speed)
	if is_instance_valid(held_item):
		speed *= 0.88
	velocity.x = move_toward(velocity.x, direction.x * speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 18.0 * delta)
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = -0.2
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and moving > 0.2:
		footstep_distance += moving * delta
		bob_phase += delta * moving * TAU / 1.4
		if footstep_distance > (0.45 if crouching else 0.70):
			footstep_distance = 0.0
			Audio.effect("step", -23.0 if crouching else -15.0)
	# Soft head motion; weapon/hand inertia is independent of camera rotation.
	camera.position.y = lerpf(camera.position.y, (cos(bob_phase * 2.0) - 1.0) * 0.004 * minf(moving, 1.0), 1.0 - exp(-delta * 14.0))
	camera.fov = lerpf(camera.fov, 82.0 if speed > walk_speed else 78.0, delta * 6.0)

func apply_appearance(data: Dictionary) -> void:
	body_visual.apply_appearance(data)
	view_arms.apply_appearance(data)
	_refresh_hand_pose()

func _refresh_hand_pose() -> void:
	if is_instance_valid(flashlight_controller):
		flashlight_controller.advance(0.0)

func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.76
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.91, 0))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func pick_up(item: CarryItem) -> bool:
	if is_instance_valid(held_item):
		Game.notify("Руки заняты. G — положить предмет.")
		return false
	held_item = item
	item.held = true
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	item.reparent(hand)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
	held_changed.emit()
	Audio.effect("click", -16.0)
	return true

func consume_item(kind: CarryItem.Kind) -> bool:
	if not is_instance_valid(held_item) or held_item.kind != kind:
		return false
	held_item.queue_free()
	held_item = null
	held_changed.emit()
	return true

func drop_item() -> bool:
	if not is_instance_valid(held_item):
		return false
	var from := camera.global_position
	var to := from - camera.global_basis.z * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		Game.notify("Отойдите от стены, чтобы положить предмет.")
		return false
	var item := held_item
	held_item = null
	item.reparent(world_parent)
	item.global_position = to - Vector3(0, 0.2, 0)
	item.held = false
	item.collision_layer = 1
	item.collision_mask = 3
	item.freeze = false
	held_changed.emit()
	return true
