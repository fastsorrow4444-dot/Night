class_name BeveledBox
extends RefCounted
static var cache: Dictionary = {}

static func create(size: Vector3) -> Mesh:
	var key := str(size)
	if cache.has(key):
		return cache[key]
	var smallest := minf(size.x, minf(size.y, size.z))
	if smallest < 0.15 or maxf(size.x, maxf(size.y, size.z)) > 6.0:
		var cube := BoxMesh.new()
		cube.size = size
		cache[key] = cube
		return cube
	var half := size * 0.5
	var bevel := minf(0.025, smallest * 0.08)
	var core := half - Vector3.ONE * bevel
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: Array = [
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP]]
	for face in 6:
		var normal: Vector3 = faces[face][0]
		var u: Vector3 = faces[face][1]
		var v: Vector3 = faces[face][2]
		var a := half.dot(u.abs())
		var b := half.dot(v.abs())
		var columns: Array[float] = [-a, -a + bevel, a - bevel, a]
		var rows: Array[float] = [-b, -b + bevel, b - bevel, b]
		for row in 4:
			for col in 4:
				var p := normal * half.dot(normal.abs()) + u * columns[col] + v * rows[row]
				var inner := p.clamp(-core, core)
				var n := (p - inner).normalized()
				surface.set_normal(n)
				surface.set_uv(Vector2(float(col) / 3, float(row) / 3))
				surface.add_vertex(inner + n * bevel)
		for row in 3:
			for col in 3:
				var index := face * 16 + row * 4 + col
				for vertex: int in [index, index + 5, index + 1, index, index + 4, index + 5]:
					surface.add_index(vertex)
	var mesh := surface.commit()
	cache[key] = mesh
	return mesh
