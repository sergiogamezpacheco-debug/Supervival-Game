class_name Nature
## Árboles y rocas low poly facetados (propuestas A, B y C de cada uno).
## Todo por código, con el mismo sombreado plano que el superviviente.

const BARK := Color("5a3d24")
const BARK_L := Color("7a5634")


static func _p(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = CharacterModel.mat(color)
	m.position = pos
	m.rotation = rot
	m.scale = scl
	parent.add_child(m)
	return m


## Bulto irregular facetado (roca, copa). jag: cuánto se deforma cada vértice.
static func blob(seed_: int, jag := 0.25, sides := 7, rings := 4, flat_base := true) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var rows: Array = []
	for k in range(1, rings):
		var phi := PI * float(k) / float(rings)
		var row: Array = []
		var off := PI / float(sides) * float(k)
		for i in sides:
			var a := off + TAU * float(i) / float(sides)
			var r := 1.0 + rng.randf_range(-jag, jag)
			var v := Vector3(sin(phi) * cos(a), cos(phi), sin(phi) * sin(a)) * r
			if flat_base:
				v.y = maxf(v.y, -0.45)
			row.append(v)
		rows.append(row)
	var top := Vector3(rng.randf_range(-0.15, 0.15), 1.0 + rng.randf_range(-jag, jag * 0.5), rng.randf_range(-0.15, 0.15))
	var bot := Vector3(0, -0.45 if flat_base else -1.0, 0)
	var tris: Array = []
	for i in sides:
		var i2 := (i + 1) % sides
		tris.append([top, rows[0][i2], rows[0][i]])
		tris.append([bot, rows[rows.size() - 1][i], rows[rows.size() - 1][i2]])
		for k in rows.size() - 1:
			# filas alternadas medio paso: triángulos en zigzag
			tris.append([rows[k + 1][i], rows[k][i2], rows[k][i]])
			tris.append([rows[k + 1][i], rows[k + 1][i2], rows[k][i2]])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for t in tris:
		var n: Vector3 = (t[1] - t[0]).cross(t[2] - t[0]).normalized()
		var shade := 0.86 + 0.14 * clampf(-n.y if false else n.y, -1.0, 1.0) + rng.randf_range(-0.05, 0.05)
		st.set_color(Color(shade, shade, shade))
		for v in t:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


static func _trunk(root: Node3D, h: float, r: float, lean := 0.0) -> void:
	_p(root, CharacterModel.loft([[0.0, r * 1.5, r * 1.5], [h * 0.12, r * 1.05, r * 1.05], [h * 0.6, r * 0.8, r * 0.8, lean * 0.5, 0.0], [h, r * 0.45, r * 0.45, lean, 0.0]], 6), BARK)
	for a in [0.4, 2.5, 4.4]:   # raíces
		_p(root, CharacterModel.loft([[0.0, r * 0.55, r * 0.3], [r * 1.4, r * 0.2, r * 0.15]], 4), BARK_L, Vector3(cos(a), 0, sin(a)) * r * 1.3, Vector3(0, -a, -1.1))


# ----------------------------------------------------------------- pinos

## A · Pino por capas: faldones cónicos irregulares, silueta clásica.
static func pine_a(seed_ := 1) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	_trunk(root, 1.5, 0.17)
	var greens := [Color("23502b"), Color("2b5f33"), Color("34703b"), Color("3f8246")]
	var y := 0.95
	for k in 4:
		var w := 1.25 - k * 0.26
		var h := 1.05 - k * 0.1
		var ox := rng.randf_range(-0.07, 0.07)
		var oz := rng.randf_range(-0.07, 0.07)
		_p(root, CharacterModel.loft([[0.0, w * 0.86, w * 0.86], [0.16, w, w * rng.randf_range(0.88, 1.0)], [h * 0.55, w * 0.45, w * 0.45, ox, oz], [h, 0.02, 0.02, ox * 2.0, oz * 2.0]], 7),
			greens[k], Vector3(0, y, 0), Vector3(0, rng.randf() * TAU, rng.randf_range(-0.04, 0.04)))
		y += h * 0.52
	return root


## B · Pino de monte: tronco alto y desnudo, copa ancha arriba, ramas secas.
static func pine_b(seed_ := 1) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	_trunk(root, 3.1, 0.2, 0.22)
	for d in [[1.5, 0.9, 0.5], [2.0, 3.6, 0.42]]:   # ramas secas
		_p(root, CharacterModel.loft([[0.0, 0.05, 0.05], [float(d[2]), 0.015, 0.015]], 4), BARK_L, Vector3(0.1, float(d[0]), 0), Vector3(0, float(d[1]), -1.15))
	var greens := [Color("2c5a2e"), Color("386b35"), Color("457b3c")]
	for d in [[Vector3(0.2, 3.05, 0.0), Vector3(1.15, 0.5, 1.0), 0], [Vector3(-0.35, 3.25, 0.25), Vector3(0.8, 0.42, 0.75), 1], [Vector3(0.55, 3.4, -0.2), Vector3(0.7, 0.4, 0.7), 2], [Vector3(0.15, 3.6, 0.05), Vector3(0.6, 0.36, 0.55), 2]]:
		_p(root, blob(seed_ * 31 + int(d[2]) + int(float(d[0].x) * 10.0), 0.14, 7, 3, false), greens[d[2]], d[0], Vector3(0, rng.randf() * TAU, 0), d[1])
	return root


## C · Abeto denso: muchas capas finas que caen, muy puntiagudo.
static func pine_c(seed_ := 1) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	_trunk(root, 1.0, 0.15)
	var n := 7
	for k in n:
		var f := float(k) / float(n - 1)
		var w := lerpf(1.05, 0.2, f)
		var y := 0.6 + k * 0.42
		var c := Color("1f4a34").lerp(Color("3d7d58"), f)
		_p(root, CharacterModel.loft([[-0.14, w, w], [0.0, w * 0.82, w * 0.82], [0.34, w * 0.3, w * 0.3], [0.62, 0.03, 0.03]], 6),
			c, Vector3(rng.randf_range(-0.03, 0.03), y, rng.randf_range(-0.03, 0.03)), Vector3(0, rng.randf() * TAU, 0))
	return root


# ----------------------------------------------------------------- rocas

## A · Peñasco anguloso con dos piedras pequeñas.
static func rock_a(seed_ := 1) -> Node3D:
	var root := Node3D.new()
	_p(root, blob(seed_ * 7 + 1, 0.22, 6, 3), Color("8b8982"), Vector3(0, 0.36, 0), Vector3.ZERO, Vector3(0.95, 0.8, 0.8))
	_p(root, blob(seed_ * 7 + 2, 0.22, 5, 3), Color("7b7972"), Vector3(0.8, 0.14, 0.45), Vector3(0, 1.0, 0), Vector3(0.36, 0.3, 0.32))
	_p(root, blob(seed_ * 7 + 3, 0.22, 5, 3), Color("99978f"), Vector3(-0.7, 0.1, 0.55), Vector3(0, 2.2, 0), Vector3(0.26, 0.22, 0.25))
	return root


## B · Losas apiladas en estratos, como roca de cantera.
static func rock_b(seed_ := 1) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var cols := [Color("86796a"), Color("9a8c7a"), Color("76695c"), Color("a39683")]
	var y := 0.0
	for k in 4:
		var w := 0.95 - k * 0.15
		var h := rng.randf_range(0.2, 0.32)
		_p(root, CharacterModel.loft([[0.0, w, w * 0.8], [h * 0.25, w * 1.04, w * 0.84], [h, w * 0.92, w * 0.72]], 5),
			cols[k], Vector3(rng.randf_range(-0.1, 0.1), y, rng.randf_range(-0.08, 0.08)), Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.07, 0.07)))
		y += h * 0.92
	return root


## C · Roca redondeada con musgo y matas de hierba.
static func rock_c(seed_ := 1) -> Node3D:
	var root := Node3D.new()
	_p(root, blob(seed_ * 11 + 1, 0.16, 8, 4), Color("7f8587"), Vector3(0, 0.38, 0), Vector3.ZERO, Vector3(1.0, 0.72, 0.85))
	_p(root, blob(seed_ * 11 + 2, 0.18, 7, 3), Color("4f7a3a"), Vector3(-0.1, 0.78, 0.05), Vector3.ZERO, Vector3(0.7, 0.2, 0.6))
	_p(root, blob(seed_ * 11 + 3, 0.16, 6, 3), Color("6f7577"), Vector3(0.75, 0.16, -0.3), Vector3.ZERO, Vector3(0.38, 0.3, 0.34))
	for d in [[0.9, 0.35], [-0.95, 0.2], [0.2, 0.95], [-0.5, -0.75]]:
		for a in [-0.4, 0.0, 0.45]:
			_p(root, CharacterModel.loft([[0.0, 0.035, 0.02], [0.32, 0.004, 0.004]], 3), Color("6c9a45"), Vector3(float(d[0]), 0, float(d[1])), Vector3(a * 0.8, a * 3.0, a))
	return root
