class_name ViewArt
extends RefCounted
## Shared close-up hand meshes, used both by the camera and the mirror avatar.
static func hand(right: bool, layers: int) -> Node3D:
	var source := (load("res://assets/player/ViewHands.glb") as PackedScene).instantiate()
	var root := Node3D.new()
	var names: Array = ["RightHand", "RightThumb"] if right else ["LeftHand"]
	for part_name: String in names:
		var part := source.find_child(part_name, true, false) as Node3D
		if part != null:
			clear_owner(part)
			part.reparent(root, false)
	source.free()
	set_layers(root, layers)
	return root

static func clear_owner(node: Node) -> void:
	node.owner = null
	for child: Node in node.get_children():
		clear_owner(child)

static func set_layers(node: Node, layers: int) -> void:
	if node is MeshInstance3D:
		node.layers = layers
		if layers == 4:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		set_layers(child, layers)

static func sleeve_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 32
	const ROWS := 10
	for row in ROWS + 1:
		var t := float(row) / ROWS
		var radius := lerpf(0.028, 0.054, t) + sin(t * 28.0) * 0.0015 * sin(t * PI)
		for column in SEGMENTS + 1:
			var angle := float(column) / SEGMENTS * TAU
			surface.set_normal(Vector3(cos(angle), 0, sin(angle)))
			surface.set_uv(Vector2(float(column) / SEGMENTS * 2.0, t * 3.0))
			surface.add_vertex(Vector3(cos(angle) * radius, t, sin(angle) * radius * 0.88))
	for row in ROWS:
		for column in SEGMENTS:
			var a := row * (SEGMENTS + 1) + column
			var b := a + SEGMENTS + 1
			for index: int in [a, b + 1, b, a, a + 1, b + 1]:
				surface.add_index(index)
	surface.generate_tangents()
	return surface.commit()
