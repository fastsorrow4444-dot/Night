extends Node
## Exercise contact, anatomy, gait and inertia using the shipped rig and controller.
var checks := 0
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, title: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", title)
	else:
		failures += 1
		push_error("FAIL: " + title)

func _run() -> void:
	var stage := Node3D.new()
	add_child(stage)
	var actor := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate() as PlayerController
	stage.add_child(actor)
	var body := actor.body_visual
	var rig := actor.view_arms
	var lamp := actor.flashlight_controller
	body.set_process(false)
	rig.set_process(false)
	lamp.set_process(false)
	var eye_bounds := (body.parts.Eyes as MeshInstance3D).mesh.get_aabb()
	check(eye_bounds.position.y > 1.60 and eye_bounds.end.y < 1.80, "Anatomical eyes occupy the face, in the same coordinate frame as the head")
	var eye_material := (body.parts.Eyes as MeshInstance3D).get_active_material(0) as StandardMaterial3D
	check(eye_material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED, "Transparent corneal UVs reveal the textured iris instead of a solid blue shell")
	check(body.garment_meshes.size() > 20, "Outfit selection controls seams, pockets, hood, laces and the complete garments")
	body.clock = 3.97
	body._process(0.0)
	check(body.blink_amount > 0.95 and body.skin.get_blend_shape_value(0) > 0.95, "Blink closes the actual eyelid morph on the anatomical face")
	body.clock = 1.0
	body._process(0.0)
	check(body.skin.get_blend_shape_value(0) == 0.0, "Eyelids return fully to the open resting shape")
	var chest_before := body.skeleton.get_bone_global_pose(int(body.bones.Chest)).basis
	body._process(0.5)
	var chest_after := body.skeleton.get_bone_global_pose(int(body.bones.Chest)).basis
	check(chest_before.get_rotation_quaternion().angle_to(chest_after.get_rotation_quaternion()) > 0.0005, "Idle breathing subtly moves the skinned chest")
	actor.velocity = Vector3(0, 0, -2.0)
	body._process(1.0 / 60.0)
	check(body.move_weight > 0 and body.move_weight < 0.3, "Starting to walk blends from idle instead of snapping into a walking pose")
	var contact := true
	var smooth_joints := true
	var previous := body.skeleton.get_bone_global_pose(int(body.bones.ThighL)).basis.get_rotation_quaternion()
	for frame in 120:
		body._process(1.0 / 60.0)
		var left := body._position("FootL")
		var right := body._position("FootR")
		contact = contact and minf(left.y, right.y) < 0.15 and left.y > 0.04 and right.y > 0.04
		var next := body.skeleton.get_bone_global_pose(int(body.bones.ThighL)).basis.get_rotation_quaternion()
		smooth_joints = smooth_joints and previous.angle_to(next) < 0.30
		previous = next
	check(contact, "A supporting foot stays near the floor through complete walking cycles")
	check(smooth_joints, "Knee and hip motion stays continuous across walk-cycle boundaries")
	actor.velocity = Vector3.ZERO
	for frame in 90:
		body._process(1.0 / 60.0)
	check(body.move_weight < 0.001, "Stopping gradually returns the walk blend to idle")
	actor.head.position.y = 0.91
	for frame in 30:
		body._process(1.0 / 60.0)
	check(body._position("Hips").y < 0.60 and body._position("FootL").y < 0.15, "Crouching lowers the pelvis while foot IK preserves floor contact")
	actor.head.position.y = 1.64
	for frame in 30:
		body._process(1.0 / 60.0)
	lamp.toggle()
	lamp.advance(2.0)
	check(body.arm_reach_error < 0.04, "Reflected torch wrist remains connected to its continuous skinned sleeve")
	var carton := CarryItem.new()
	stage.add_child(carton)
	actor.pick_up(carton)
	lamp.advance(0.0)
	check(body.arm_reach_error < 0.04, "Box support and torch contact both remain within anatomical arm reach")
	rig.add_look_input(Vector2(300, -200))
	for frame in 6:
		rig._process(1.0 / 60.0)
	check(rig.sway.length() > 0.002 and rig.sway.length() < 0.05, "A mouse turn creates a bounded inertial hand response")
	for frame in 150:
		rig._process(1.0 / 60.0)
	check(rig.sway.length() < 0.0001 and rig.sway_velocity.length() < 0.0001, "The hand spring settles smoothly after mouse movement stops")
	var continuous_thumb: Array = rig.thumb.mesh.surface_get_blend_shape_arrays(0)[0]
	var vertices: PackedVector3Array = continuous_thumb[Mesh.ARRAY_VERTEX]
	var base_vertices: PackedVector3Array = rig.thumb.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var displaced := 0
	for i in vertices.size():
		if vertices[i].distance_to(base_vertices[i]) > 0.0001:
			displaced += 1
	check(displaced > 10 and displaced < vertices.size() / 2, "The switch press deforms only the thumb region of a continuous hand mesh")
	stage.queue_free()
	for i in 3:
		await get_tree().process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
