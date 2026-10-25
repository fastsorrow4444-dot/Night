class_name CharacterVisual
extends Node3D
## Articulated modular GLB. Full body and first-person arms share the same materials.
var actor: PlayerController
var first_person := false
var asset: Node3D
var parts: Dictionary = {}
var spine: Node3D
var pelvis: Node3D
var head_joint: Node3D
var shoulders: Array[Node3D] = []
var elbows: Array[Node3D] = []
var hands: Array[Node3D] = []
var thighs: Array[Node3D] = []
var knees: Array[Node3D] = []
var ankles: Array[Node3D] = []
var thumb: Node3D
var appearance: Dictionary = {}

func _ready() -> void:
	asset = (load("res://assets/character/Worker.glb") as PackedScene).instantiate()
	add_child(asset)
	spine = _pivot(self, Vector3(0, 1.0, 0))
	_attach("TorsoWork", spine)
	_attach("TorsoCasual", spine)
	head_joint = _pivot(spine, Vector3(0, 0.58, 0))
	_attach("Head", head_joint)
	_attach("Cap", head_joint)
	pelvis = _pivot(self, Vector3(0, 0.92, 0))
	_attach("PelvisWork", pelvis)
	_attach("PelvisCasual", pelvis)
	if not first_person:
		var holster := WorldBuilder.box(pelvis, Vector3(0.21, 0.005, 0.015), Vector3(0.055, 0.15, 0.065), Color("40362d"), false)
		_set_mesh_layers(holster, 8)
	for side in 2:
		var suffix := "L" if side == 0 else "R"
		var x := -0.265 if side == 0 else 0.265
		var shoulder := _pivot(spine, Vector3(x, 0.46, 0))
		var elbow := _pivot(shoulder, Vector3(0, -0.29, 0))
		var hand := _pivot(elbow, Vector3(0, -0.255, 0))
		shoulders.append(shoulder)
		elbows.append(elbow)
		hands.append(hand)
		for outfit: String in ["Work", "Casual"]:
			_attach("UpperArm" + outfit + suffix, shoulder)
			_attach("Forearm" + outfit + suffix, elbow)
		_attach("Hand" + suffix, hand)
		_attach("Thumb" + suffix, hand)
		x = -0.101 if side == 0 else 0.101
		var thigh := _pivot(self, Vector3(x, 0.9, 0))
		var knee := _pivot(thigh, Vector3(0, -0.41, 0))
		var ankle := _pivot(knee, Vector3(0, -0.37, 0))
		thighs.append(thigh)
		knees.append(knee)
		ankles.append(ankle)
		for outfit: String in ["Work", "Casual"]:
			_attach("Thigh" + outfit + suffix, thigh)
			_attach("Shin" + outfit + suffix, knee)
			_attach("Boot" + outfit + suffix, ankle)
	thumb = parts["ThumbR"]
	apply_appearance(Game.appearance)

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	node.position = pos
	return node

func _attach(part_name: String, joint: Node3D) -> void:
	var part := asset.find_child(part_name, true, false) as Node3D
	if part == null:
		push_error("Character part missing: " + part_name)
		return
	part.reparent(joint, true)
	parts[part_name] = part
	var lower := part_name.begins_with("Pelvis") or part_name.begins_with("Thigh") or part_name.begins_with("Shin") or part_name.begins_with("Boot")
	_set_mesh_layers(part, 4 if first_person else (8 if lower else 2))

func _set_mesh_layers(node: Node, layers: int) -> void:
	if node is MeshInstance3D:
		node.layers = layers
		if first_person:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_set_mesh_layers(child, layers)

func apply_appearance(data: Dictionary) -> void:
	appearance = data.duplicate(true)
	for key: String in parts:
		var visible_part := true
		if key.contains("Work") or key.contains("Casual"):
			var selected: String = str(data.get("top", "work"))
			if key.begins_with("Pelvis") or key.begins_with("Thigh") or key.begins_with("Shin"):
				selected = str(data.get("bottom", "work"))
			elif key.begins_with("Boot"):
				selected = str(data.get("shoes", "work"))
			visible_part = key.contains("Work") if selected == "work" else key.contains("Casual")
		if key == "Cap":
			visible_part = bool(data.get("cap", true))
		if first_person and not (key.begins_with("UpperArm") or key.begins_with("Forearm") or key.begins_with("Hand") or key.begins_with("Thumb")):
			visible_part = false
		(parts[key] as Node3D).visible = visible_part

func _process(_delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(actor.flashlight_controller):
		return
	var controller := actor.flashlight_controller
	var raised := controller.raise_amount
	var movement := minf(Vector2(actor.velocity.x, actor.velocity.z).length() / actor.walk_speed, 1.4)
	var gait := sin(actor.bob_phase) * movement
	var crouch := clampf((1.64 - actor.head.position.y) / 0.73, 0.0, 1.0) if not first_person else 0.0
	spine.position.y = 1.0 - crouch * 0.44
	spine.rotation.x = -crouch * 0.85
	spine.position.z = -crouch * 0.05
	pelvis.position.y = 0.92 - crouch * 0.40
	head_joint.rotation.x = actor.head.rotation.x - spine.rotation.x
	var aim_pitch := actor.head.rotation.x * 0.8 if not first_person else 0.0
	shoulders[1].rotation.x = (deg_to_rad(65) + aim_pitch) * raised + gait * 0.10 * (1.0 - raised) - spine.rotation.x * raised
	elbows[1].rotation.x = deg_to_rad(30) * raised
	hands[1].rotation.x = -deg_to_rad(80) * raised
	hands[1].rotation.z = -0.08 * raised
	thumb.rotation.z = -controller.press_amount * 0.65
	var carrying := is_instance_valid(actor.held_item)
	shoulders[0].rotation.x = deg_to_rad(58) if carrying else -gait * 0.10
	elbows[0].rotation.x = deg_to_rad(55) if carrying else 0.03
	hands[0].rotation.x = -deg_to_rad(90) if carrying else 0.0
	for side in 2:
		var swing := gait * 0.42 * (-1.0 if side == 0 else 1.0)
		thighs[side].position.y = 0.9 - crouch * 0.40
		thighs[side].rotation.x = swing * (1.0 - crouch) - crouch * 1.08
		knees[side].rotation.x = maxf(-swing, 0.0) * 0.65 + crouch * 2.16
		ankles[side].rotation.x = -crouch * 1.08

func right_hand_position() -> Vector3:
	return hands[1].global_position
