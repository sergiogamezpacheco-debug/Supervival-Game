class_name StationModels
## Estructuras del refugio en low poly facetado, a partir de la lámina
## "Estructuras de refugio" del usuario (docs/diseno_estructuras.jpg).
## Todo por código. Cada modelo cabe en una casilla de 2 m y mira hacia -Z.

const WOOD := Color("8a5a32")
const WOOD_D := Color("5e3b1f")
const WOOD_L := Color("b98a5a")
const PLANK := Color("c9a273")
const STONE := Color("8e8c86")
const STONE_D := Color("6b6964")
const METAL := Color("8f989e")
const METAL_D := Color("3d4246")
const FIRE := Color(1.0, 0.55, 0.12)

## Fase de obra a la que pertenecen las piezas que se van creando (ver under_construction).
static var _fase := 0


static func _p(root: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := Nature._p(root, mesh, color, pos, rot_deg * (PI / 180.0), scl)
	m.set_meta("fase", _fase)
	return m


static func _glow(root: Node3D, mesh: Mesh, color: Color, pos: Vector3, energy := 3.0, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var m := Builder.part(mesh, color, pos, energy)
	m.set_meta("fase", _fase)
	m.rotation_degrees = rot_deg
	root.add_child(m)
	return m


static func _box(s: Vector3) -> Mesh:
	return Builder.box(s)


static func _cyl(top: float, bottom: float, h: float, seg := 8) -> Mesh:
	var c := Builder.cyl(top, bottom, h)
	c.radial_segments = seg
	return c


## Palo entre dos puntos.
static func _stick(root: Node3D, a: Vector3, b: Vector3, r: float, color: Color, seg := 6) -> MeshInstance3D:
	var m := _p(root, _cyl(r, r, a.distance_to(b), seg), color, (a + b) / 2.0)
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		var axis := Vector3.UP.cross(dir).normalized()
		m.basis = Basis(axis, Vector3.UP.angle_to(dir))
	return m


static func _light(root: Node3D, pos: Vector3, rng := 5.0, energy := 1.2) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.omni_range = rng
	l.light_energy = energy
	l.position = pos
	root.add_child(l)


static func _rock(root: Node3D, seed_: int, pos: Vector3, s: Vector3, color := STONE) -> void:
	_p(root, Nature.blob(seed_, 0.22, 6, 3), color, pos, Vector3(0, seed_ * 37 % 360, 0), s)


static func _legs(root: Node3D, w: float, d: float, h: float, t: float, color: Color) -> void:
	for x in [-1, 1]:
		for z in [-1, 1]:
			_p(root, _box(Vector3(t, h, t)), color, Vector3(x * (w / 2.0 - t), h / 2.0, z * (d / 2.0 - t)))


static func make(kind: String, level: int) -> Node3D:
	var root := Node3D.new()
	_fase = 0
	match kind:
		"carpinteria": _carpinteria(root)
		"horno": _horno(root)
		"hoguera": _hoguera(root)
		"banco_armas": _banco_armas(root)
		"recolector_agua": _recolector(root)
		"secadero": _secadero(root)
		"huerto": _huerto(root)
		"mesa_medica": _mesa_medica(root)
		"generador": _generador(root)
		"recicladora": _recicladora(root)
		_:
			return null
	_fase = 0
	return root


# ------------------------------------------------------------ carpintería
static func _carpinteria(r: Node3D) -> void:
	_legs(r, 1.7, 0.75, 0.82, 0.1, WOOD_D)
	for z in [-0.22, 0.22]:
		_p(r, _box(Vector3(1.45, 0.07, 0.07)), WOOD_D, Vector3(0, 0.3, z))
	# tablero de tablas sueltas
	for i in 4:
		_p(r, _box(Vector3(1.8, 0.07, 0.2)), WOOD if i % 2 == 0 else WOOD_L, Vector3(0, 0.86, -0.3 + i * 0.2))
	# tablas encima y sierra
	_p(r, _box(Vector3(0.9, 0.04, 0.16)), PLANK, Vector3(-0.35, 0.92, -0.12), Vector3(0, 12, 0))
	_p(r, _box(Vector3(0.6, 0.04, 0.14)), PLANK.darkened(0.08), Vector3(0.45, 0.92, 0.18), Vector3(0, -20, 0))
	_p(r, _box(Vector3(0.62, 0.02, 0.15)), Color("c3c7ca"), Vector3(0.3, 0.95, -0.15), Vector3(0, 25, 0))
	_p(r, _box(Vector3(0.16, 0.06, 0.1)), WOOD_D, Vector3(0.62, 0.96, -0.3), Vector3(0, 25, 0))
	# montón de tablones en el suelo
	for i in 4:
		_p(r, _box(Vector3(0.85, 0.06, 0.16)), PLANK if i % 2 == 0 else WOOD_L, Vector3(0.55 + i * 0.03, 0.03 + i * 0.06, 0.62 - i * 0.05), Vector3(0, -15 + i * 10, 0))


# ------------------------------------------------------- horno de fundición
static func _horno(r: Node3D) -> void:
	for i in 9:
		var a := TAU * float(i) / 9.0
		_rock(r, 40 + i, Vector3(cos(a) * 0.72, 0.1, sin(a) * 0.62), Vector3(0.24, 0.2, 0.22), STONE_D)
	# cúpula de piedra
	_p(r, Nature.blob(7, 0.08, 9, 5), STONE, Vector3(0, 0.55, 0.05), Vector3.ZERO, Vector3(0.68, 0.95, 0.62))
	# bloques marcados en la cúpula
	for k in 3:
		for i in 6:
			var a := TAU * float(i) / 6.0 + k * 0.5
			var y := 0.35 + k * 0.3
			var rr := 0.66 - k * 0.12
			_p(r, _box(Vector3(0.22, 0.13, 0.08)), STONE.lightened(0.08 if (i + k) % 2 == 0 else 0.0), Vector3(cos(a) * rr, y, sin(a) * rr * 0.92 + 0.05), Vector3(0, -rad_to_deg(a) + 90, 0))
	# chimenea abierta arriba
	_p(r, _cyl(0.2, 0.26, 0.2, 8), STONE_D, Vector3(0, 1.38, 0.05))
	_p(r, _cyl(0.14, 0.14, 0.05, 8), Color("1d1a18"), Vector3(0, 1.47, 0.05))
	# boca con fuego
	_p(r, _box(Vector3(0.6, 0.48, 0.2)), Color("2a2220"), Vector3(0, 0.36, -0.55))
	_p(r, _box(Vector3(0.74, 0.1, 0.24)), STONE_D, Vector3(0, 0.65, -0.58))
	for x in [-0.15, 0.0, 0.15]:
		_p(r, _cyl(0.05, 0.05, 0.4, 6), WOOD_D, Vector3(x, 0.2, -0.6), Vector3(90, 0, 0))
	_glow(r, _cyl(0.0, 0.18, 0.32, 6), FIRE, Vector3(0, 0.34, -0.6), 3.0)
	_glow(r, _cyl(0.0, 0.1, 0.22, 6), Color(1.0, 0.85, 0.3), Vector3(0.08, 0.3, -0.62), 3.0)
	_light(r, Vector3(0, 0.5, -0.9), 4.0, 1.0)


# ---------------------------------------------------------------- hoguera
static func _hoguera(r: Node3D) -> void:
	for i in 10:
		var a := TAU * float(i) / 10.0
		_rock(r, 60 + i, Vector3(cos(a) * 0.62, 0.1, sin(a) * 0.62), Vector3(0.18, 0.14, 0.16), Color("b4b1aa"))
	for k in 4:
		var a := k * 0.8
		_stick(r, Vector3(cos(a) * 0.4, 0.06, sin(a) * 0.4), Vector3(-cos(a) * 0.1, 0.3, -sin(a) * 0.1), 0.05, WOOD_D)
	_glow(r, _cyl(0.0, 0.26, 0.6, 6), FIRE, Vector3(0, 0.38, 0), 3.0)
	_glow(r, _cyl(0.0, 0.14, 0.4, 6), Color(1.0, 0.85, 0.3), Vector3(0.05, 0.3, 0.03), 3.0)
	# trípode con olla
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.4
		_stick(r, Vector3(cos(a) * 0.85, 0.0, sin(a) * 0.85), Vector3(0, 1.5, 0), 0.035, WOOD)
	_stick(r, Vector3(0, 1.48, 0), Vector3(0, 1.0, 0), 0.01, Color("2b2b2b"))
	_p(r, _cyl(0.24, 0.18, 0.28, 8), Color("2a2b2d"), Vector3(0, 0.86, 0))
	_p(r, _cyl(0.22, 0.22, 0.02, 8), Color("8fa0a8"), Vector3(0, 0.99, 0))
	_light(r, Vector3(0, 1.0, 0))


# --------------------------------------------------------- banco de armas
static func _banco_armas(r: Node3D) -> void:
	_legs(r, 1.75, 0.85, 0.85, 0.08, Color("6d7174"))
	_p(r, _box(Vector3(1.8, 0.07, 0.9)), Color("9ca1a4"), Vector3(0, 0.88, 0))
	_p(r, _box(Vector3(1.6, 0.04, 0.75)), Color("777c80"), Vector3(0, 0.3, 0))
	_fase = 1
	# cajas en la balda
	_p(r, _box(Vector3(0.5, 0.22, 0.32)), Color("4f5a3a"), Vector3(-0.4, 0.43, 0))
	_p(r, _box(Vector3(0.4, 0.18, 0.28)), Color("8a3b2a"), Vector3(0.35, 0.41, 0.05))
	# rifle encima
	_p(r, _box(Vector3(0.8, 0.06, 0.07)), Color("2b2c2e"), Vector3(-0.1, 0.95, -0.1), Vector3(0, 8, 0))
	_p(r, _box(Vector3(0.36, 0.1, 0.09)), WOOD, Vector3(-0.55, 0.95, -0.15), Vector3(0, 8, 0))
	_p(r, _box(Vector3(0.06, 0.12, 0.05)), Color("2b2c2e"), Vector3(0.05, 0.92, -0.08), Vector3(0, 8, -20))
	# llave, martillo y tornillo de banco
	_p(r, _box(Vector3(0.3, 0.02, 0.05)), Color("c3c7ca"), Vector3(0.5, 0.93, 0.25), Vector3(0, -30, 0))
	_p(r, _box(Vector3(0.28, 0.03, 0.04)), WOOD, Vector3(0.15, 0.93, 0.28), Vector3(0, 15, 0))
	_p(r, _box(Vector3(0.1, 0.06, 0.08)), Color("4a4f53"), Vector3(0.28, 0.95, 0.3), Vector3(0, 15, 0))
	_p(r, _box(Vector3(0.22, 0.16, 0.18)), Color("45607a"), Vector3(0.72, 1.0, -0.25))
	_p(r, _box(Vector3(0.06, 0.06, 0.3)), METAL, Vector3(0.72, 1.0, -0.42))
	# manchas de óxido
	_p(r, _box(Vector3(0.3, 0.005, 0.2)), Color("8a5a3a"), Vector3(-0.6, 0.92, 0.25))


# ------------------------------------------------------ recolector de agua
static func _recolector(r: Node3D) -> void:
	var staves := 10
	_p(r, _cyl(0.5, 0.5, 1.15, staves), WOOD, Vector3(0, 0.6, 0))
	_p(r, _cyl(0.56, 0.56, 0.4, staves), WOOD_L, Vector3(0, 0.6, 0))  # panza
	for y in [0.18, 0.6, 1.02]:
		_p(r, _cyl(0.57 if y == 0.6 else 0.52, 0.57 if y == 0.6 else 0.52, 0.06, staves), Color("4a3a2c"), Vector3(0, y, 0))
	_p(r, _cyl(0.48, 0.48, 0.06, staves), WOOD_L, Vector3(0, 1.19, 0))
	for x in [-0.2, 0.0, 0.2]:
		_p(r, _box(Vector3(0.02, 0.01, 0.9)), WOOD_D, Vector3(x, 1.225, 0))
	# bajante
	_p(r, _box(Vector3(0.1, 1.3, 0.1)), Color("c9cbcc"), Vector3(-0.62, 1.15, 0.1))
	_p(r, _box(Vector3(0.28, 0.1, 0.1)), Color("c9cbcc"), Vector3(-0.5, 0.52, 0.1))
	_p(r, _box(Vector3(0.16, 0.1, 0.1)), Color("c9cbcc"), Vector3(-0.55, 1.78, 0.1), Vector3(0, 0, 30))
	# grifo
	_p(r, _cyl(0.03, 0.03, 0.18, 6), METAL, Vector3(0.2, 0.25, -0.58), Vector3(90, 0, 0))
	_p(r, _box(Vector3(0.05, 0.08, 0.05)), METAL, Vector3(0.2, 0.2, -0.66))


# ------------------------------------------------------------ secadero
static func _secadero(r: Node3D) -> void:
	for x in [-0.8, 0.8]:
		_stick(r, Vector3(x - 0.05, 0, -0.35), Vector3(x + 0.02, 1.7, 0.08), 0.045, WOOD)
		_stick(r, Vector3(x + 0.05, 0, 0.35), Vector3(x - 0.02, 1.7, -0.08), 0.045, WOOD)
	_stick(r, Vector3(-0.95, 1.58, 0), Vector3(0.95, 1.58, 0), 0.04, WOOD_L)
	for i in 5:
		var x := -0.48 + i * 0.24
		_stick(r, Vector3(x, 1.58, 0), Vector3(x, 1.48, 0), 0.008, Color("3a3a3a"))
		var h := 0.42 + (i % 2) * 0.08
		_p(r, _box(Vector3(0.12, h, 0.04)), Color("a8402e"), Vector3(x, 1.46 - h / 2.0, 0), Vector3(0, 0, (i - 2) * 3))
		_p(r, _box(Vector3(0.04, h * 0.8, 0.045)), Color("e3a28a"), Vector3(x + 0.02, 1.46 - h / 2.0, 0), Vector3(0, 0, (i - 2) * 3))


# ---------------------------------------------------------------- huerto
static func _huerto(r: Node3D) -> void:
	for z in [-0.55, 0.55]:
		_p(r, _box(Vector3(1.8, 0.3, 0.08)), WOOD_L if z < 0 else WOOD, Vector3(0, 0.15, z))
	for x in [-0.86, 0.86]:
		_p(r, _box(Vector3(0.08, 0.3, 1.18)), WOOD, Vector3(x, 0.15, 0))
	for x in [-0.86, 0.86]:
		for z in [-0.55, 0.55]:
			_p(r, _box(Vector3(0.1, 0.34, 0.1)), WOOD_D, Vector3(x, 0.17, z))
	_fase = 1
	_p(r, _box(Vector3(1.66, 0.22, 1.04)), Color("4a3324"), Vector3(0, 0.15, 0))
	for i in 6:
		var p := Vector3(-0.55 + (i % 3) * 0.55, 0.27, -0.25 + (i / 3) * 0.5)
		_p(r, _box(Vector3(0.02, 0.1, 0.02)), Color("6aa13a"), p + Vector3(0, 0.03, 0))
		for s in [-1, 1]:
			_p(r, _box(Vector3(0.09, 0.015, 0.05)), Color("7fbf45"), p + Vector3(s * 0.045, 0.09, 0), Vector3(0, 0, s * 25))


# ------------------------------------------------------------ mesa médica
static func _mesa_medica(r: Node3D) -> void:
	for x in [-1, 1]:
		for z in [-1, 1]:
			_p(r, _box(Vector3(0.06, 0.85, 0.06)), Color("d9dcdd"), Vector3(x * 0.72, 0.42, z * 0.38))
	for z in [-0.38, 0.38]:
		_p(r, _box(Vector3(1.4, 0.04, 0.04)), Color("d9dcdd"), Vector3(0, 0.25, z))
	_p(r, _box(Vector3(1.6, 0.06, 0.9)), Color("e2e4e1"), Vector3(0, 0.88, 0))
	# frascos
	_p(r, _cyl(0.07, 0.07, 0.22, 8), Color("cfd6d2"), Vector3(0.2, 1.02, 0.1))
	_p(r, _cyl(0.03, 0.03, 0.05, 6), Color("4a6a5a"), Vector3(0.2, 1.15, 0.1))
	_p(r, _cyl(0.05, 0.05, 0.16, 8), Color("e6e0d0"), Vector3(0.35, 0.99, 0.0))
	_p(r, _box(Vector3(0.1, 0.05, 0.1)), Color("c0392b"), Vector3(0.35, 1.09, 0.0))
	_p(r, _cyl(0.05, 0.05, 0.14, 8), Color("a8c4b8"), Vector3(0.48, 0.98, 0.15))
	# cajas de medicinas
	for b in [[Vector3(-0.5, 0.95, -0.15), 10], [Vector3(-0.3, 0.95, 0.15), -15], [Vector3(-0.1, 0.94, -0.25), 30]]:
		_p(r, _box(Vector3(0.2, 0.1, 0.14)), Color("f7f7f4"), b[0], Vector3(0, b[1], 0))
		_p(r, _box(Vector3(0.21, 0.03, 0.15)), Color("c0392b"), b[0] + Vector3(0, 0.01, 0), Vector3(0, b[1], 0))


# --------------------------------------------------------------- generador
static func _generador(r: Node3D) -> void:
	var frame := Color("2a2c2e")
	# bastidor de tubo
	for x in [-0.55, 0.55]:
		for z in [-0.35, 0.35]:
			_p(r, _box(Vector3(0.05, 0.85, 0.05)), frame, Vector3(x, 0.425, z))
		_p(r, _box(Vector3(0.05, 0.05, 0.75)), frame, Vector3(x, 0.85, 0))
		_p(r, _box(Vector3(0.05, 0.05, 0.75)), frame, Vector3(x, 0.05, 0))
	for z in [-0.35, 0.35]:
		_p(r, _box(Vector3(1.15, 0.05, 0.05)), frame, Vector3(0, 0.05, z))
	# motor
	_fase = 1
	_p(r, _box(Vector3(0.8, 0.42, 0.5)), Color("3b3e41"), Vector3(0, 0.3, 0))
	for i in 5:
		_p(r, _cyl(0.12, 0.12, 0.03, 8), Color("8c9196"), Vector3(-0.15 + i * 0.07, 0.36, -0.26), Vector3(90, 0, 0))
	_p(r, _cyl(0.1, 0.1, 0.12, 8), Color("b9bec2"), Vector3(0.3, 0.3, -0.28), Vector3(90, 0, 0))
	# depósito crema arriba
	_fase = 2
	_p(r, _box(Vector3(1.0, 0.24, 0.62)), Color("e6dcc4"), Vector3(0, 0.66, 0))
	_p(r, _box(Vector3(0.96, 0.04, 0.58)), Color("cfc4aa"), Vector3(0, 0.79, 0))
	_p(r, _cyl(0.06, 0.06, 0.06, 8), Color("3b3e41"), Vector3(-0.2, 0.84, 0.05))
	_p(r, _box(Vector3(0.22, 0.12, 0.04)), Color("2a2c2e"), Vector3(0.3, 0.66, -0.32))
	_glow(r, _box(Vector3(0.04, 0.04, 0.02)), Color(0.4, 1.0, 0.4), Vector3(0.35, 0.68, -0.345), 2.0)
	# escape
	_p(r, _cyl(0.06, 0.06, 0.32, 8), Color("c3c7ca"), Vector3(0.3, 0.98, 0.1))
	_p(r, _cyl(0.075, 0.075, 0.06, 8), Color("9aa0a4"), Vector3(0.3, 1.16, 0.1))


# -------------------------------------------------------------- recicladora
static func _recicladora(r: Node3D) -> void:
	var g := Color("8a8f93")
	var gd := Color("5f6468")
	for x in [-0.35, 0.35]:
		for z in [-0.35, 0.35]:
			_p(r, _box(Vector3(0.08, 1.15, 0.08)), gd, Vector3(x, 0.575, z + 0.15))
	_p(r, _box(Vector3(0.8, 0.12, 0.8)), g, Vector3(0, 1.1, 0.15))
	_fase = 1
	# tolva (pirámide invertida)
	_p(r, _cyl(0.72, 0.36, 0.55, 4), Color("9ea3a6"), Vector3(0, 1.45, 0.15), Vector3(0, 45, 0))
	_p(r, _cyl(0.68, 0.68, 0.02, 4), Color("2c2f31"), Vector3(0, 1.72, 0.15), Vector3(0, 45, 0))
	# cuerpo y bloques a un lado
	_p(r, _box(Vector3(0.6, 0.5, 0.6)), Color("a3a8ab"), Vector3(0, 0.75, 0.15))
	for i in 3:
		_p(r, _box(Vector3(0.22, 0.2, 0.18)), Color("b9b4aa"), Vector3(0.45, 0.55 + (i % 2) * 0.21, -0.05 + i * 0.2))
	_fase = 2
	# cinta inclinada hacia delante
	var belt := _p(r, _box(Vector3(0.4, 0.06, 1.0)), Color("33363a"), Vector3(0, 0.42, -0.5), Vector3(-25, 0, 0))
	belt.name = "cinta"
	for x in [-0.22, 0.22]:
		_p(r, _box(Vector3(0.04, 0.12, 1.02)), gd, Vector3(x, 0.44, -0.5), Vector3(-25, 0, 0))
	_p(r, _cyl(0.07, 0.07, 0.46, 8), Color("2a2c2e"), Vector3(0, 0.2, -0.95), Vector3(0, 0, 90))
	# montón de restos a la salida
	var cols := [Color("c0583c"), Color("d7d2c4"), Color("7f8a90"), Color("a74a36"), Color("e0d8c8")]
	for i in 14:
		var a := float(i) * 2.4
		var d := 0.08 + float(i % 5) * 0.06
		_p(r, _box(Vector3(0.14, 0.03, 0.1)), cols[i % cols.size()], Vector3(0.45 + cos(a) * d, 0.03 + (i % 3) * 0.02, -0.75 + sin(a) * d), Vector3(i * 13 % 40 - 20, i * 47 % 180, i * 11 % 30))


# --------------------------------------------------------- obra a medias
## Muestra solo lo construido (las piezas de las fases hechas) dentro de un andamio.
## Si el modelo no marca fases, enseña una parte proporcional.
static func under_construction(visual: Node3D, done: int, total: int, size: Vector3) -> Node3D:
	var root := Node3D.new()
	var kids := visual.get_children()
	var marked := false
	for k in kids:
		if int(k.get_meta("fase", 0)) > 0:
			marked = true
	var n_show := maxi(1, int(ceil(kids.size() * float(done) / maxf(total, 1.0) * 0.85)))
	for i in kids.size():
		var hide := int(kids[i].get_meta("fase", 0)) >= done if marked else i >= n_show
		if hide:
			(kids[i] as Node).queue_free()
	root.add_child(visual)
	var sx := size.x / 2.0 + 0.12
	var sz := size.z / 2.0 + 0.12
	var h := maxf(size.y, 1.0) + 0.25
	var sc := Color("c8a46e")
	for x in [-sx, sx]:
		for z in [-sz, sz]:
			_stick(root, Vector3(x, 0, z), Vector3(x, h, z), 0.035, sc)
	for z in [-sz, sz]:
		_stick(root, Vector3(-sx, h, z), Vector3(sx, h, z), 0.03, sc)
		_stick(root, Vector3(-sx, 0.1, z), Vector3(sx, h * 0.8, z), 0.025, sc)
	for x in [-sx, sx]:
		_stick(root, Vector3(x, h, -sz), Vector3(x, h, sz), 0.03, sc)
	# cinta de obra
	_p(root, _box(Vector3(sx * 2.0, 0.05, 0.01)), Color("e8b84a"), Vector3(0, 0.55, -sz))
	root.set_meta("en_obra", true)
	return root
