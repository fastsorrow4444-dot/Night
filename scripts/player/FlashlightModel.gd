class_name FlashlightModel
extends Node3D
var render_layer := 2
var lens_material: StandardMaterial3D
var button: Node3D

func _ready() -> void:
	_cylinder(Vector3.ZERO, 0.031, 0.22, Color("2a3334"))
	for i in 12:
		_cylinder(Vector3(0, 0, -0.075 + i * 0.014), 0.033, 0.004, Color("172326"))
	_cylinder(Vector3(0, 0, 0.116), 0.033, 0.018, Color("566467"))
	_cylinder(Vector3(0, 0, -0.118), 0.047, 0.065, Color("485457"))
	_cylinder(Vector3(0, 0, -0.153), 0.050, 0.010, Color("a2aba5"))
	var lens := _cylinder(Vector3(0, 0, -0.160), 0.043, 0.004, Color("c7ccad"))
	lens_material = (lens.material_override as StandardMaterial3D).duplicate()
	lens.material_override = lens_material
	lens_material.emission_enabled = true
	lens_material.emission = Color("ffdca0")
	lens_material.emission_energy_multiplier = 0.0
	button = WorldBuilder.cylinder(self, Vector3(0, 0.036, 0.015), 0.012, 0.006, Color("14191b"))
	WorldBuilder.box(self, Vector3(0.03, 0.004, 0.05), Vector3(0.009, 0.025, 0.12), Color("808b81"), false, 0.8)
	set_render_layer(render_layer)

func _cylinder(pos: Vector3, radius: float, length: float, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = length
	shape.radial_segments = 64
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.42
	material.metallic = 0.65
	mesh.material_override = material
	add_child(mesh)
	mesh.position = pos
	mesh.rotation.x = PI / 2
	return mesh

func set_render_layer(value: int) -> void:
	render_layer = value
	_layers(self)

func _layers(node: Node) -> void:
	if node is MeshInstance3D:
		node.layers = render_layer
		if render_layer == 4:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_layers(child)

func update_switch(lit: bool, press: float) -> void:
	if lens_material != null:
		lens_material.emission_energy_multiplier = 2.0 if lit else 0.0
		button.position.y = 0.036 - press * 0.006
