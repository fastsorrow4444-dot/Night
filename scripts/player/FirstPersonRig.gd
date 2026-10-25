class_name FirstPersonRig
extends Node3D
## Camera-space forearms with an actual support grip and a sculpted torch grip.
const TORCH_GRIP_OFFSET := Vector3(-0.034, -0.100, -0.060)
const WRIST_ROLL := -2.2689280276 # -130 degrees: knuckles above the forearm, palm around the barrel.
var actor: PlayerController
var left_wrist: Node3D
var right_wrist: Node3D
var left_hand: Node3D
var right_hand: Node3D
var thumb: MeshInstance3D
var sleeves: Array[MeshInstance3D] = []
var appearance: Dictionary = {}
var carrying := false
var torch_pose := Transform3D.IDENTITY
var motion_clock := 0.0
var movement_blend := 0.0
var look_impulse := Vector2.ZERO
var sway := Vector2.ZERO
var sway_velocity := Vector2.ZERO
var carry_origin := Vector3.ZERO
var motion_offset := Vector3.ZERO
var motion_angles := Vector3.ZERO

func _ready() -> void:
	carry_origin = actor.hand.position
	left_wrist = Node3D.new()
	right_wrist = Node3D.new()
	add_child(left_wrist)
	add_child(right_wrist)
	left_hand = ViewArt.hand(false, 4)
	right_hand = ViewArt.hand(true, 4)
	left_wrist.add_child(left_hand)
	right_wrist.add_child(right_hand)
	thumb = right_hand.find_child("RightHand", true, false)
	var mesh := ViewArt.sleeve_mesh()
	for side in 2:
		var sleeve := MeshInstance3D.new()
		sleeve.mesh = mesh
		sleeve.layers = 4
		sleeve.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sleeve)
		sleeves.append(sleeve)
	apply_appearance(Game.appearance)

func add_look_input(relative: Vector2) -> void:
	look_impulse = (look_impulse + relative * 0.00022).limit_length(0.045)

func _process(delta: float) -> void:
	motion_clock += delta
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	movement_blend = lerpf(movement_blend, minf(speed / actor.walk_speed, 1.4), 1.0 - exp(-delta * 9.0))
	# A critically damped spring, stepped at most 1/120 s, keeps mouse inertia
	# stable across frame rates and settles without a visible snap on stopping.
	var remaining := minf(delta, 0.10)
	while remaining > 0.00001:
		var step := minf(remaining, 1.0 / 120.0)
		sway_velocity += ((look_impulse - sway) * 150.0 - sway_velocity * 23.0) * step
		sway += sway_velocity * step
		look_impulse *= exp(-step * 12.0)
		remaining -= step
	var phase := actor.body_visual.motion_phase * TAU
	motion_offset = Vector3(sin(phase) * 0.004, cos(phase * 2.0) * 0.003, sin(phase * 2.0) * 0.002) * movement_blend
	motion_offset.y += sin(motion_clock * 1.7) * 0.0015
	motion_offset += Vector3(-sway.x, sway.y, 0) * 0.30
	motion_angles = Vector3(sway.y, -sway.x, sin(phase) * 0.010 * movement_blend)
	actor.hand.position = carry_origin + motion_offset * 0.6

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
	left_wrist.transform = actor.hand.transform * Transform3D(Basis.IDENTITY, Vector3(-0.085, -0.148, 0.26))
	left_hand.visible = carrying
	sleeves[0].visible = carrying
	_pose_sleeve(sleeves[0], left_wrist.position, Vector3(-0.43, -0.66, -0.12))
	var belt := actor.to_global(Vector3(0.225, 0.98 - (1.64 - actor.head.position.y) * 0.6, 0.015))
	var belt_world := Transform3D(actor.global_basis * Basis(Vector3.RIGHT, PI / 2), belt)
	var belt_camera := actor.camera.global_transform.affine_inverse() * belt_world
	var held_camera := Transform3D(Basis.from_euler(motion_angles), Vector3(0.276, -0.32, -0.52) + motion_offset)
	torch_pose = belt_camera.interpolate_with(held_camera, raised)
	# Lift clear of the holster, then rotate the wrist into the working grip.
	var arc := sin(raised * PI)
	torch_pose.origin += Vector3(0.035, 0.055, -0.085) * arc
	torch_pose.basis = torch_pose.basis * Basis(Vector3.FORWARD, -arc * 0.14)
	torch_pose.origin.y -= press * 0.0015
	var grip_rotation := Basis(Vector3.BACK, WRIST_ROLL)
	right_wrist.transform = torch_pose * Transform3D(grip_rotation, -(grip_rotation * TORCH_GRIP_OFFSET))
	right_hand.visible = raised > 0.015
	sleeves[1].visible = right_hand.visible
	ViewArt.press_switch(right_hand, press)
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
