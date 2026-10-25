class_name WorldBuilder
extends RefCounted
## Small construction helpers for original, editable placeholder geometry.
const FONT = preload("res://assets/fonts/DejaVuSans.ttf")
static var materials: Dictionary = {}

static func material(color: Color, metal := 0.0, emission := 0.0) -> StandardMaterial3D:
	var key := "%s/%.2f/%.2f" % [color.to_html(), metal, emission]
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	mat.metallic = metal
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	materials[key] = mat
	return mat

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid := true, metal := 0.0) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.position = pos
	parent.add_child(root)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = material(color, metal)
	root.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
	return root

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius
	cylinder_mesh.height = height
	cylinder_mesh.radial_segments = 12
	mesh.mesh = cylinder_mesh
	mesh.material_override = material(color, 0.4)
	mesh.position = pos
	mesh.rotation = rotation
	parent.add_child(mesh)
	return mesh

static func text(parent: Node3D, words: String, pos: Vector3, height: float, color: Color, rotation := Vector3.ZERO) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.font = FONT
	label.font_size = 64
	label.pixel_size = height / 64.0
	label.modulate = color
	label.outline_modulate = Color(0.03, 0.05, 0.05, 0.65)
	label.outline_size = 3
	label.position = pos
	label.rotation = rotation
	label.no_depth_test = false
	parent.add_child(label)
	return label

static func lamp(parent: Node3D, pos: Vector3, warm := false, energy := 2.0) -> OmniLight3D:
	var color := Color("ffdb9a") if warm else Color("bce1d0")
	box(parent, pos, Vector3(1.5, 0.12, 0.3), Color("263c3a"), false)
	var tube := box(parent, pos + Vector3(0, -0.075, 0), Vector3(1.28, 0.04, 0.15), color, false)
	var tube_material := material(color, 0.0, 2.5).duplicate() as StandardMaterial3D
	(tube.get_child(0) as MeshInstance3D).material_override = tube_material
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, -0.35, 0)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 10.0
	light.omni_attenuation = 1.25
	parent.add_child(light)
	light.set_meta("fixture_material", tube_material)
	return light

static func action_point(parent: Node3D, pos: Vector3, size: Vector3, title: String, action: String, color: Color) -> Interactable:
	var point := Interactable.new()
	point.title = title
	point.action = action
	point.position = pos
	point.add_box(size)
	parent.add_child(point)
	box(point, Vector3.ZERO, size, color, false)
	return point
