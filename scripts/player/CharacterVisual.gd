class_name CharacterVisual
extends Node3D
## Continuous skinned anatomy and garments. Contact IK is layered over a walk cycle.
var actor: PlayerController
var asset: Node3D
var skeleton: Skeleton3D
var parts: Dictionary = {}
var bones: Dictionary = {}
var rest: Dictionary = {}
var garment_meshes: Array[MeshInstance3D] = []
var appearance: Dictionary = {}
var left_grip: Node3D
var right_grip: Node3D
var thumb: MeshInstance3D
var skin: MeshInstance3D
var clock := 0.0
var move_weight := 0.0
var crouch_weight := 0.0
var motion_phase := 0.0
var walk_frames: Array = []
var blink_amount := 0.0
var arm_reach_error := 0.0

func _ready() -> void:
	asset = (load("res://assets/character/Worker.glb") as PackedScene).instantiate()
	add_child(asset)
	skeleton = asset.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		push_error("Worker asset has no skinned skeleton")
		return
	for index in skeleton.get_bone_count():
		var key := skeleton.get_bone_name(index)
		bones[key] = index
		rest[key] = skeleton.get_bone_global_rest(index)
	_collect(asset)
	skin = parts.get("HeadSkin") as MeshInstance3D
	walk_frames = (JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/walk_cycle.json")) as Dictionary).get("frames", [])
	left_grip = ViewArt.hand(false, 2)
	right_grip = ViewArt.hand(true, 2)
	add_child(left_grip)
	add_child(right_grip)
	thumb = right_grip.find_child("RightHand", true, false)
	apply_appearance(Game.appearance)
	update_pose()

func _collect(node: Node) -> void:
	if node is MeshInstance3D:
		node.layers = 2
		parts[str(node.name)] = node
		if (node.get_meta("extras", {}) as Dictionary).has("outfit"):
			garment_meshes.append(node)
	for child: Node in node.get_children():
		_collect(child)

func apply_appearance(data: Dictionary) -> void:
	appearance = data.duplicate(true)
	for mesh: MeshInstance3D in garment_meshes:
		var outfit := str((mesh.get_meta("extras") as Dictionary).outfit)
		if outfit == "cap":
			mesh.visible = bool(data.get("cap", true))
		else:
			var fields := outfit.split("_")
			mesh.visible = str(data.get(fields[0], "work")) == fields[1]

func _process(delta: float) -> void:
	clock += delta
	var speed := 0.0
	var crouching := 0.0
	if is_instance_valid(actor):
		speed = Vector2(actor.velocity.x, actor.velocity.z).length()
		crouching = clampf((1.64 - actor.head.position.y) / 0.73, 0.0, 1.0)
	move_weight = lerpf(move_weight, clampf(speed / 1.7, 0, 1), 1.0 - exp(-delta * 9.0))
	crouch_weight = lerpf(crouch_weight, crouching, 1.0 - exp(-delta * 14.0))
	# One cycle travels 1.4 metres: the pose slows naturally as the player stops.
	motion_phase = fposmod(motion_phase + speed * delta / 1.4, 1.0)
	var blink_time := fposmod(clock + 0.47, 4.6)
	blink_amount = sin(clampf((blink_time - 4.35) / 0.18, 0, 1) * PI) if blink_time > 4.35 and blink_time < 4.53 else 0.0
	update_pose()

func _position(key: String) -> Vector3:
	return skeleton.get_bone_global_pose(int(bones[key])).origin

func _orient(key: String, direction: Vector3) -> void:
	var base: Transform3D = rest[key]
	var desired := Basis(Quaternion(base.basis.y.normalized(), direction.normalized())) * base.basis
	_set_basis(key, desired)

func _set_basis(key: String, desired: Basis) -> void:
	var index := int(bones[key])
	var parent := skeleton.get_bone_parent(index)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var local := parent_basis.inverse() * desired
	skeleton.set_bone_pose_rotation(index, local.orthonormalized().get_rotation_quaternion())

func _walk_direction(key: String, fallback: Vector3) -> Vector3:
	if walk_frames.is_empty():
		return fallback
	var cursor := motion_phase * walk_frames.size()
	var a: Array = walk_frames[int(cursor) % walk_frames.size()][key]
	var b: Array = walk_frames[(int(cursor) + 1) % walk_frames.size()][key]
	var value := Vector3(float(a[0]), float(a[1]), float(a[2])).slerp(Vector3(float(b[0]), float(b[1]), float(b[2])), fmod(cursor, 1.0))
	if is_instance_valid(actor):
		var movement := actor.global_basis.inverse() * Vector3(actor.velocity.x, 0, actor.velocity.z)
		if movement.length() > 0.1:
			value = Basis(Vector3.UP, atan2(-movement.x, -movement.z)) * value
	return fallback.slerp(value, move_weight).normalized()

func update_pose() -> void:
	if skeleton == null:
		return
	skeleton.reset_bone_poses()
	var breath := sin(clock * 1.7)
	var gait := sin(motion_phase * TAU)
	var hips_index := int(bones.Hips)
	var crouch := crouch_weight
	var pelvis_offset := Vector3(gait * 0.012 * move_weight, -crouch * 0.40 + (cos(motion_phase * TAU * 2) - 1.0) * 0.008 * move_weight, crouch * 0.10)
	skeleton.set_bone_pose_position(hips_index, skeleton.get_bone_rest(hips_index).origin + pelvis_offset)
	_set_basis("Hips", Basis(Vector3.FORWARD, gait * 0.025 * move_weight) * (rest.Hips as Transform3D).basis)
	_orient("Spine", Vector3(0, 1, -0.06 - crouch * 0.45 - breath * 0.005))
	_orient("Chest", Vector3(-gait * 0.012 * move_weight, 1, -crouch * 0.30 - breath * 0.006))
	var pitch := actor.head.rotation.x if is_instance_valid(actor) else sin(clock * 0.21) * 0.025
	_set_basis("Head", Basis(Vector3.RIGHT, clampf(pitch * 0.55, -0.65, 0.65)) * (rest.Head as Transform3D).basis)
	for side in 2:
		var suffix := "L" if side == 0 else "R"
		var sign_side := -1.0 if side == 0 else 1.0
		var ankle_rest: Vector3 = (rest["Foot" + suffix] as Transform3D).origin
		var ankle := ankle_rest
		if move_weight > 0.001:
			var phase := fposmod(motion_phase + side * 0.5, 1.0)
			var stride := 0.84 * move_weight
			var foot_z := 0.0
			if phase < 0.60:
				foot_z = lerpf(-stride * 0.5, stride * 0.5, phase / 0.6)
			else:
				var t := (phase - 0.6) / 0.4
				foot_z = lerpf(stride * 0.5, -stride * 0.5, smoothstep(0, 1, t))
				ankle.y += sin(t * PI) * 0.105 * move_weight
			var direction := Vector3.FORWARD
			if is_instance_valid(actor):
				direction = (actor.global_basis.inverse() * Vector3(actor.velocity.x, 0, actor.velocity.z)).normalized()
			ankle += -direction * foot_z
		ankle.x = sign_side * 0.115
		_solve_limb("Thigh" + suffix, "Shin" + suffix, "Foot" + suffix, ankle, Vector3(sign_side * 0.03, 0.02, -1.0))
		_set_basis("Foot" + suffix, (rest["Foot" + suffix] as Transform3D).basis)
		_orient("UpperArm" + suffix, _walk_direction("UpperArm" + suffix, Vector3(sign_side * 0.10, -1, 0.03)))
		_orient("Forearm" + suffix, _walk_direction("Forearm" + suffix, Vector3(sign_side * 0.03, -1, -0.12)))
		# Relaxed finger flexion instead of a rigid open mannequin hand.
		for finger in range(2, 6):
			for segment in range(1, 4):
				var key := "Finger%d_%d%s" % [finger, segment, suffix]
				var index := int(bones[key])
				var finger_basis := skeleton.get_bone_rest(index).basis * Basis(Vector3.RIGHT, 0.15 + segment * 0.035)
				skeleton.set_bone_pose_rotation(index, finger_basis.get_rotation_quaternion())
	var carrying := is_instance_valid(actor) and is_instance_valid(actor.held_item)
	var raised := 0.0
	var press := 0.0
	if is_instance_valid(actor) and is_instance_valid(actor.flashlight_controller):
		raised = actor.flashlight_controller.raise_amount
		press = actor.flashlight_controller.press_amount
	left_grip.visible = carrying
	right_grip.visible = raised > 0.015
	(parts.HandSkinL as MeshInstance3D).visible = not carrying
	(parts.HandSkinR as MeshInstance3D).visible = not right_grip.visible
	ViewArt.press_switch(right_grip, press)
	arm_reach_error = 0.0
	if carrying:
		left_grip.global_transform = actor.view_arms.left_wrist.global_transform
		_contact_arm("L", left_grip.global_position)
	if right_grip.visible:
		right_grip.global_transform = actor.view_arms.right_wrist.global_transform
		_contact_arm("R", right_grip.global_position)
	if skin != null:
		var index := skin.find_blend_shape_by_name("Blink")
		if index >= 0:
			skin.set_blend_shape_value(index, blink_amount)

func _contact_arm(suffix: String, world_target: Vector3) -> void:
	var target := skeleton.to_local(world_target)
	var sign_side := -1.0 if suffix == "L" else 1.0
	_solve_limb("UpperArm" + suffix, "Forearm" + suffix, "Hand" + suffix, target, Vector3(sign_side, -0.5, 0.25))
	arm_reach_error = maxf(arm_reach_error, skeleton.to_global(_position("Hand" + suffix)).distance_to(world_target))

func _solve_limb(upper: String, lower: String, end: String, target: Vector3, hint: Vector3) -> void:
	var start := _position(upper)
	var a := (rest[lower] as Transform3D).origin.distance_to((rest[upper] as Transform3D).origin)
	var b := (rest[end] as Transform3D).origin.distance_to((rest[lower] as Transform3D).origin)
	var delta := target - start
	var distance := clampf(delta.length(), 0.025, a + b - 0.001)
	var axis := delta.normalized()
	var bend := (hint - axis * hint.dot(axis)).normalized()
	var along := (a * a - b * b + distance * distance) / (2.0 * distance)
	var middle := start + axis * along + bend * sqrt(maxf(a * a - along * along, 0.0))
	_orient(upper, middle - start)
	_orient(lower, start + axis * distance - middle)
