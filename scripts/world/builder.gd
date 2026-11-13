class_name Builder
extends RefCounted
## Modelos provisionales hechos con primitivas. Se sustituirán por modelos .glb
## sin tocar la lógica: basta con cambiar la función correspondiente.

static var _mats: Dictionary = {}


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
			root.add_child(part(cyl(0.18, 0.25, 1.2), Color("6b4423"), Vector3(0, 0.6, 0)))
			root.add_child(part(cyl(0.0, 1.1, 1.6), Color("2f6b34"), Vector3(0, 1.8, 0)))
			root.add_child(part(cyl(0.0, 0.8, 1.3), Color("3a7d3f"), Vector3(0, 2.6, 0)))
		"roca":
			var r := part(sphere(0.8, 1.0), Color("7d7f82"), Vector3(0, 0.35, 0))
			r.scale = Vector3(1.0, 0.8, 0.85)
			root.add_child(r)
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
	root.add_child(part(cyl(0.04, 0.04, 0.9), Color("8b5a2b"), Vector3(0, 0, -0.2)))
	match item_id:
		"hacha_piedra":
			root.add_child(part(box(Vector3(0.08, 0.25, 0.22)), Color("8a8c8f"), Vector3(0, 0.35, -0.3)))
		"pico_piedra":
			root.add_child(part(box(Vector3(0.08, 0.1, 0.5)), Color("8a8c8f"), Vector3(0, 0.4, -0.2)))
		"lanza":
			root.add_child(part(cyl(0.0, 0.06, 0.25), Color("cfc29a"), Vector3(0, 0.55, -0.2)))
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
