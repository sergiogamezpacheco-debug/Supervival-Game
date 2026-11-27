class_name Builder
extends RefCounted
## Modelos provisionales hechos con primitivas. Se sustituirán por modelos .glb
## sin tocar la lógica: basta con cambiar la función correspondiente.

static var _mats: Dictionary = {}


# ------------------------------------------------- unir mallas (menos dibujos)

static var _merged_mats := {}


## Une en una sola malla todas las piezas opacas y sin brillo propio que cuelgan de
## "root" (con el color de cada una pasado a los vértices). Se ve igual, pero el móvil
## lo dibuja de una vez en lugar de pieza a pieza. Luces, fuego y transparencias se quedan aparte.
## Si "direct" es true, solo une los hijos directos (para modelos con articulaciones).
static func merge(root: Node3D, direct := false) -> Node3D:
	var parts: Array = []
	var nodes: Array = root.get_children() if direct else root.find_children("*", "MeshInstance3D", true, false)
	for n in nodes:
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.visible or mi.get_child_count() > 0:
			continue
		var m := mi.material_override as StandardMaterial3D
		if m == null and mi.mesh.get_surface_count() > 0:
			m = mi.mesh.surface_get_material(0) as StandardMaterial3D
		if m == null or m.emission_enabled or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.albedo_texture != null:
			continue
		if mi.material_overlay != null:
			continue
		parts.append([mi, m])
	if parts.size() < 2:
		return root
	var groups := {}
	for pm in parts:
		var mi: MeshInstance3D = pm[0]
		var m: StandardMaterial3D = pm[1]
		var key := "%d_%.2f" % [m.cull_mode, m.roughness]
		if not groups.has(key):
			groups[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array(), "cull": m.cull_mode, "rough": m.roughness}
		var g: Dictionary = groups[key]
		# transformación de la pieza respecto a root
		var t := mi.transform
		var par := mi.get_parent()
		while par != null and par != root:
			if par is Node3D:
				t = (par as Node3D).transform * t
			par = par.get_parent()
		var nb := t.basis.inverse().transposed()
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var base: int = (g["v"] as PackedVector3Array).size()
			var use_vc := m.vertex_color_use_as_albedo and cols.size() == verts.size()
			for k in verts.size():
				g["v"].append(t * verts[k])
				g["n"].append((nb * norms[k]).normalized() if k < norms.size() else Vector3.UP)
				g["c"].append(m.albedo_color * cols[k] if use_vc else m.albedo_color)
			if idx.is_empty():
				for k in verts.size():
					g["i"].append(base + k)
			else:
				for k in idx:
					g["i"].append(base + k)
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	for key in groups:
		var g: Dictionary = groups[key]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g["v"]
		arr[Mesh.ARRAY_NORMAL] = g["n"]
		arr[Mesh.ARRAY_COLOR] = g["c"]
		arr[Mesh.ARRAY_INDEX] = g["i"]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mk: String = str(key)
		if not _merged_mats.has(mk):
			var mm := StandardMaterial3D.new()
			mm.vertex_color_use_as_albedo = true
			mm.albedo_color = Color.WHITE
			mm.roughness = float(g["rough"])
			mm.cull_mode = int(g["cull"])
			_merged_mats[mk] = mm
		var out := MeshInstance3D.new()
		out.name = "unida"
		out.mesh = am
		out.material_override = _merged_mats[mk]
		root.add_child(out)
	return root


static func mat(color: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), emission]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


static func part(mesh: Mesh, color: Color, pos := Vector3.ZERO, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color, emission)
	mi.position = pos
	return mi


static func cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	return c


static func sphere(r: float, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0.0 else h
	s.radial_segments = 10
	s.rings = 6
	return s


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func resource_mesh(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"pino":
			# Mezcla: en el bosque mandan el pino por capas y el abeto; fuera hay más pino de monte
			var mix := "aaccb" if GS.current_map == "bosque" else "abbc"
			var t: Node3D
			match mix[randi() % mix.length()]:
				"a": t = Nature.pine_a(randi() % 6 + 1)
				"b": t = Nature.pine_b(randi() % 6 + 1)
				_: t = Nature.pine_c(randi() % 6 + 1)
			t.scale = Vector3.ONE * randf_range(0.85, 1.2)
			t.rotation.y = randf() * TAU
			root.add_child(t)
		"arbol":
			# árbol pequeño de hoja (La Arboleda): da madera básica
			var tr := Node3D.new()
			Nature._trunk(tr, 1.7, 0.13, randf_range(-0.15, 0.15))
			var greens := [Color("4f7d38"), Color("5d8c40"), Color("6a9a48")]
			for k in 4:
				var off := Vector3(randf_range(-0.45, 0.45), 1.8 + randf_range(0.0, 0.6), randf_range(-0.45, 0.45))
				Nature._p(tr, Nature.blob(randi() % 50 + k * 7, 0.18, 7, 3, false), greens[k % 3], off,
					Vector3(0, randf() * TAU, 0), Vector3.ONE * randf_range(0.55, 0.85))
			tr.scale = Vector3.ONE * randf_range(0.85, 1.15)
			tr.rotation.y = randf() * TAU
			root.add_child(tr)
		"roca":
			# En la cantera, losas; en el resto, peñascos y rocas con musgo
			var mixr := "bbba" if GS.current_map == "cantera" else "aacb"
			var rk: Node3D
			match mixr[randi() % mixr.length()]:
				"a": rk = Nature.rock_a(randi() % 6 + 1)
				"b": rk = Nature.rock_b(randi() % 6 + 1)
				_: rk = Nature.rock_c(randi() % 6 + 1)
			rk.scale = Vector3.ONE * randf_range(0.85, 1.1)
			rk.rotation.y = randf() * TAU
			root.add_child(rk)
		"veta_hierro":
			var v := part(sphere(0.8, 1.1), Color("5f5650"), Vector3(0, 0.4, 0))
			v.scale = Vector3(1.0, 0.85, 0.9)
			root.add_child(v)
			for p in [Vector3(0.4, 0.6, 0.3), Vector3(-0.35, 0.5, 0.35), Vector3(0.1, 0.85, -0.3), Vector3(-0.2, 0.75, -0.1)]:
				root.add_child(part(box(Vector3(0.22, 0.18, 0.2)), Color("b5651d"), p))
		"veta_carbon":
			var v := part(sphere(0.8, 1.0), Color("4b4846"), Vector3(0, 0.38, 0))
			v.scale = Vector3(1.0, 0.85, 0.9)
			root.add_child(v)
			for p in [Vector3(0.35, 0.6, 0.3), Vector3(-0.3, 0.55, 0.3), Vector3(0.05, 0.8, -0.3)]:
				root.add_child(part(box(Vector3(0.24, 0.2, 0.22)), Color("151515"), p))
		"veta_cobre":
			var v := part(sphere(0.8, 1.05), Color("6a5f58"), Vector3(0, 0.4, 0))
			v.scale = Vector3(1.0, 0.85, 0.9)
			root.add_child(v)
			for p in [Vector3(0.4, 0.6, 0.3), Vector3(-0.35, 0.5, 0.35), Vector3(0.1, 0.85, -0.3), Vector3(-0.2, 0.7, -0.15)]:
				root.add_child(part(box(Vector3(0.22, 0.18, 0.2)), Color("4aa38a") if p.x < 0 else Color("c9733f"), p))
		"veta_azufre":
			var v := part(sphere(0.75, 0.95), Color("7a7064"), Vector3(0, 0.36, 0))
			v.scale = Vector3(1.0, 0.8, 0.9)
			root.add_child(v)
			for p in [Vector3(0.35, 0.55, 0.3), Vector3(-0.3, 0.5, 0.3), Vector3(0.05, 0.75, -0.3)]:
				root.add_child(part(box(Vector3(0.26, 0.2, 0.24)), Color("e3d03a"), p))
		"chatarra":
			root.add_child(part(box(Vector3(1.0, 0.25, 0.7)), Color("7a4a2a"), Vector3(0, 0.12, 0)))
			var pipe := part(cyl(0.08, 0.08, 1.1), Color("6a6e70"), Vector3(0.1, 0.35, 0))
			pipe.rotation_degrees = Vector3(0, 30, 80)
			root.add_child(pipe)
			root.add_child(part(box(Vector3(0.4, 0.35, 0.35)), Color("8b5e3c"), Vector3(-0.3, 0.3, 0.15)))
		"seta":
			for p in [Vector3(0, 0, 0), Vector3(0.2, 0, 0.12), Vector3(-0.15, 0, 0.18)]:
				root.add_child(part(cyl(0.04, 0.05, 0.22), Color("efe6d2"), p + Vector3(0, 0.11, 0)))
				root.add_child(part(sphere(0.13, 0.1), Color("b8432f"), p + Vector3(0, 0.24, 0)))
		"arbusto":
			root.add_child(part(sphere(0.55), Color("2e5e2a"), Vector3(0, 0.45, 0)))
			for p in [Vector3(0.3, 0.6, 0.25), Vector3(-0.25, 0.7, 0.2), Vector3(0.05, 0.55, -0.4)]:
				root.add_child(part(sphere(0.09), Color("c0262d"), p))
		"hierba":
			for i in 5:
				var a := TAU * float(i) / 5.0
				var blade := part(cyl(0.0, 0.07, 0.6), Color("a3b84a"), Vector3(cos(a) * 0.15, 0.3, sin(a) * 0.15))
				blade.rotation = Vector3(sin(a) * 0.3, 0, cos(a) * 0.3)
				root.add_child(blade)
		"ramas":
			# palos secos caídos: se recogen a mano (madera sin hacha)
			for i in 4:
				var a := float(i) * 1.9 + randf() * 0.5
				var st := part(cyl(0.035, 0.05, 0.9 - i * 0.12), Color("7a5232").lightened(0.06 * (i % 2)), Vector3(cos(a) * 0.12, 0.05 + i * 0.03, sin(a) * 0.12))
				st.rotation = Vector3(PI / 2.0, a, 0)
				root.add_child(st)
				var twig := part(cyl(0.015, 0.02, 0.25), Color("6b4a2c"), Vector3(cos(a) * 0.25, 0.08, sin(a) * 0.25))
				twig.rotation = Vector3(PI / 2.0, a + 0.7, 0)
				root.add_child(twig)
		"piedras":
			# piedras sueltas por el suelo: se recogen a mano (piedra sin pico)
			for i in 5:
				var a := float(i) * 1.3
				var d := 0.1 + float(i % 3) * 0.12
				var pr := Nature.rock_a(i + 1)
				pr.scale = Vector3.ONE * (0.16 + 0.04 * float(i % 2))
				pr.position = Vector3(cos(a) * d, 0, sin(a) * d)
				pr.rotation.y = a
				root.add_child(pr)
	return root


static func player_mesh() -> Node3D:
	# Fantasma cian translúcido (provisional hasta importar el modelo propio).
	var root := Node3D.new()
	var ghost := Color(0.35, 0.95, 1.0, 0.75)
	var body := CapsuleMesh.new()
	body.radius = 0.35
	body.height = 1.5
	root.add_child(part(body, ghost, Vector3(0, 0.85, 0), 1.2))
	root.add_child(part(sphere(0.07), Color.WHITE, Vector3(0.13, 1.35, -0.3), 3.0))
	root.add_child(part(sphere(0.07), Color.WHITE, Vector3(-0.13, 1.35, -0.3), 3.0))
	# Mano: aquí se cuelga la herramienta equipada.
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0.42, 0.9, -0.15)
	root.add_child(hand)
	return root


static func tool_mesh(item_id: String) -> Node3D:
	var root := Node3D.new()
	if item_id == "":
		return root
	if item_id == "molotov":
		# botella con líquido ámbar y trapo atado al cuello
		root.add_child(part(cyl(0.09, 0.1, 0.26), Color(0.55, 0.75, 0.6, 0.6), Vector3(0, 0.13, 0)))
		root.add_child(part(cyl(0.085, 0.095, 0.16), Color("d9a43a"), Vector3(0, 0.09, 0)))
		root.add_child(part(cyl(0.035, 0.07, 0.12), Color(0.55, 0.75, 0.6, 0.6), Vector3(0, 0.32, 0)))
		root.add_child(part(box(Vector3(0.1, 0.16, 0.05)), Color("e8dcc0"), Vector3(0.04, 0.42, 0)))
		root.add_child(part(cyl(0.0, 0.05, 0.1), Color("ffb347"), Vector3(0.04, 0.54, 0), 3.0))
		return root
	root.add_child(part(cyl(0.04, 0.04, 0.9), Color("8b5a2b"), Vector3(0, 0, -0.2)))
	match item_id:
		"hacha_piedra":
			root.add_child(part(box(Vector3(0.08, 0.25, 0.22)), Color("8a8c8f"), Vector3(0, 0.35, -0.3)))
		"pico_piedra":
			root.add_child(part(box(Vector3(0.08, 0.1, 0.5)), Color("8a8c8f"), Vector3(0, 0.4, -0.2)))
		"lanza":
			root.add_child(part(cyl(0.0, 0.06, 0.25), Color("cfc29a"), Vector3(0, 0.55, -0.2)))
		"antorcha":
			# trapo atado y llama que alumbra
			root.add_child(part(cyl(0.065, 0.06, 0.14), Color("b49a6a"), Vector3(0, 0.42, -0.2)))
			root.add_child(part(cyl(0.0, 0.08, 0.22), Color("ffb347"), Vector3(0, 0.6, -0.2), 3.0))
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.72, 0.4)
			l.light_energy = 1.6
			l.omni_range = 7.0
			l.position = Vector3(0, 0.75, -0.2)
			root.add_child(l)
		"garrote":
			root.add_child(part(cyl(0.07, 0.05, 0.4), Color("8b5a2b"), Vector3(0, 0.35, -0.2)))
			for k in 5:
				var a := float(k) * 1.3
				root.add_child(part(box(Vector3(0.02, 0.02, 0.16)), Color("9aa0a4"), Vector3(sin(a) * 0.07, 0.3 + k * 0.05, -0.2 + cos(a) * 0.07)))
	root.rotation_degrees = Vector3(-60, 0, 0)
	return root


static func zombie_mesh() -> Node3D:
	var root := Node3D.new()
	var skin := Color("6f8f5a")
	var body := CapsuleMesh.new()
	body.radius = 0.33
	body.height = 1.6
	root.add_child(part(body, Color("4a4560"), Vector3(0, 0.8, 0)))
	root.add_child(part(sphere(0.25), skin, Vector3(0, 1.75, 0)))
	root.add_child(part(cyl(0.08, 0.08, 0.7), skin, Vector3(0.25, 1.25, -0.35)))
	root.add_child(part(cyl(0.08, 0.08, 0.7), skin, Vector3(-0.25, 1.25, -0.35)))
	root.get_child(2).rotation_degrees.x = 80
	root.get_child(3).rotation_degrees.x = 80
	root.add_child(part(sphere(0.05), Color("ff3b30"), Vector3(0.09, 1.8, -0.22), 4.0))
	root.add_child(part(sphere(0.05), Color("ff3b30"), Vector3(-0.09, 1.8, -0.22), 4.0))
	return root


static func bag_mesh(is_player_bag: bool) -> Node3D:
	var root := Node3D.new()
	var c := Color("d9a441") if is_player_bag else Color("6d5a44")
	root.add_child(part(box(Vector3(0.6, 0.45, 0.4)), c, Vector3(0, 0.23, 0)))
	root.add_child(part(box(Vector3(0.62, 0.12, 0.42)), c.darkened(0.3), Vector3(0, 0.5, 0)))
	if is_player_bag:
		root.add_child(part(sphere(0.12), Color(1, 0.85, 0.3), Vector3(0, 1.4, 0), 3.0))
	return root


static func well_mesh() -> Node3D:
	var root := Node3D.new()
	root.add_child(part(cyl(0.9, 1.0, 0.8), Color("8f8a80"), Vector3(0, 0.4, 0)))
	root.add_child(part(cyl(0.75, 0.75, 0.05), Color("2b6fa8"), Vector3(0, 0.7, 0), 0.4))
	root.add_child(part(box(Vector3(0.12, 1.6, 0.12)), Color("6b4423"), Vector3(0.85, 1.2, 0)))
	root.add_child(part(box(Vector3(0.12, 1.6, 0.12)), Color("6b4423"), Vector3(-0.85, 1.2, 0)))
	root.add_child(part(box(Vector3(2.0, 0.12, 0.5)), Color("7a4f2a"), Vector3(0, 2.0, 0)))
	return root


static func creature_mesh(kind: String) -> Node3D:
	match kind:
		"conejo":
			var r := Node3D.new()
			var fur := Color("a08a6e")
			r.add_child(part(sphere(0.22, 0.36), fur, Vector3(0, 0.2, 0.05)))
			r.add_child(part(sphere(0.13), fur, Vector3(0, 0.33, -0.2)))
			r.add_child(part(box(Vector3(0.05, 0.22, 0.06)), fur, Vector3(0.05, 0.52, -0.2)))
			r.add_child(part(box(Vector3(0.05, 0.22, 0.06)), fur, Vector3(-0.05, 0.52, -0.2)))
			r.add_child(part(sphere(0.06), Color.WHITE, Vector3(0, 0.25, 0.27)))
			return r
		"jabali":
			var r := Node3D.new()
			var hide := Color("4a3a2e")
			r.add_child(part(box(Vector3(0.6, 0.6, 1.2)), hide, Vector3(0, 0.6, 0)))
			r.add_child(part(box(Vector3(0.45, 0.45, 0.45)), hide, Vector3(0, 0.6, -0.75)))
			r.add_child(part(box(Vector3(0.2, 0.15, 0.15)), Color("6b5545"), Vector3(0, 0.5, -1.02)))
			r.add_child(part(cyl(0.0, 0.03, 0.18), Color("eee8d5"), Vector3(0.12, 0.45, -0.98)))
			r.add_child(part(cyl(0.0, 0.03, 0.18), Color("eee8d5"), Vector3(-0.12, 0.45, -0.98)))
			for p in [Vector3(0.2, 0.15, 0.4), Vector3(-0.2, 0.15, 0.4), Vector3(0.2, 0.15, -0.4), Vector3(-0.2, 0.15, -0.4)]:
				r.add_child(part(box(Vector3(0.12, 0.3, 0.12)), hide.darkened(0.3), p))
			return r
		"lobo":
			var r := Node3D.new()
			var grey := Color("6e7276")
			r.add_child(part(box(Vector3(0.4, 0.45, 1.1)), grey, Vector3(0, 0.65, 0)))
			r.add_child(part(box(Vector3(0.32, 0.32, 0.42)), grey, Vector3(0, 0.85, -0.7)))
			r.add_child(part(box(Vector3(0.16, 0.14, 0.25)), grey.darkened(0.2), Vector3(0, 0.78, -0.98)))
			r.add_child(part(cyl(0.0, 0.07, 0.18), grey, Vector3(0.1, 1.08, -0.65)))
			r.add_child(part(cyl(0.0, 0.07, 0.18), grey, Vector3(-0.1, 1.08, -0.65)))
			r.add_child(part(sphere(0.04), Color("ffd23f"), Vector3(0.08, 0.9, -0.92), 3.0))
			r.add_child(part(sphere(0.04), Color("ffd23f"), Vector3(-0.08, 0.9, -0.92), 3.0))
			for p in [Vector3(0.14, 0.22, 0.4), Vector3(-0.14, 0.22, 0.4), Vector3(0.14, 0.22, -0.4), Vector3(-0.14, 0.22, -0.4)]:
				r.add_child(part(box(Vector3(0.1, 0.45, 0.1)), grey.darkened(0.25), p))
			var tail := part(box(Vector3(0.1, 0.1, 0.45)), grey, Vector3(0, 0.8, 0.7))
			tail.rotation_degrees.x = 25
			r.add_child(tail)
			return r
		"ciervo":
			var r := Node3D.new()
			var fur := Color("8a6240")
			r.add_child(part(box(Vector3(0.45, 0.5, 1.2)), fur, Vector3(0, 1.0, 0)))
			var neck := part(box(Vector3(0.22, 0.6, 0.25)), fur, Vector3(0, 1.4, -0.55))
			neck.rotation_degrees.x = -25
			r.add_child(neck)
			r.add_child(part(box(Vector3(0.24, 0.24, 0.42)), fur, Vector3(0, 1.7, -0.75)))
			for sx in [0.12, -0.12]:
				var antler := part(cyl(0.02, 0.03, 0.5), Color("d9c9a3"), Vector3(sx, 2.0, -0.7))
				antler.rotation_degrees.z = 25.0 if sx > 0 else -25.0
				r.add_child(antler)
			for p in [Vector3(0.15, 0.38, 0.45), Vector3(-0.15, 0.38, 0.45), Vector3(0.15, 0.38, -0.45), Vector3(-0.15, 0.38, -0.45)]:
				r.add_child(part(box(Vector3(0.09, 0.76, 0.09)), fur.darkened(0.3), p))
			r.add_child(part(sphere(0.08), Color.WHITE, Vector3(0, 1.1, 0.62)))
			return r
		"minero":
			var r := zombie_mesh()
			r.add_child(part(sphere(0.3, 0.32), Color("e0b43a"), Vector3(0, 1.88, 0)))
			r.add_child(part(cyl(0.07, 0.07, 0.06), Color(1, 1, 0.8), Vector3(0, 1.93, -0.27), 4.0))
			(r.get_child(0) as MeshInstance3D).material_override = mat(Color("4a5a6e"))
			return r
		"acorazado":
			var inner := zombie_mesh()
			inner.add_child(part(box(Vector3(0.8, 0.7, 0.5)), Color("5b6168"), Vector3(0, 1.1, 0)))
			inner.add_child(part(sphere(0.3, 0.3), Color("4d5258"), Vector3(0, 1.9, 0)))
			inner.add_child(part(box(Vector3(0.3, 0.2, 0.4)), Color("5b6168"), Vector3(0.45, 1.45, 0)))
			inner.add_child(part(box(Vector3(0.3, 0.2, 0.4)), Color("5b6168"), Vector3(-0.45, 1.45, 0)))
			inner.scale = Vector3(1.3, 1.15, 1.3)
			var r := Node3D.new()
			r.add_child(inner)
			return r
		"vibora":
			var r := Node3D.new()
			var sk := Color("6b5a2e")
			for i in 6:
				var a := float(i) * 0.9
				r.add_child(part(sphere(0.09 - i * 0.008), sk if i % 2 == 0 else sk.darkened(0.4), Vector3(sin(a) * 0.18, 0.09, -0.3 + i * 0.13)))
			r.add_child(part(box(Vector3(0.14, 0.08, 0.18)), sk.darkened(0.2), Vector3(0, 0.11, -0.42)))
			return r
	return zombie_mesh()


# --------------------------------------------------------- zonas y ruinas

static func container_mesh(id: String) -> Node3D:
	var root := Node3D.new()
	match id:
		"caja_herramientas":
			root.add_child(part(box(Vector3(0.9, 0.45, 0.5)), Color("b23a2e"), Vector3(0, 0.23, 0)))
			root.add_child(part(box(Vector3(0.5, 0.08, 0.08)), Color("333333"), Vector3(0, 0.5, 0)))
		"taquilla":
			root.add_child(part(box(Vector3(0.8, 1.8, 0.5)), Color("6d7f8c"), Vector3(0, 0.9, 0)))
			root.add_child(part(box(Vector3(0.02, 1.6, 0.02)), Color("3d4a52"), Vector3(0, 0.9, -0.26)))
		"coche", "coche_bueno":
			# coche abandonado: oxidado, con el maletero abierto
			var col := Color("8a5a3a") if id == "coche" else Color("4f6a58")
			RouteBuilder.car(root, col, Vector3.ZERO, 0.0)
			var lid := part(box(Vector3(1.6, 0.06, 0.9)), col.darkened(0.15), Vector3(0, 1.35, 2.3))
			lid.rotation.x = -1.0
			root.add_child(lid)
			for k in 4:   # óxido
				root.add_child(part(box(Vector3(0.35, 0.02, 0.4)), Color("6b3a22"), Vector3(-0.5 + k * 0.33, 0.96, -1.2 + k * 0.7)))
			if id == "coche_bueno":   # baca con bultos
				root.add_child(part(box(Vector3(1.3, 0.35, 1.2)), Color("5f6a42"), Vector3(0, 1.7, 0.1)))
		"cadaver":
			# superviviente muerto boca abajo con su mochila
			root.add_child(part(box(Vector3(1.6, 0.02, 1.2)), Color("4a1e18"), Vector3(0.1, 0.01, 0.1)))
			root.add_child(part(box(Vector3(0.5, 0.25, 0.75)), Color("5a6a4a"), Vector3(0, 0.14, 0)))
			root.add_child(part(sphere(0.15), Color("c8a07c"), Vector3(0, 0.15, -0.55)))
			for x in [-0.13, 0.13]:
				root.add_child(part(box(Vector3(0.17, 0.16, 0.8)), Color("3d4a5a"), Vector3(x, 0.09, 0.75)))
			for x in [-0.36, 0.36]:
				root.add_child(part(box(Vector3(0.14, 0.13, 0.6)), Color("5a6a4a"), Vector3(x, 0.08, -0.25)))
			root.add_child(part(box(Vector3(0.42, 0.22, 0.4)), Color("7a5a32"), Vector3(0, 0.36, 0.05)))
		_:
			root.add_child(part(box(Vector3(1.1, 0.55, 0.65)), Color("4e3a26"), Vector3(0, 0.28, 0)))
			root.add_child(part(box(Vector3(1.14, 0.2, 0.69)), Color("3b2c1d"), Vector3(0, 0.62, 0)))
			root.add_child(part(box(Vector3(1.16, 0.06, 0.7)), Color("6b6b6b"), Vector3(0, 0.4, 0)))
	return root


## Pieza sólida (malla + colisión) para las ruinas.
static func solid(body: StaticBody3D, size: Vector3, pos: Vector3, color: Color, rot_y := 0.0) -> void:
	var m := part(box(size), color, pos)
	m.rotation_degrees.y = rot_y
	body.add_child(m)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	cs.rotation_degrees.y = rot_y
	body.add_child(cs)


## Edificios y decorado de las zonas. Devuelve un StaticBody3D con colisiones.
static func prefab(kind: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.add_to_group("obstacle")
	match kind:
		"cabana":
			var logc := Color("6e4a2c")
			b.add_child(part(box(Vector3(6.0, 0.1, 5.0)), Color("5a4330"), Vector3(0, 0.05, 0)))
			solid(b, Vector3(6.0, 2.2, 0.3), Vector3(0, 1.1, -2.5), logc)
			solid(b, Vector3(0.3, 2.2, 5.0), Vector3(-3.0, 1.1, 0), logc)
			solid(b, Vector3(0.3, 1.4, 5.0), Vector3(3.0, 0.7, 0), logc.darkened(0.15))
			solid(b, Vector3(2.0, 2.2, 0.3), Vector3(-2.0, 1.1, 2.5), logc)
			solid(b, Vector3(2.0, 1.0, 0.3), Vector3(2.0, 0.5, 2.5), logc.darkened(0.15))
			solid(b, Vector3(1.2, 0.8, 0.8), Vector3(-2.0, 0.4, -1.6), Color("4a3828"))
			b.add_child(part(box(Vector3(2.5, 0.12, 1.2)), Color("3d2a1a"), Vector3(1.0, 1.5, -1.0)))
		"aserradero":
			var wood := Color("7d5a35")
			b.add_child(part(box(Vector3(8.0, 0.15, 5.0)), Color("6b4e30"), Vector3(0, 0.08, 0)))
			solid(b, Vector3(3.0, 0.9, 1.0), Vector3(0, 0.45, 0), wood)
			var saw := part(cyl(0.6, 0.6, 0.04), Color("c8c8c8"), Vector3(0, 1.0, 0))
			saw.rotation_degrees.x = 90
			b.add_child(saw)
			for i in 3:
				solid(b, Vector3(0.5, 0.5, 3.0), Vector3(2.8, 0.25 + i * 0.45, -1.0 + (i % 2) * 0.3), Color("8b5a2b"))
			solid(b, Vector3(0.3, 2.4, 0.3), Vector3(-3.8, 1.2, -2.4), wood.darkened(0.3))
			solid(b, Vector3(0.3, 2.4, 0.3), Vector3(3.8, 1.2, -2.4), wood.darkened(0.3))
			solid(b, Vector3(8.0, 0.3, 0.3), Vector3(0, 2.4, -2.4), wood.darkened(0.3))
		"caseta":
			var conc := Color("9a9890")
			b.add_child(part(box(Vector3(5.0, 0.1, 4.0)), Color("7d7b75"), Vector3(0, 0.05, 0)))
			solid(b, Vector3(5.0, 2.4, 0.25), Vector3(0, 1.2, -2.0), conc)
			solid(b, Vector3(0.25, 2.4, 4.0), Vector3(-2.5, 1.2, 0), conc)
			solid(b, Vector3(0.25, 2.4, 4.0), Vector3(2.5, 1.2, 0), conc)
			solid(b, Vector3(1.6, 2.4, 0.25), Vector3(-1.7, 1.2, 2.0), conc)
			solid(b, Vector3(1.6, 2.4, 0.25), Vector3(1.7, 1.2, 2.0), conc)
			solid(b, Vector3(1.6, 0.8, 0.8), Vector3(-1.3, 0.4, -1.3), Color("6b4a2a"))
		"excavadora":
			var yel := Color("c9a227").darkened(0.15)
			solid(b, Vector3(3.2, 1.2, 2.2), Vector3(0, 0.9, 0), yel)
			solid(b, Vector3(1.4, 1.3, 1.6), Vector3(-0.6, 2.1, 0), yel.darkened(0.1))
			b.add_child(part(box(Vector3(1.3, 0.8, 1.62)), Color(0.4, 0.6, 0.7, 0.6), Vector3(-0.6, 2.2, 0)))
			solid(b, Vector3(3.6, 0.6, 0.5), Vector3(0, 0.3, 1.1), Color("2b2b2b"))
			solid(b, Vector3(3.6, 0.6, 0.5), Vector3(0, 0.3, -1.1), Color("2b2b2b"))
			var arm := part(box(Vector3(3.0, 0.35, 0.35)), yel, Vector3(2.6, 1.8, 0))
			arm.rotation_degrees.z = -30
			b.add_child(arm)
			solid(b, Vector3(0.9, 0.8, 1.2), Vector3(3.9, 0.5, 0), Color("7a4a2a"))
		"tunel":
			var rock := Color("7a5a48")
			solid(b, Vector3(3.0, 4.0, 4.0), Vector3(-3.2, 2.0, 0), rock)
			solid(b, Vector3(3.0, 4.0, 4.0), Vector3(3.2, 2.0, 0), rock)
			solid(b, Vector3(9.4, 1.4, 4.0), Vector3(0, 4.0, 0), rock.darkened(0.1))
			solid(b, Vector3(3.4, 4.0, 0.4), Vector3(0, 2.0, -2.0), Color("151210"))
			for x in [-1.5, 1.5]:
				solid(b, Vector3(0.25, 3.3, 0.25), Vector3(x, 1.65, 1.8), Color("6b4a2a"))
			solid(b, Vector3(3.4, 0.3, 0.3), Vector3(0, 3.3, 1.8), Color("6b4a2a"))
	return b


# ------------------------------------------------------------ construcción

static func ghost_mat(ok: bool) -> StandardMaterial3D:
	return mat(Color(0.3, 1.0, 0.4, 0.45) if ok else Color(1.0, 0.25, 0.2, 0.45), 0.6)


static func structure_mesh(kind: String, color: Color) -> Node3D:
	var root := Node3D.new()
	match kind:
		"foundation":
			root.add_child(part(box(Vector3(2.0, 0.12, 2.0)), color, Vector3(0, 0.06, 0)))
			root.add_child(part(box(Vector3(1.9, 0.02, 0.05)), color.darkened(0.25), Vector3(0, 0.125, -0.5)))
			root.add_child(part(box(Vector3(1.9, 0.02, 0.05)), color.darkened(0.25), Vector3(0, 0.125, 0.5)))
		"wall":
			root.add_child(part(box(Vector3(2.0, 2.6, 0.25)), color, Vector3(0, 1.3, 0)))
			root.add_child(part(box(Vector3(2.04, 0.15, 0.3)), color.darkened(0.3), Vector3(0, 2.55, 0)))
		"door":
			root.add_child(part(box(Vector3(0.3, 2.6, 0.3)), color.darkened(0.25), Vector3(0.85, 1.3, 0)))
			root.add_child(part(box(Vector3(0.3, 2.6, 0.3)), color.darkened(0.25), Vector3(-0.85, 1.3, 0)))
			root.add_child(part(box(Vector3(2.0, 0.35, 0.3)), color.darkened(0.25), Vector3(0, 2.43, 0)))
			# Hoja de la puerta: gira sobre la bisagra izquierda.
			var hinge := Node3D.new()
			hinge.name = "Hinge"
			hinge.position = Vector3(-0.7, 0, 0)
			hinge.add_child(part(box(Vector3(1.4, 2.2, 0.12)), color, Vector3(0.7, 1.1, 0)))
			hinge.add_child(part(sphere(0.06), Color("d4b45a"), Vector3(1.2, 1.1, -0.1)))
			root.add_child(hinge)
	return root


static func station_mesh(kind: String, level: int) -> Node3D:
	var made := StationModels.make(kind, level)   # modelos según la lámina de estructuras
	if made != null:
		return made
	var root := Node3D.new()
	var wood := Color("8b5a2b")
	var stone := Color("85837d")
	match kind:
		"banco_trabajo":
			root.add_child(part(box(Vector3(1.7, 0.12, 0.9)), wood, Vector3(0, 0.9, 0)))
			for p in [Vector3(0.75, 0.45, 0.35), Vector3(-0.75, 0.45, 0.35), Vector3(0.75, 0.45, -0.35), Vector3(-0.75, 0.45, -0.35)]:
				root.add_child(part(box(Vector3(0.1, 0.9, 0.1)), wood.darkened(0.3), p))
			root.add_child(part(box(Vector3(0.35, 0.25, 0.25)), Color("7d7f82"), Vector3(-0.5, 1.08, 0)))
			if level >= 2:
				root.add_child(part(box(Vector3(0.5, 0.2, 0.35)), Color("6f7a82"), Vector3(0.45, 1.06, 0)))
		"carpinteria":
			root.add_child(part(box(Vector3(1.8, 0.15, 0.8)), wood, Vector3(0, 0.8, 0)))
			root.add_child(part(box(Vector3(1.6, 0.8, 0.6)), wood.darkened(0.35), Vector3(0, 0.4, 0)))
			var saw := part(cyl(0.35, 0.35, 0.03), Color("c8c8c8"), Vector3(0.2, 0.95, 0))
			saw.rotation_degrees.x = 90
			root.add_child(saw)
			root.add_child(part(box(Vector3(1.4, 0.15, 0.2)), Color("c49a6c"), Vector3(-0.1, 0.95, 0.25)))
		"cantero":
			root.add_child(part(box(Vector3(1.6, 0.8, 1.0)), stone, Vector3(0, 0.4, 0)))
			root.add_child(part(box(Vector3(0.45, 0.35, 0.45)), stone.lightened(0.2), Vector3(0.3, 0.98, 0)))
			root.add_child(part(box(Vector3(0.1, 0.5, 0.1)), wood, Vector3(-0.4, 1.05, 0.1)))
		"hoguera":
			for i in 8:
				var a := TAU * float(i) / 8.0
				root.add_child(part(sphere(0.16), stone, Vector3(cos(a) * 0.55, 0.12, sin(a) * 0.55)))
			var l1 := part(cyl(0.08, 0.08, 0.8), wood, Vector3(0, 0.15, 0))
			l1.rotation_degrees = Vector3(0, 30, 80)
			root.add_child(l1)
			var l2 := part(cyl(0.08, 0.08, 0.8), wood, Vector3(0, 0.15, 0))
			l2.rotation_degrees = Vector3(0, -40, 80)
			root.add_child(l2)
			root.add_child(part(cyl(0.0, 0.25, 0.6), Color(1.0, 0.55, 0.1, 0.85), Vector3(0, 0.45, 0), 3.0))
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.6, 0.3)
			light.omni_range = 5.0
			light.light_energy = 1.2
			light.position = Vector3(0, 1.0, 0)
			root.add_child(light)
		"horno":
			root.add_child(part(box(Vector3(1.4, 1.3, 1.2)), stone.darkened(0.15), Vector3(0, 0.65, 0)))
			root.add_child(part(box(Vector3(0.5, 0.4, 0.05)), Color(1.0, 0.45, 0.1), Vector3(0, 0.45, -0.61), 2.5))
			root.add_child(part(box(Vector3(0.35, 1.0, 0.35)), stone.darkened(0.3), Vector3(0.35, 1.8, 0.3)))
		"mesa_costura":
			root.add_child(part(box(Vector3(1.4, 0.1, 0.8)), wood.lightened(0.15), Vector3(0, 0.85, 0)))
			for p in [Vector3(0.6, 0.42, 0.3), Vector3(-0.6, 0.42, 0.3), Vector3(0.6, 0.42, -0.3), Vector3(-0.6, 0.42, -0.3)]:
				root.add_child(part(box(Vector3(0.08, 0.85, 0.08)), wood.darkened(0.3), p))
			root.add_child(part(cyl(0.1, 0.1, 0.2), Color("c0392b"), Vector3(0.4, 1.0, 0)))
			root.add_child(part(box(Vector3(0.6, 0.03, 0.5)), Color("d9cfb4"), Vector3(-0.25, 0.92, 0)))
		"gimnasio":
			# Pórtico con saco de boxeo a un lado y banco con barra al otro
			for x in [-1.05, -0.15]:
				root.add_child(part(box(Vector3(0.1, 1.9, 0.1)), wood.darkened(0.25), Vector3(x, 0.95, 0.35)))
			root.add_child(part(box(Vector3(1.0, 0.1, 0.1)), wood.darkened(0.25), Vector3(-0.6, 1.9, 0.35)))
			root.add_child(part(cyl(0.015, 0.015, 0.4), Color("3a3a3a"), Vector3(-0.6, 1.65, 0.35)))
			root.add_child(part(cyl(0.2, 0.2, 0.8), Color("7a5a36") if level <= 1 else Color("8a2f25"), Vector3(-0.6, 1.05, 0.35)))
			root.add_child(part(box(Vector3(0.35, 0.1, 1.1)), Color("5b4a3a") if level <= 1 else Color("2f2f33"), Vector3(0.6, 0.45, -0.05)))
			for z in [-0.45, 0.35]:
				root.add_child(part(box(Vector3(0.08, 0.4, 0.08)), wood.darkened(0.3), Vector3(0.6, 0.2, z)))
			for x in [0.3, 0.9]:
				root.add_child(part(box(Vector3(0.05, 0.9, 0.05)), Color("6a6f73"), Vector3(x, 0.45, 0.45)))
			var bar := part(cyl(0.02, 0.02, 1.4), Color("9aa0a4"), Vector3(0.6, 0.9, 0.45))
			bar.rotation_degrees.z = 90
			root.add_child(bar)
			var plate_c := stone.darkened(0.2) if level <= 1 else Color("2b2b2e")
			for x in [0.0, 1.2]:
				var pl := part(cyl(0.2, 0.2, 0.08), plate_c, Vector3(x, 0.9, 0.45))
				pl.rotation_degrees.z = 90
				root.add_child(pl)
		"cofre":
			var c := wood if level <= 1 else Color("6b4a2a")
			root.add_child(part(box(Vector3(1.2, 0.6, 0.7)), c, Vector3(0, 0.3, 0)))
			root.add_child(part(box(Vector3(1.24, 0.22, 0.74)), c.darkened(0.2), Vector3(0, 0.7, 0)))
			root.add_child(part(box(Vector3(0.15, 0.18, 0.05)), Color("d4b45a"), Vector3(0, 0.55, -0.37)))
			if level >= 2:
				root.add_child(part(box(Vector3(1.26, 0.06, 0.76)), Color("6f7a82"), Vector3(0, 0.45, 0)))
	return root


static func base_border(half: float) -> Node3D:
	var root := Node3D.new()
	var c := Color(0.85, 0.8, 0.5, 0.5)
	var w := half * 2.0
	root.add_child(part(box(Vector3(w, 0.03, 0.12)), c, Vector3(0, 0.02, -half)))
	root.add_child(part(box(Vector3(w, 0.03, 0.12)), c, Vector3(0, 0.02, half)))
	root.add_child(part(box(Vector3(0.12, 0.03, w)), c, Vector3(-half, 0.02, 0)))
	root.add_child(part(box(Vector3(0.12, 0.03, w)), c, Vector3(half, 0.02, 0)))
	return root


## Aplica un material a todas las mallas (para la vista previa fantasma).
static func tint(node: Node, m: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = m
	for c in node.get_children():
		tint(c, m)
