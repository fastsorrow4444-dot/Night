class_name FirstPersonRig
extends Node3D
## Camera-space forearms with an actual support grip and a sculpted torch grip.
const TORCH_GRIP_OFFSET := Vector3(-0.034, -0.070, -0.060)
var actor: PlayerController
var left_wrist: Node3D
var right_wrist: Node3D
var left_hand: Node3D
var right_hand: Node3D
var thumb: Node3D
var sleeves: Array[MeshInstance3D] = []
var appearance: Dictionary = {}
var carrying := false
var torch_pose := Transform3D.IDENTITY

func _ready() -> void:
	left_wrist = Node3D.new()
	right_wrist = Node3D.new()
	add_child(left_wrist)
	add_child(right_wrist)
	left_hand = ViewArt.hand(false, 4)
	right_hand = ViewArt.hand(true, 4)
	left_wrist.add_child(left_hand)
	right_wrist.add_child(right_hand)
	thumb = right_hand.find_child("RightThumb", true, false)
	var mesh := ViewArt.sleeve_mesh()
	for side in 2:
		var sleeve := MeshInstance3D.new()
		sleeve.mesh = mesh
		sleeve.layers = 4
		sleeve.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sleeve)
		sleeves.append(sleeve)
	apply_appearance(Game.appearance)

func apply_appearance(data: Dictionary) -> void:
	appearance = data.duplicate(true)
	var cloth := "work_canvas" if data.get("top", "work") == "work" else "hoodie"
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/character/textures/" + cloth + ".png")
	material.normal_enabled = true
	material.normal_texture = load("res://assets/character/textures/" + cloth + "_normal.png")
	material.normal_scale = 0.12
	material.roughness = 0.9
	for sleeve: MeshInstance3D in sleeves:
		sleeve.material_override = material

func update_pose(raised: float, press: float) -> void:
	carrying = is_instance_valid(actor.held_item)
	left_wrist.position = actor.hand.position + Vector3(-0.085, -0.148, 0.20)
	left_hand.visible = carrying
	sleeves[0].visible = carrying
	_pose_sleeve(sleeves[0], left_wrist.position, Vector3(-0.43, -0.66, -0.12))
	var belt := actor.to_global(Vector3(0.225, 0.98 - (1.64 - actor.head.position.y) * 0.6, 0.015))
	var belt_world := Transform3D(actor.global_basis * Basis(Vector3.RIGHT, PI / 2), belt)
	var belt_camera := actor.camera.global_transform.affine_inverse() * belt_world
	var held_camera := Transform3D(Basis.IDENTITY, Vector3(0.276, -0.32, -0.56))
	torch_pose = belt_camera.interpolate_with(held_camera, raised)
	right_wrist.transform = torch_pose * Transform3D(Basis.IDENTITY, -TORCH_GRIP_OFFSET)
	right_hand.visible = raised > 0.015
	sleeves[1].visible = right_hand.visible
	thumb.position.y = -press * 0.010
	_pose_sleeve(sleeves[1], right_wrist.position, Vector3(0.48, -0.66, -0.10))

func _pose_sleeve(mesh: MeshInstance3D, wrist: Vector3, elbow: Vector3) -> void:
	var direction := elbow - wrist
	var y := direction.normalized()
	var x := Vector3.FORWARD.cross(y).normalized()
	if x.length_squared() < 0.1:
		x = Vector3.RIGHT
	var z := x.cross(y).normalized()
	mesh.transform = Transform3D(Basis(x, y * direction.length(), z), wrist)

func torch_global_transform() -> Transform3D:
	return global_transform * torch_pose
