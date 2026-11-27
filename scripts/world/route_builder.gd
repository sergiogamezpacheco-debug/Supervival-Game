class_name RouteBuilder
## Tramos de camino entre zonas (data/routes.json): un pasillo largo con el camino en medio y
## fronteras naturales a los lados (pinar cerrado, arroyo, barranco, peñas, vallas, río...).
## El trazado y los edificios salen de la semilla del tramo (siempre iguales); lo que cambia en
## cada visita (árbol caído, coche cruzado, derrumbe, sitio de los infectados) sale de visit_seed.
##
## El camino va de z = 0 (salida, "from") a z = -length (llegada, "to") y serpentea en x.

const HALF := 13.0          # medio ancho por el que se puede andar
const STEP := 2.0           # cada cuánto se muestrea el trazado

const GROUND := {"pinar": "4a6338", "roquedal": "7d6a4e", "campo": "6d7a42", "ribera": "4f6b3a",
	"carretera": "6b7046", "costa": "8a8256", "montana": "6f6450", "via": "6a6a4c"}


## Centro del camino a la altura z.
static func center_x(route: Dictionary, z: float) -> float:
	var L := float(route.get("length", 300))
	var ph := float(hash(str(route.get("name", ""))) % 100) / 100.0 * TAU
	return sin(z / L * TAU * 1.3 + ph) * 6.0 + sin(z / 37.0 + ph * 2.0) * 1.5


## Construye el tramo dentro de root. Devuelve {"spawn", "exit", "creatures": [[tipo, pos]], "obstacles": [...]}.
static func build(root: Node3D, route: Dictionary, visit_seed: int) -> Dictionary:
	var L := float(route.get("length", 300))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(route.get("name", "")))           # fijo: trazado, fronteras, edificios
	var vrng := RandomNumberGenerator.new()
	vrng.seed = visit_seed                               # cambia en cada visita
	var out := {"spawn": Vector3(center_x(route, -4.0), 0, -4.0), "exit": Vector3(center_x(route, -L + 4.0), 0, -L + 4.0),
		"creatures": [], "obstacles": [], "resources": []}
	var stat := Node3D.new()
	stat.name = "Estatico"
	root.add_child(stat)

	# suelo y manchas
	var gcol := Color(str(GROUND.get(str(route.get("biome", "")), "5a6a40")))
	var g := Builder.part(Builder.box(Vector3(140, 0.1, L + 60)), gcol, Vector3(0, -0.05, -L / 2.0))
	stat.add_child(g)
	for i in int(L / 6.0):
		var s := rng.randf_range(2.0, 6.0)
		var z := rng.randf_range(-L - 20, 20)
		var p := Builder.part(Builder.box(Vector3(s, 0.02, s * rng.randf_range(0.6, 1.4))),
			gcol.lightened(0.07) if i % 2 == 0 else gcol.darkened(0.1), Vector3(center_x(route, z) + rng.randf_range(-30, 30), 0.01, z))
		p.rotation.y = rng.randf_range(0, TAU)
		stat.add_child(p)

	var props := {}
	_road(stat, route, L, props)
	var borders: Dictionary = route.get("borders", {})
	_border(stat, root, route, L, -1.0, str(borders.get("left", "pinar_denso")), rng, props)
	_border(stat, root, route, L, 1.0, str(borders.get("right", "pinar_denso")), rng, props)

	# carteles de salida y llegada
	_sign(stat, Vector3(center_x(route, -1.0) + 4.0, 0, -1.0), "<- " + str(route.get("from", "")))
	_sign(stat, Vector3(center_x(route, -L + 1.0) + 4.0, 0, -L + 1.0), str(route.get("to", "")) + " ->")

	# puntos de interés (fijos)
	var keep := []
	for poi in route.get("pois", []):
		var z := -L * float(poi.get("at", 0.5))
		var side := str(poi.get("side", "right"))
		var off := 0.0 if side == "center" else (7.5 if side == "right" else -7.5)
		var pos := Vector3(center_x(route, z) + off, 0, z)
		var node := poi_mesh(str(poi.get("type", "")), rng)
		node.position = pos
		node.rotation.y = 0.0 if side == "center" else (PI / 2.0 if side == "right" else -PI / 2.0)
		stat.add_child(node)
		keep.append(pos)

	# cambios de cada visita: en unos puntos fijos del camino puede haber (o no) un árbol caído,
	# un coche cruzado, un derrumbe... cada vez una cosa distinta
	var var_d: Dictionary = route.get("variations", {})
	var kinds: Array = var_d.get("obstacles", [])
	out["spots"] = spots(route)
	var placed := 0
	var maxn := int(var_d.get("max", 2))
	for i in out["spots"].size():
		var sp: Vector3 = out["spots"][i]
		if kinds.is_empty() or placed >= maxn or (vrng.randf() < 0.45 and not (i == out["spots"].size() - 1 and placed == 0)):
			out["obstacles"].append(["", sp])
			continue
		var kind := str(kinds[vrng.randi() % kinds.size()])
		var ob := obstacle_mesh(kind, vrng)
		ob.position = sp + Vector3(vrng.randf_range(-1.0, 1.0), 0, 0)
		ob.rotation.y = vrng.randf_range(-0.3, 0.3)
		stat.add_child(ob)
		out["obstacles"].append([kind, ob.position])
		placed += 1

	# recursos (sitio cambia un poco en cada visita) y criaturas (siempre en otro sitio)
	for kind in route.get("resources", {}):
		for i in int(route["resources"][kind]):
			var z := vrng.randf_range(-L + 8, -8)
			var x := center_x(route, z) + vrng.randf_range(-HALF + 1.5, HALF - 1.5)
			if absf(x - center_x(route, z)) < 3.2:
				x += 4.0 * signf(x - center_x(route, z) + 0.01)
			out["resources"].append([str(kind), Vector3(x, 0, z)])
	# un grupito rondando cada sitio con botín (en otro sitio cada visita)
	var guard := str((route.get("creatures", [{"type": "infectado"}]) as Array)[0].get("type", "infectado"))
	for k in keep:
		var a := vrng.randf() * TAU
		var gp: Vector3 = k + Vector3(cos(a), 0, sin(a)) * vrng.randf_range(4.0, 8.0)
		gp.x = clampf(gp.x, center_x(route, gp.z) - HALF + 2.0, center_x(route, gp.z) + HALF - 2.0)
		for j in vrng.randi_range(1, 2):
			out["creatures"].append([guard, gp + Vector3(vrng.randf_range(-1.5, 1.5), 0, vrng.randf_range(-1.5, 1.5))])
	for c in route.get("creatures", []):
		var size: Array = c.get("size", [1, 1])
		for i in int(c.get("groups", 1)):
			var z := vrng.randf_range(-L + 20, -20)
			var cx := center_x(route, z) + vrng.randf_range(-HALF + 3, HALF - 3)
			for j in vrng.randi_range(int(size[0]), int(size[1])):
				out["creatures"].append([str(c["type"]), Vector3(cx + vrng.randf_range(-2, 2), 0, z + vrng.randf_range(-2, 2))])
	Builder.merge(stat)
	_flush(root, props)
	return out


## Puntos fijos del tramo donde cada visita puede poner un obstáculo (lejos de los edificios).
static func spots(route: Dictionary) -> Array:
	var L := float(route.get("length", 300))
	var out := []
	var f := 0.18
	while f < 0.9:
		var near := false
		for poi in route.get("pois", []):
			if absf(float(poi.get("at", 0.5)) - f) < 0.07:
				near = true
		if not near:
			out.append(Vector3(center_x(route, -L * f), 0, -L * f))
		f += 0.17
	return out


# ------------------------------------------------------------------ camino
static func _strip(route: Dictionary, L: float, half_w: float, y: float, col: Color, off := 0.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(col.srgb_to_linear())   # el renderizador compatible toma el color de vértice como lineal
	var z := 2.0
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var first := true
	while z > -L - 2.0:
		var cx := center_x(route, z) + off
		var l := Vector3(cx - half_w, y, z)
		var r := Vector3(cx + half_w, y, z)
		if not first:
			st.set_normal(Vector3.UP)
			st.add_vertex(prev_l)
			st.add_vertex(r)
			st.add_vertex(prev_r)
			st.add_vertex(prev_l)
			st.add_vertex(l)
			st.add_vertex(r)
		prev_l = l
		prev_r = r
		first = false
		z -= STEP
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := Builder.mat(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	return mi


static func _road(root: Node3D, route: Dictionary, L: float, props: Dictionary) -> void:
	match str(route.get("road", "tierra")):
		"asfalto":
			root.add_child(_strip(route, L, 4.2, 0.03, Color("8a7a5a")))      # arcén de tierra
			root.add_child(_strip(route, L, 3.4, 0.05, Color("4a4a4c")))
			var z := 0.0
			while z > -L:   # línea discontinua
				var a := Vector3(center_x(route, z), 0.07, z)
				var b := Vector3(center_x(route, z - 2.5), 0.07, z - 2.5)
				_add(props, "raya", Transform3D(Basis(Vector3.UP, atan2(a.x - b.x, a.z - b.z)), (a + b) / 2.0))
				z -= 6.0
		"via":
			root.add_child(_strip(route, L, 2.4, 0.04, Color("8b8576")))      # balasto
			var z2 := 0.0
			while z2 > -L:
				var ang := atan2(center_x(route, z2) - center_x(route, z2 - 1.0), 1.0)
				_add(props, "traviesa", Transform3D(Basis(Vector3.UP, ang), Vector3(center_x(route, z2), 0.08, z2)))
				z2 -= 0.9
			for side in [-0.72, 0.72]:
				root.add_child(_strip(route, L, 0.06, 0.16, Color("6e6a66"), side))
			root.add_child(_strip(route, L, 1.2, 0.035, Color("7a6a4c"), 3.6))   # senda al lado de la vía
		_:
			root.add_child(_strip(route, L, 2.4, 0.03, Color("9a7a52")))
			for side in [-1.1, 1.1]:   # rodadas
				root.add_child(_strip(route, L, 0.25, 0.04, Color("7d6142"), side))


static func _sign(root: Node3D, pos: Vector3, _txt: String) -> void:
	root.add_child(Builder.part(Builder.box(Vector3(0.12, 1.8, 0.12)), Color("5a4232"), pos + Vector3(0, 0.9, 0)))
	var board := Builder.part(Builder.box(Vector3(1.4, 0.4, 0.06)), Color("b8955e"), pos + Vector3(0.4, 1.55, 0))
	root.add_child(board)
	root.add_child(Builder.part(Builder.box(Vector3(1.0, 0.06, 0.07)), Color("3b2a1a"), pos + Vector3(0.4, 1.55, 0)))


# ------------------------------------------------------------------ piezas repetidas (MultiMesh)
## Decorado que se repite cientos de veces (pinos, rocas, cañas, traviesas): una malla por tipo
## dibujada con MultiMesh, que en el móvil es muchísimo más barato que un nodo por pieza.
static var _protos := {}


static func _add(props: Dictionary, key: String, t: Transform3D) -> void:
	if not props.has(key):
		props[key] = []
	props[key].append(t)


static func _tr(pos: Vector3, rot_y: float, scl: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y).scaled(scl), pos)


static func proto(key: String) -> Mesh:
	if _protos.has(key):
		return _protos[key]
	var n := Node3D.new()
	var parts := key.split("_")
	var v := int(parts[parts.size() - 1]) if parts[parts.size() - 1].is_valid_int() else 1
	match parts[0]:
		"pinoa": n.add_child(Nature.pine_a(v))
		"pinob": n.add_child(Nature.pine_b(v))
		"pinoc": n.add_child(Nature.pine_c(v))
		"rocaa": n.add_child(Nature.rock_a(v))
		"rocab": n.add_child(Nature.rock_b(v))
		"rocac": n.add_child(Nature.rock_c(v))
		"mata": n.add_child(Builder.part(Nature.blob(v * 13 + 5, 0.3, 6, 3), Color("3e5a30")))
		"caña": n.add_child(Builder.part(Builder.cyl(0.0, 0.05, 1.0), Color("7a8a46"), Vector3(0, 0.5, 0)))
		"raya": n.add_child(Builder.part(Builder.box(Vector3(0.18, 0.02, 2.5)), Color("d8d2b0")))
		"traviesa": n.add_child(Builder.part(Builder.box(Vector3(2.6, 0.08, 0.25)), Color("5a4232")))
		"poste": n.add_child(Builder.part(Builder.box(Vector3(0.12, 1.3, 0.12)), Color("5a4232"), Vector3(0, 0.65, 0)))
		"tabla":
			n.add_child(Builder.part(Builder.box(Vector3(0.06, 0.08, 2.0)), Color("7a5a3a"), Vector3(0, 1.05, 0)))
			n.add_child(Builder.part(Builder.box(Vector3(0.06, 0.08, 2.0)), Color("7a5a3a"), Vector3(0, 0.55, 0)))
	Builder.merge(n)
	var am := ArrayMesh.new()
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var tr := mi.transform
		var par := mi.get_parent()
		while par != null and par != n:
			tr = (par as Node3D).transform * tr
			par = par.get_parent()
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for k in verts.size():
				verts[k] = tr * verts[k]
			arr[Mesh.ARRAY_VERTEX] = verts
			if arr[Mesh.ARRAY_NORMAL] != null:
				var nb := tr.basis.inverse().transposed()
				var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				for k in norms.size():
					norms[k] = (nb * norms[k]).normalized()
				arr[Mesh.ARRAY_NORMAL] = norms
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var m: Material = mi.material_override if mi.material_override else mi.mesh.surface_get_material(si)
			am.surface_set_material(am.get_surface_count() - 1, m)
	n.free()
	_protos[key] = am
	return am


static func _flush(root: Node3D, props: Dictionary) -> void:
	for key in props:
		var list: Array = props[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = proto(str(key))
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = str(key)
		mmi.multimesh = mm
		root.add_child(mmi)


# ------------------------------------------------------------------ fronteras
## Una pared invisible y el decorado que la justifica a lo largo de un lado (side = -1 izq., 1 dcha.).
static func _border(stat: Node3D, root: Node3D, route: Dictionary, L: float, side: float, kind: String, rng: RandomNumberGenerator, props: Dictionary) -> void:
	var wall := StaticBody3D.new()
	wall.name = "Frontera_izq" if side < 0.0 else "Frontera_dcha"
	root.add_child(wall)
	var z := 0.0
	while z > -L:
		var cx := center_x(route, z - 5.0)
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(1.0, 4.0, 10.4)
		cs.shape = b
		cs.position = Vector3(cx + side * (HALF + 0.5), 2.0, z - 5.0)
		cs.rotation.y = atan2(center_x(route, z) - center_x(route, z - 10.0), 10.0)
		wall.add_child(cs)
		z -= 10.0
	var e := HALF + 0.8     # donde empieza la frontera
	# franjas continuas (agua, barranco, terraplén)
	match kind:
		"arroyo":
			stat.add_child(_strip(route, L, 2.75, 0.04, Color("6e9aa6"), side * (e + 3.2)))
			stat.add_child(_strip(route, L, 0.5, 0.05, Color("6b5a40"), side * (e + 0.2)))
		"rio":
			stat.add_child(_strip(route, L, 9.0, 0.04, Color("5f8f9e"), side * (e + 9.5)))
			stat.add_child(_strip(route, L, 0.7, 0.06, Color("7a6a4a"), side * (e + 0.3)))
		"barranco":
			stat.add_child(_strip(route, L, 6.0, 0.05, Color("2a2620"), side * (e + 6.5)))
			stat.add_child(_strip(route, L, 0.8, 0.055, Color("4a4034"), side * (e + 1.0)))
		"terraplen":
			stat.add_child(_strip(route, L, 3.5, 0.05, Color("a39a62"), side * (e + 3.0)))
			stat.add_child(_strip(route, L, 0.3, 0.06, Color("6b6440"), side * (e + 0.2)))
		"acantilado":
			stat.add_child(_strip(route, L, 25.0, 0.03, Color("4e7f94"), side * (e + 30.0)))
			stat.add_child(_strip(route, L, 3.0, 0.04, Color("c9b98a"), side * (e + 4.0)))
	z = 2.0
	while z > -L - 4.0:
		var cx := center_x(route, z)
		var x := cx + side * e
		match kind:
			"pinar_denso":
				for row in 4:
					if rng.randf() < 0.85:
						_add(props, "%s_%d" % [["pinoa", "pinob", "pinoc"][rng.randi() % 3], rng.randi() % 3 + 1],
							_tr(Vector3(x + side * (row * 2.2 + rng.randf_range(-0.6, 0.6)), 0, z + rng.randf_range(-0.9, 0.9)), rng.randf() * TAU, Vector3.ONE * rng.randf_range(1.0, 1.45)))
				if rng.randf() < 0.5:
					_add(props, "mata_%d" % (rng.randi() % 3 + 1), _tr(Vector3(x - side * 0.8, 0, z), rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.5, 0.8)))
			"arroyo":
				if rng.randf() < 0.45:
					_add(props, "rocaa_%d" % (rng.randi() % 3 + 1), _tr(Vector3(x + side * rng.randf_range(0.0, 1.0), 0, z), rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.25, 0.45)))
				if rng.randf() < 0.4:
					_add(props, "pinob_%d" % (rng.randi() % 3 + 1), _tr(Vector3(x + side * 7.5, 0, z), rng.randf() * TAU, Vector3.ONE * 1.3))
				_reeds(props, Vector3(x + side * 0.9, 0, z), rng, 2)
			"rio":
				_reeds(props, Vector3(x + side * 0.5, 0, z), rng, 3)
			"canaveral":
				for k in 4:
					_reeds(props, Vector3(x + side * k * 1.4, 0, z + rng.randf_range(-0.8, 0.8)), rng, 5)
			"barranco":
				if rng.randf() < 0.8:
					_add(props, "rocab_%d" % (rng.randi() % 3 + 1), _tr(Vector3(x + side * 0.6, 0, z), rng.randf() * TAU,
						Vector3(rng.randf_range(0.35, 0.6), rng.randf_range(0.25, 0.4), rng.randf_range(0.35, 0.6))))
			"penas", "acantilado":
				# pared de peñascos: dos filas grandes y otra más alta detrás
				for row in (3 if kind == "penas" else 1):
					if rng.randf() < 0.8:
						var sc := rng.randf_range(1.3, 2.2) + row * 0.6
						_add(props, "%s_%d" % [["rocaa", "rocab", "rocac"][rng.randi() % 3], rng.randi() % 3 + 1],
							_tr(Vector3(x + side * (1.2 + row * 2.6 + rng.randf_range(-0.5, 0.5)), 0, z + rng.randf_range(-0.8, 0.8)), rng.randf() * TAU,
								Vector3(sc, sc * rng.randf_range(1.0, 1.8), sc)))
			"vallado":
				if int(-z / STEP) % 2 == 0:
					_add(props, "poste", _tr(Vector3(x, 0, z), 0.0, Vector3.ONE))
				_add(props, "tabla", _tr(Vector3(x, 0, z - STEP / 2.0), atan2(center_x(route, z) - center_x(route, z - STEP), STEP), Vector3.ONE))
				if rng.randf() < 0.35:
					_add(props, "pinoc_%d" % (rng.randi() % 3 + 1), _tr(Vector3(x + side * rng.randf_range(3, 8), 0, z), rng.randf() * TAU, Vector3.ONE))
				if rng.randf() < 0.5:
					_add(props, "mata_%d" % (rng.randi() % 3 + 1), _tr(Vector3(x + side * 1.2, 0, z), rng.randf() * TAU, Vector3.ONE * 0.6))
			"terraplen":
				if rng.randf() < 0.45:
					_add(props, "rocaa_%d" % (rng.randi() % 3 + 1), _tr(Vector3(x + side * rng.randf_range(0.4, 4.0), 0, z), rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.3, 0.6)))
				if rng.randf() < 0.5:
					_add(props, "mata_%d" % (rng.randi() % 3 + 1), _tr(Vector3(x + side * rng.randf_range(1.0, 5.0), 0, z), rng.randf() * TAU, Vector3.ONE * 0.6))
				for row in 2:
					if rng.randf() < 0.7:
						_add(props, "%s_%d" % [["pinoa", "pinoc"][rng.randi() % 2], rng.randi() % 3 + 1],
							_tr(Vector3(x + side * (7.0 + row * 2.4 + rng.randf_range(-0.5, 0.5)), 0, z), rng.randf() * TAU, Vector3.ONE * rng.randf_range(1.0, 1.3)))
		# más allá de la frontera: campo con árboles y matas sueltos (que no se vea vacío)
		if kind not in ["rio", "acantilado", "barranco"] and rng.randf() < 0.55:
			var far := x + side * rng.randf_range(10.0, 34.0)
			if rng.randf() < 0.6:
				_add(props, "%s_%d" % [["pinoa", "pinob", "pinoc"][rng.randi() % 3], rng.randi() % 3 + 1],
					_tr(Vector3(far, 0, z + rng.randf_range(-1, 1)), rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.9, 1.4)))
			else:
				_add(props, "mata_%d" % (rng.randi() % 3 + 1), _tr(Vector3(far, 0, z), rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.5, 0.9)))
		z -= STEP


static func _reeds(props: Dictionary, pos: Vector3, rng: RandomNumberGenerator, n: int) -> void:
	for k in n:
		var h := rng.randf_range(1.0, 1.9)
		var t := Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))).scaled(Vector3(1.8, h, 1.8)),
			pos + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)))
		_add(props, "caña", t)


# ------------------------------------------------------------------ edificios y cosas del camino
static func _box(r: Node3D, size: Vector3, pos: Vector3, col: Color, rot_y := 0.0) -> MeshInstance3D:
	var m := Builder.part(Builder.box(size), col, pos)
	m.rotation.y = rot_y
	r.add_child(m)
	return m


static func house(r: Node3D, w: float, d: float, wall: Color, roof: Color, broken := false) -> void:
	_box(r, Vector3(w, 2.6, d), Vector3(0, 1.3, 0), wall)
	var rf := _box(r, Vector3(w + 0.4, 0.2, d * 0.6), Vector3(0, 2.95, -d * 0.24), roof)
	rf.rotation.x = 0.45
	var rb := _box(r, Vector3(w + 0.4, 0.2, d * 0.6), Vector3(0, 2.95, d * 0.24), roof)
	rb.rotation.x = -0.45
	_box(r, Vector3(0.9, 1.8, 0.08), Vector3(w * 0.2, 0.9, -d / 2.0 - 0.02), Color("3b2a1a"))
	for k in [-1.0, 1.0]:
		_box(r, Vector3(0.7, 0.6, 0.08), Vector3(-w * 0.25 + k * 0.3 - 0.3, 1.6, -d / 2.0 - 0.03), Color("2a3238") if not broken else Color("6b4a2c"))
	if broken:
		var hole := _box(r, Vector3(w * 0.4, 0.25, d * 0.3), Vector3(w * 0.15, 3.0, 0), Color("2a2620"))
		hole.rotation.x = 0.45


static func car(r: Node3D, col: Color, pos: Vector3, rot_y: float, tipped := false) -> void:
	var c := Node3D.new()
	c.position = pos
	c.rotation.y = rot_y
	if tipped:
		c.rotation.z = PI / 2.0
		c.position.y = 0.9
	_box(c, Vector3(1.8, 0.7, 4.2), Vector3(0, 0.6, 0), col)
	_box(c, Vector3(1.6, 0.6, 2.2), Vector3(0, 1.2, 0.2), col.darkened(0.1))
	_box(c, Vector3(1.62, 0.4, 0.06), Vector3(0, 1.25, -0.92), Color("2a3238"))
	for x in [-0.85, 0.85]:
		for z in [-1.3, 1.3]:
			var w := Builder.part(Builder.cyl(0.35, 0.35, 0.25), Color("1e1e1e"), Vector3(x, 0.35, z))
			w.rotation.z = PI / 2.0
			c.add_child(w)
	r.add_child(c)


static func poi_mesh(kind: String, rng: RandomNumberGenerator) -> Node3D:
	var r := Node3D.new()
	r.name = kind
	match kind:
		"cabana_caza", "refugio_montana":
			var cab := Builder.prefab("cabana")
			r.add_child(cab)
		"caseta_peones":
			r.add_child(Builder.prefab("caseta"))
		"casa_labranza", "casa_playa", "tienda_carretera":
			var wall := Color("c9b48c") if kind != "casa_playa" else Color("e2dccb")
			house(r, 6.0, 5.0, wall, Color("9a4a32") if kind != "tienda_carretera" else Color("5a6a72"))
			if kind == "tienda_carretera":
				_box(r, Vector3(4.0, 0.7, 0.1), Vector3(0, 3.6, -2.6), Color("c43a2e"))
				for k in 3:
					_box(r, Vector3(0.6, 0.5, 0.6), Vector3(-2.0 + k * 0.8, 0.25, -3.2), Color("8a6440"))
		"pueblo_abandonado":
			for k in 4:
				var h := Node3D.new()
				h.position = Vector3((k % 2) * 8.0 - 4.0, 0, (k / 2) * 9.0 - 4.5)
				h.rotation.y = rng.randf_range(-0.2, 0.2)
				house(h, 5.5, 4.5, Color("b9a684").darkened(0.05 * k), Color("7a3a2a"), k == 1)
				r.add_child(h)
		"gasolinera":
			_box(r, Vector3(9.0, 0.3, 6.0), Vector3(0, 4.0, 0), Color("d8d0c0"))
			_box(r, Vector3(9.2, 0.5, 0.1), Vector3(0, 4.0, -3.0), Color("c43a2e"))
			for x in [-3.5, 3.5]:
				_box(r, Vector3(0.35, 4.0, 0.35), Vector3(x, 2.0, 0), Color("bcb6aa"))
			for x in [-1.6, 1.6]:
				_box(r, Vector3(0.8, 1.6, 0.6), Vector3(x, 0.8, 0), Color("c43a2e"))
				_box(r, Vector3(0.5, 0.3, 0.05), Vector3(x, 1.2, -0.33), Color("e8e2d2"))
			_box(r, Vector3(9.0, 0.08, 6.0), Vector3(0, 0.04, 0), Color("5a5a5c"))
			var shop := Node3D.new()
			shop.position = Vector3(0, 0, 7.0)
			house(shop, 7.0, 4.0, Color("d8d0c0"), Color("5a6a72"))
			r.add_child(shop)
			car(r, Color("3f6a8a"), Vector3(-1.6, 0, -1.5), 0.1)
		"coches_abandonados", "control_coches":
			car(r, Color("8a3a2e"), Vector3(-2.0, 0, 0), 1.3)
			car(r, Color("6a7a5a"), Vector3(2.4, 0, 1.5), -0.4)
			if kind == "control_coches":
				_box(r, Vector3(6.0, 0.25, 0.25), Vector3(0, 1.0, -3.0), Color("d8d2c0"))
				for k in 4:
					_box(r, Vector3(0.6, 0.27, 0.27), Vector3(-2.25 + k * 1.5, 1.0, -3.0), Color("c43a2e"))
			else:
				car(r, Color("c9b48c"), Vector3(0.3, 0, -5.0), 0.2, true)
		"carteles_aviso":
			for k in 3:
				var p := Vector3(-4.0 + k * 4.0, 0, rng.randf_range(-1, 1))
				_box(r, Vector3(0.12, 1.8, 0.12), p + Vector3(0, 0.9, 0), Color("5a4232"))
				var b := _box(r, Vector3(1.2, 0.8, 0.06), p + Vector3(0, 1.7, 0), Color("e2d8bc"), rng.randf_range(-0.2, 0.2))
				b.rotation.z = rng.randf_range(-0.15, 0.15)
				_box(r, Vector3(0.9, 0.12, 0.07), p + Vector3(0, 1.75, 0), Color("a8281e"))
			for k in 4:
				var arrow := _box(r, Vector3(0.04, 0.9, 0.04), Vector3(rng.randf_range(-5, 5), 0.35, rng.randf_range(-3, 3)), Color("6b4a2c"))
				arrow.rotation.x = 0.5
		"pila_troncos":
			for k in 6:
				var lg := Builder.part(Builder.cyl(0.25, 0.25, 3.0), Color("7a5232"), Vector3(-0.6 + (k % 3) * 0.55, 0.25 + (k / 3) * 0.45, 0))
				lg.rotation.x = PI / 2.0
				r.add_child(lg)
		"vagoneta", "vagoneta_suelta":
			_box(r, Vector3(1.4, 0.9, 2.0), Vector3(0, 0.8, 0), Color("6a5a4a"))
			_box(r, Vector3(1.2, 0.3, 1.8), Vector3(0, 1.2, 0), Color("2a2620"))
		"vagon_volcado":
			var v := _box(r, Vector3(3.0, 3.0, 12.0), Vector3(0, 1.5, 0), Color("6a4a3a"))
			v.rotation.z = 1.35
			v.position.y = 1.3
			_box(r, Vector3(2.4, 0.1, 10.0), Vector3(-1.6, 0.06, 0), Color("4a3a2e"))
		"molino":
			var base := Builder.part(Builder.cyl(1.8, 2.3, 6.0), Color("d8cdb4"), Vector3(0, 3.0, 0))
			r.add_child(base)
			r.add_child(Builder.part(Builder.cyl(0.0, 2.2, 1.6), Color("8a4a32"), Vector3(0, 6.8, 0)))
			for k in 4:
				var blade := _box(r, Vector3(0.4, 5.0, 0.08), Vector3(0, 5.5, -2.4), Color("e8dfc8"))
				blade.rotation.z = k * PI / 2.0 + 0.3
		"barca":
			_box(r, Vector3(1.4, 0.5, 3.6), Vector3(0, 0.25, 0), Color("6e4a2c"))
			_box(r, Vector3(1.1, 0.1, 3.2), Vector3(0, 0.5, 0), Color("4a3828"))
		"furgoneta":
			car(r, Color("e2dccb"), Vector3.ZERO, 0.4)
			_box(r, Vector3(1.9, 1.2, 2.6), Vector3(0.6, 1.6, 0.2), Color("e2dccb"), 0.4)
		"puente":
			_box(r, Vector3(5.6, 0.3, 10.0), Vector3(0, 0.15, 0), Color("6e4a2c"))
			for x in [-2.7, 2.7]:
				_box(r, Vector3(0.15, 1.0, 10.0), Vector3(x, 0.8, 0), Color("5a3a22"))
		"control_militar":
			for k in 7:
				var sb := Builder.part(Nature.blob(k + 11, 0.15, 6, 3), Color("a89a6a"), Vector3(-5.0 + k * 0.7, 0.0, 0))
				sb.scale = Vector3(0.45, 0.4, 0.3)
				r.add_child(sb)
			_box(r, Vector3(5.0, 0.2, 0.2), Vector3(2.5, 1.0, 0), Color("d8d2c0"))
			var tent := Builder.part(Builder.cyl(0.0, 3.0, 2.6), Color("5f6a42"), Vector3(-4.0, 1.3, 5.0))
			r.add_child(tent)
			_box(r, Vector3(2.4, 2.4, 6.0), Vector3(5.0, 1.2, 5.0), Color("4f6a58"))
	return r


static func _coll(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	body.add_child(cs)


## Lo que puede aparecer en mitad del camino en una visita (y en la siguiente ya no).
static func obstacle_mesh(kind: String, rng: RandomNumberGenerator) -> Node3D:
	var r := StaticBody3D.new()
	r.add_to_group("obstacle")
	r.name = kind
	match kind:
		"arbol_caido":
			var trunk := Builder.part(Builder.cyl(0.32, 0.4, 9.0), Color("6b4a2c"), Vector3(0, 0.38, 0))
			trunk.rotation.z = PI / 2.0
			r.add_child(trunk)
			var crown := Nature.pine_b(rng.randi())
			crown.rotation.z = -PI / 2.0
			crown.position = Vector3(4.5, 0.4, 0)
			crown.scale = Vector3.ONE * 1.2
			r.add_child(crown)
			_coll(r, Vector3(8.0, 0.8, 0.8), Vector3(0, 0.4, 0))
		"coche_cruzado":
			car(r, [Color("8a3a2e"), Color("3f6a8a"), Color("c9b48c")][rng.randi() % 3], Vector3.ZERO, PI / 2.0 + rng.randf_range(-0.3, 0.3))
			_coll(r, Vector3(1.8, 1.4, 4.2), Vector3(0, 0.7, 0))
		"rocas_derrumbe":
			for k in 5:
				var rk := Nature.rock_a(rng.randi())
				rk.scale = Vector3.ONE * rng.randf_range(0.4, 0.75)
				rk.position = Vector3(-3.0 + k * 1.5 + rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-1.0, 1.0))
				r.add_child(rk)
		"barricada":
			for k in 4:
				var pl := Builder.part(Builder.box(Vector3(2.2, 0.25, 0.2)), Color("7a5a3a"), Vector3(-3.0 + k * 2.0, 0.6 + (k % 2) * 0.3, 0))
				pl.rotation.z = rng.randf_range(-0.4, 0.4)
				r.add_child(pl)
			for k in 3:
				var bar := Builder.part(Builder.cyl(0.4, 0.4, 1.0), Color("3f5a6a"), Vector3(-2.5 + k * 2.5, 0.5, 0.8))
				r.add_child(bar)
		"barro":
			r.add_child(Builder.part(Nature.blob(rng.randi(), 0.2, 8, 2), Color("4a3a28"), Vector3.ZERO))
			r.get_child(0).scale = Vector3(4.0, 0.05, 2.5)
		"vagoneta_suelta":
			r.add_child(poi_mesh("vagoneta", rng))
	return r
