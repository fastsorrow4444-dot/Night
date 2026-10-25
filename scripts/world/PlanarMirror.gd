class_name PlanarMirror
extends Node3D
## A shared-world reflected camera with an off-axis frustum, supported by GL Compatibility.
var dimensions := Vector2(2.4, 2.3)
var observer: Camera3D
var reflection_view: SubViewport
var reflection_camera: Camera3D
var surface: MeshInstance3D
var last_quality := -1
var rendering := false

func _ready() -> void:
	reflection_view = SubViewport.new()
	reflection_view.name = "ReflectionViewport"
	reflection_view.world_3d = get_world_3d()
	reflection_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	reflection_view.gui_disable_input = true
	add_child(reflection_view)
	reflection_camera = Camera3D.new()
	reflection_camera.name = "ReflectedCamera"
	# Exclude first-person arms and every mirror surface: no recursive viewports.
	reflection_camera.cull_mask = 1 | 2 | 8
	reflection_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	reflection_view.add_child(reflection_camera)
	reflection_camera.current = true
	var quad := QuadMesh.new()
	quad.size = dimensions
	surface = MeshInstance3D.new()
	surface.name = "MirrorGlass"
	surface.mesh = quad
	surface.layers = 16
	surface.position.z = 0.015
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/mirror.gdshader")
	mat.set_shader_parameter("reflection_texture", reflection_view.get_texture())
	surface.material_override = mat
	WorldBuilder.box(self, Vector3(0, 0, -0.045), Vector3(dimensions.x + 0.13, dimensions.y + 0.13, 0.09), Color("4e5b58"), true, 0.65)
	for x: float in [-dimensions.x / 2 - 0.025, dimensions.x / 2 + 0.025]:
		WorldBuilder.box(self, Vector3(x, 0, 0.02), Vector3(0.05, dimensions.y + 0.1, 0.055), Color("a59c7e"), false, 0.65)
	for y: float in [-dimensions.y / 2 - 0.025, dimensions.y / 2 + 0.025]:
		WorldBuilder.box(self, Vector3(0, y, 0.02), Vector3(dimensions.x, 0.05, 0.055), Color("a59c7e"), false, 0.65)
	_refresh_quality()

func _refresh_quality() -> void:
	last_quality = int(Storage.settings.quality)
	var height: int = [256, 512, 768][last_quality]
	reflection_view.size = Vector2i(roundi(height * dimensions.x / dimensions.y), height)
	reflection_view.msaa_3d = Viewport.MSAA_DISABLED if last_quality == 0 else Viewport.MSAA_2X

func _process(_delta: float) -> void:
	if last_quality != int(Storage.settings.quality):
		_refresh_quality()
	update_reflection()

func update_reflection() -> void:
	rendering = false
	if not is_instance_valid(observer) or not observer.current:
		reflection_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var normal := global_basis.z.normalized()
	var plane := surface.global_position
	var eye := observer.global_position
	var distance := normal.dot(eye - plane)
	var toward := (plane - eye).normalized()
	if distance < 0.08 or distance > 9.0 or (-observer.global_basis.z).dot(toward) < 0.0:
		reflection_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var reflected_eye := eye - 2.0 * distance * normal
	var right := global_basis.x.normalized()
	var up := global_basis.y.normalized()
	reflection_camera.global_transform = Transform3D(Basis(-right, up, -normal), reflected_eye)
	var center := reflection_camera.to_local(plane)
	# The near plane IS the glass, so objects behind the glass cannot leak into the view.
	reflection_camera.set_frustum(dimensions.y, Vector2(center.x, center.y), distance, 80.0)
	reflection_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	rendering = true
