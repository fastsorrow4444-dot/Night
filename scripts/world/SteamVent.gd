class_name SteamVent
extends CPUParticles3D

func _ready() -> void:
	amount = 12
	lifetime = 2.8
	emitting = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	direction = Vector3.UP
	spread = 18
	gravity = Vector3(0,0.08,0)
	initial_velocity_min = 0.14
	initial_velocity_max = 0.30
	scale_amount_min = 0.12
	scale_amount_max = 0.30
	emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 0.06
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1,1,1,0.25),Color(1,1,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1.0,0.5)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	material.albedo_color = Color(0.65,0.7,0.72,0.25)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material
	mesh = quad
