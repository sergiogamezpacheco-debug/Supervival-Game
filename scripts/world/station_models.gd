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


## Pieza transparente (cristal, vapor): color con alfa.
static func _clear(root: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := Builder.part(mesh, color, pos)
	m.set_meta("fase", _fase)
	m.rotation_degrees = rot_deg
	m.scale = scl
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		"compostadora": _compostadora(root)
		"mesa_medica": _mesa_medica(root)
		"generador": _generador(root)
		"recicladora": _recicladora(root)
		"cocina": _cocina(root)
		"destileria": _destileria(root, level)
		"mesa_quimica": _mesa_quimica(root)
		"banco_electronica": _banco_electronica(root)
		"almacenamiento": _almacenamiento(root)
		"puesto_mercader": _puesto(root, false)
		"puesto_armero": _puesto(root, true)
		"caja_suministros": _caja_suministros(root)
		"baul_madera": _baul(root, false)
		"cofre_reforzado": _baul(root, true)
		"estanteria_madera": _estanteria_madera(root)
		"estanteria_taller": _estanteria_metal(root, true)
		"estanteria_industrial": _estanteria_metal(root, false)
		"armario_madera": _armario_madera(root)
		"armario_metal": _armario_metal(root)
		"armario_reforzado": _armario_reforzado(root)
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


# ----------------------------------------------------------- compostadora
## Cajón de listones con huecos, montón de compost oscuro con restos y la tapa apoyada al lado.
static func _compostadora(r: Node3D) -> void:
	var h := 0.9
	for x in [-0.55, 0.55]:
		for z in [-0.55, 0.55]:
			_p(r, _box(Vector3(0.1, h + 0.06, 0.1)), WOOD_D, Vector3(x, (h + 0.06) / 2.0, z))
	for k in 5:
		var y := 0.1 + k * 0.18
		for z in [-0.55, 0.55]:
			_p(r, _box(Vector3(1.12, 0.12, 0.05)), WOOD_L if k % 2 == 0 else WOOD, Vector3(0, y, z))
		for x in [-0.55, 0.55]:
			_p(r, _box(Vector3(0.05, 0.12, 1.12)), WOOD if k % 2 == 0 else WOOD_L, Vector3(x, y, 0))
	# compost: tierra oscura con restos de comida y hojas
	_p(r, _box(Vector3(1.02, 0.7, 1.02)), Color("3b2a1e"), Vector3(0, 0.38, 0))
	_p(r, Nature.blob(61, 0.25, 7, 4), Color("4a3424"), Vector3(0, 0.74, 0), Vector3.ZERO, Vector3(0.48, 0.16, 0.48))
	var bits := [Color("6d8a3a"), Color("a8763a"), Color("8a3b26"), Color("c9b25a"), Color("5f7a30")]
	for k in 9:
		var a := float(k) * 2.4
		var d := 0.12 + float(k % 3) * 0.11
		_p(r, _box(Vector3(0.1, 0.03, 0.06)), bits[k % bits.size()], Vector3(cos(a) * d, 0.8 + float(k % 2) * 0.03, sin(a) * d), Vector3(0, a * 40.0, 10))
	# montón de compost caído delante, en una esquina (como en el diseño)
	_p(r, Nature.blob(62, 0.25, 7, 4), Color("3b2a1e"), Vector3(0.45, 0.08, -0.72), Vector3.ZERO, Vector3(0.32, 0.18, 0.24))
	_p(r, Nature.blob(63, 0.25, 6, 3), Color("4a3424"), Vector3(0.62, 0.05, -0.62), Vector3.ZERO, Vector3(0.14, 0.08, 0.12))


# ------------------------------------------------------------ puestos de La Atalaya
## Puesto de mercado: mostrador, toldo de rayas y el comerciante detrás. El del armero lleva
## un armero de pared con armas; el del mercader, sacos, cestas y latas.
static func _puesto(r: Node3D, armero: bool) -> void:
	var cloth_a := Color("a8432e") if armero else Color("c9a24a")
	var cloth_b := Color("e8e0c8")
	_p(r, _box(Vector3(2.4, 0.95, 0.7)), WOOD, Vector3(0, 0.48, 0))
	_p(r, _box(Vector3(2.5, 0.07, 0.8)), WOOD_D, Vector3(0, 0.98, 0))
	for k in 3:
		_p(r, _box(Vector3(2.41, 0.02, 0.71)), WOOD_D, Vector3(0, 0.2 + k * 0.25, 0))
	for x in [-1.25, 1.25]:
		for z in [-0.35, 1.3]:
			_p(r, _box(Vector3(0.12, 2.5, 0.12)), WOOD_D, Vector3(x, 1.25, z))
	for k in 7:   # toldo de rayas, inclinado hacia delante
		var st := _p(r, _box(Vector3(0.39, 0.05, 2.0)), cloth_a if k % 2 == 0 else cloth_b, Vector3(-1.17 + k * 0.39, 2.45, 0.45))
		st.rotation_degrees.x = -12.0
	for k in 7:   # faldón del toldo
		_p(r, _box(Vector3(0.39, 0.22, 0.03)), cloth_a if k % 2 == 0 else cloth_b, Vector3(-1.17 + k * 0.39, 2.12, -0.56))
	if armero:
		# armero de pared detrás y lo que hay en el mostrador
		_p(r, _box(Vector3(2.2, 1.6, 0.08)), WOOD_D, Vector3(0, 1.4, 1.35))
		for k in 4:
			var x := -0.8 + k * 0.53
			_stick(r, Vector3(x, 0.8, 1.28), Vector3(x + 0.05, 2.0, 1.28), 0.025, WOOD_L)
			_p(r, _box(Vector3(0.08, 0.2, 0.03)), METAL, Vector3(x + 0.05, 2.05, 1.27))
		_p(r, _box(Vector3(0.6, 0.06, 0.12)), METAL, Vector3(-0.6, 1.05, -0.05), Vector3(0, 20, 0))
		_p(r, _box(Vector3(0.14, 0.06, 0.1)), WOOD_D, Vector3(-0.92, 1.05, -0.17), Vector3(0, 20, 0))
		_p(r, _cyl(0.22, 0.22, 0.05, 10), Color("6a6f73"), Vector3(0.5, 1.04, 0.0))
		_p(r, _box(Vector3(0.3, 0.2, 0.25)), Color("4b4d3f"), Vector3(0.9, 1.12, 0.05))
	else:
		for k in 3:   # sacos y cestas
			_p(r, Nature.blob(80 + k, 0.25, 7, 4), Color("c9b27a").darkened(0.1 * k), Vector3(-0.8 + k * 0.45, 1.15, 0.05), Vector3.ZERO, Vector3(0.18, 0.2, 0.16))
		_p(r, _cyl(0.22, 0.16, 0.18, 10), Color("8a6440"), Vector3(0.45, 1.1, 0.0))
		for k in 5:
			_p(r, _box(Vector3(0.1, 0.1, 0.1)), [Color("c43a2e"), Color("5f8a3a"), Color("d8a24a")][k % 3], Vector3(0.36 + (k % 3) * 0.09, 1.22, -0.05 + (k / 3) * 0.09))
		for k in 4:
			_p(r, _cyl(0.06, 0.06, 0.14, 8), Color("b8b8b0"), Vector3(0.85 + (k % 2) * 0.14, 1.08, -0.05 + (k / 2) * 0.14))
		_p(r, _box(Vector3(0.8, 0.5, 0.5)), Color("a0703f"), Vector3(-0.7, 0.25, 1.0))
		_p(r, _box(Vector3(0.6, 0.4, 0.45)), Color("c79a62"), Vector3(0.7, 0.2, 1.05))
	var npc := Npc.new("armero" if armero else "mercader")
	npc.position = Vector3(0, 0, 0.75)
	r.add_child(npc)


# ------------------------------------------------------------ almacenaje
# Según las láminas docs/diseno_est_almacen_*.jpg (baúles, estanterías, armarios).
const IRON := Color("4a4c4f")
const RIVET := Color("8c8f92")
const CARD := Color("c79a62")


## Taller de almacenamiento: banco con un baúl a medio hacer, tablones y una estantería detrás.
static func _almacenamiento(r: Node3D) -> void:
	_p(r, _box(Vector3(1.75, 0.1, 0.85)), WOOD, Vector3(0, 0.82, 0.02))
	_legs(r, 1.7, 0.8, 0.8, 0.09, WOOD_D)
	_p(r, _box(Vector3(1.6, 0.05, 0.7)), WOOD_D, Vector3(0, 0.25, 0.02))
	# baúl a medio hacer: la caja sin tapa y la tapa curva apoyada al lado
	_p(r, _box(Vector3(0.62, 0.34, 0.42)), PLANK, Vector3(-0.35, 1.04, 0.05))
	_p(r, _box(Vector3(0.54, 0.3, 0.34)), WOOD_D.darkened(0.3), Vector3(-0.35, 1.07, 0.05))
	for x in [-0.6, -0.1]:
		_p(r, _box(Vector3(0.05, 0.36, 0.44)), IRON, Vector3(x, 1.05, 0.05))
	_p(r, _cyl(0.22, 0.22, 0.6, 10), PLANK.darkened(0.1), Vector3(0.35, 0.92, -0.2), Vector3(0, 0, 90), Vector3(0.55, 1, 1))
	# tablones apilados en el suelo y un martillo
	for k in 3:
		_p(r, _box(Vector3(0.9, 0.06, 0.16)), WOOD_L if k % 2 == 0 else PLANK, Vector3(0.3, 0.03 + k * 0.065, -0.55 + k * 0.02), Vector3(0, 6 * k, 0))
	_p(r, _box(Vector3(0.05, 0.05, 0.32)), WOOD_D, Vector3(0.6, 0.9, 0.15), Vector3(0, 30, 0))
	_p(r, _box(Vector3(0.12, 0.06, 0.05)), IRON, Vector3(0.66, 0.92, 0.04), Vector3(0, 30, 0))
	# estantería baja detrás con cajas
	_p(r, _box(Vector3(1.7, 0.06, 0.3)), WOOD, Vector3(0, 1.5, 0.3))
	for x in [-0.83, 0.83]:
		_p(r, _box(Vector3(0.06, 0.75, 0.06)), WOOD_D, Vector3(x, 1.25, 0.3))
	_p(r, _box(Vector3(0.3, 0.24, 0.24)), CARD, Vector3(-0.5, 1.65, 0.3))
	_p(r, _box(Vector3(0.26, 0.2, 0.22)), CARD.darkened(0.1), Vector3(0.1, 1.63, 0.3))
	_p(r, _box(Vector3(0.22, 0.18, 0.2)), WOOD_L, Vector3(0.55, 1.62, 0.3))


## Caja de suministros: tablones con travesaños en diagonal y cuerda cruzada.
static func _caja_suministros(r: Node3D) -> void:
	var c := Color("a0703f")
	_p(r, _box(Vector3(0.96, 0.76, 0.76)), c, Vector3(0, 0.38, 0))
	for k in 3:   # juntas de los tablones
		_p(r, _box(Vector3(0.97, 0.015, 0.77)), c.darkened(0.35), Vector3(0, 0.13 + k * 0.25, 0))
	for z in [-0.385, 0.385]:   # marco y diagonal de las caras
		for y in [0.03, 0.73]:
			_p(r, _box(Vector3(0.98, 0.07, 0.03)), c.darkened(0.15), Vector3(0, y, z))
		for x in [-0.46, 0.46]:
			_p(r, _box(Vector3(0.07, 0.76, 0.03)), c.darkened(0.15), Vector3(x, 0.38, z))
		_p(r, _box(Vector3(1.12, 0.07, 0.03)), c.darkened(0.15), Vector3(0, 0.38, z), Vector3(0, 0, 37))
	var rope := Color("c9b27a")
	for x in [-0.15, 0.15]:   # cuerda: dos vueltas en cada sentido
		_p(r, _box(Vector3(0.03, 0.8, 0.8)), rope, Vector3(x, 0.38, 0))
	for z in [-0.12, 0.12]:
		_p(r, _box(Vector3(1.0, 0.8, 0.03)), rope, Vector3(0, 0.38, z))
	_p(r, _box(Vector3(0.12, 0.05, 0.1)), rope.darkened(0.1), Vector3(0.15, 0.79, -0.12))


## Baúl de madera (tapa curva, flejes, esquinas y remaches) y cofre reforzado (más oscuro, más flejes).
static func _baul(r: Node3D, reforzado: bool) -> void:
	var wood := Color("6e4626") if reforzado else Color("a06a3a")
	var w := 1.3 if not reforzado else 1.36
	_p(r, _box(Vector3(w, 0.56, 0.76)), wood, Vector3(0, 0.3, 0))
	for k in 3:
		_p(r, _box(Vector3(w + 0.01, 0.015, 0.77)), wood.darkened(0.35), Vector3(0, 0.14 + k * 0.15, 0))
	_p(r, _cyl(0.38, 0.38, w, 12), wood.lightened(0.05), Vector3(0, 0.58, 0), Vector3(0, 0, 90), Vector3(0.6, 1, 1))
	var bands := [-w / 2.0 + 0.04, w / 2.0 - 0.04]
	if reforzado:
		bands += [-w / 6.0, w / 6.0]
	for x in bands:
		_p(r, _box(Vector3(0.08, 0.58, 0.8)), IRON, Vector3(x, 0.3, 0))
		_p(r, _cyl(0.395, 0.395, 0.08, 12), IRON, Vector3(x, 0.58, 0), Vector3(0, 0, 90), Vector3(0.6, 1, 1))
		for y in [0.1, 0.3, 0.5]:   # remaches
			_p(r, _box(Vector3(0.03, 0.03, 0.02)), RIVET, Vector3(x, y, -0.405))
	_p(r, _box(Vector3(w + 0.02, 0.07, 0.8)), IRON, Vector3(0, 0.57, 0))
	_p(r, _box(Vector3(w + 0.02, 0.06, 0.8)), IRON, Vector3(0, 0.03, 0))
	_p(r, _box(Vector3(0.2, 0.24, 0.05)), IRON.lightened(0.15), Vector3(0, 0.5, -0.41))
	_p(r, _box(Vector3(0.05, 0.08, 0.03)), Color("1c1c1c"), Vector3(0, 0.48, -0.44))
	for x in [-1.0, 1.0]:   # asas laterales
		_p(r, _box(Vector3(0.04, 0.08, 0.26)), IRON, Vector3(x * (w / 2.0 + 0.03), 0.4, 0))


static func _boxes_on(r: Node3D, y: float, w: float, seed_: int) -> void:
	var cols := [CARD, CARD.darkened(0.12), Color("5f6b3a"), Color("6a6f73"), Color("8a3b2a"), CARD.lightened(0.08)]
	var x := -w / 2.0 + 0.08
	var k := seed_
	while x < w / 2.0 - 0.2:
		var bw := 0.18 + float(k % 3) * 0.07
		var bh := 0.14 + float((k * 7) % 4) * 0.035
		_p(r, _box(Vector3(bw, bh, 0.3)), cols[k % cols.size()], Vector3(x + bw / 2.0, y + bh / 2.0, 0.02))
		x += bw + 0.05
		k += 1


## Estantería de madera: cuatro baldas con cajas y botes, y tres cajas de madera encima.
static func _estanteria_madera(r: Node3D) -> void:
	var w := 1.3
	for x in [-w / 2.0, w / 2.0]:
		for z in [-0.22, 0.22]:
			_p(r, _box(Vector3(0.06, 2.0, 0.06)), WOOD_D, Vector3(x, 1.0, z))
	for k in 4:
		var y := 0.12 + k * 0.5
		_p(r, _box(Vector3(w + 0.06, 0.05, 0.5)), WOOD, Vector3(0, y, 0))
		if k < 3:
			_boxes_on(r, y + 0.025, w, k * 3 + 1)
	for k in 3:   # cajas de madera arriba
		var c := _p(r, _box(Vector3(0.36, 0.3, 0.36)), Color("9a6a3a"), Vector3(-0.42 + k * 0.42, 1.8, 0))
		_p(r, _box(Vector3(0.37, 0.04, 0.37)), Color("6e4626"), Vector3(-0.42 + k * 0.42, 1.95, 0))
		c.rotation_degrees.y = (k - 1) * 4.0


## Estanterías de metal: la industrial (gris, con aspas laterales y una caja naranja) y la de taller
## (bastidor oscuro con rojo, balda de chapa y madera y herramientas abajo).
static func _estanteria_metal(r: Node3D, taller: bool) -> void:
	var w := 1.4
	var post := Color("3c4044") if taller else Color("767c80")
	var shelf := Color("9aa0a4")
	var h := 1.6 if taller else 1.9
	for x in [-w / 2.0, w / 2.0]:
		for z in [-0.25, 0.25]:
			_p(r, _box(Vector3(0.07, h, 0.07)), post, Vector3(x, h / 2.0, z))
			if taller:
				_p(r, _box(Vector3(0.075, 0.08, 0.075)), Color("a2312a"), Vector3(x, 0.04, z))
		# aspa del lateral
		_stick(r, Vector3(x, 0.2, -0.25), Vector3(x, h - 0.3, 0.25), 0.015, post)
		_stick(r, Vector3(x, 0.2, 0.25), Vector3(x, h - 0.3, -0.25), 0.015, post)
	var levels := [0.25, 0.85, 1.45] if taller else [0.2, 0.75, 1.3, 1.85]
	for k in levels.size():
		var y: float = levels[k]
		var mat := shelf if (not taller or k == levels.size() - 1) else Color("8a6440")
		_p(r, _box(Vector3(w + 0.08, 0.05, 0.56)), mat, Vector3(0, y, 0))
		if taller:
			_p(r, _box(Vector3(w + 0.1, 0.06, 0.03)), Color("a2312a"), Vector3(0, y, -0.29))
	if taller:
		for k in 3:   # tablones y herramientas
			_p(r, _box(Vector3(0.9, 0.05, 0.14)), WOOD_L, Vector3(-0.15, 0.3 + k * 0.05, -0.05 + k * 0.03), Vector3(0, k * 5, 0))
		_p(r, _box(Vector3(0.3, 0.16, 0.2)), Color("6a6f73"), Vector3(0.1, 0.95, 0))
		_p(r, _box(Vector3(0.04, 0.04, 0.3)), WOOD_D, Vector3(-0.45, 0.9, 0), Vector3(0, 70, 0))
	else:
		_p(r, _box(Vector3(0.36, 0.26, 0.3)), Color("d08a2e"), Vector3(-0.35, 2.0, 0))
		_p(r, _box(Vector3(0.36, 0.03, 0.3)), Color("8a5a1e"), Vector3(-0.35, 2.13, 0))


## Armario de madera: tablones verticales, dos puertas con tiradores y tapa que sobresale.
static func _armario_madera(r: Node3D) -> void:
	var wood := Color("8e6238")
	_p(r, _box(Vector3(1.1, 1.86, 0.58)), wood, Vector3(0, 0.95, 0))
	_p(r, _box(Vector3(1.24, 0.08, 0.68)), wood.lightened(0.06), Vector3(0, 1.92, -0.02))
	for k in 6:   # tablones de las puertas
		var x := -0.46 + k * 0.184
		_p(r, _box(Vector3(0.17, 1.74, 0.03)), wood.lightened(0.04 * (k % 2)), Vector3(x, 0.96, -0.3))
	_p(r, _box(Vector3(0.02, 1.74, 0.04)), wood.darkened(0.4), Vector3(0, 0.96, -0.31))
	for x in [-0.08, 0.08]:
		_p(r, _box(Vector3(0.03, 0.2, 0.04)), IRON, Vector3(x, 1.0, -0.34))
	for x in [-0.5, 0.5]:
		_p(r, _box(Vector3(0.08, 0.1, 0.5)), wood.darkened(0.3), Vector3(x, 0.05, 0))


## Armario de metal: dos taquillas grises con rejillas y tiradores.
static func _armario_metal(r: Node3D) -> void:
	var paint := Color("8c9399")
	_p(r, _box(Vector3(1.1, 1.86, 0.52)), paint, Vector3(0, 0.96, 0))
	_p(r, _box(Vector3(1.12, 0.06, 0.54)), paint.darkened(0.3), Vector3(0, 0.03, 0))
	for x in [-0.275, 0.275]:
		_p(r, _box(Vector3(0.51, 1.74, 0.03)), paint.lightened(0.08), Vector3(x, 0.97, -0.265))
		for k in 4:
			_p(r, _box(Vector3(0.28, 0.022, 0.02)), paint.darkened(0.45), Vector3(x, 1.6 + k * 0.06, -0.285))
		_p(r, _box(Vector3(0.035, 0.18, 0.04)), METAL_D, Vector3(x + (0.19 if x < 0 else -0.19), 1.0, -0.29))


## Armario reforzado: madera gruesa con marco y esquinas de hierro, bisagras y patas.
static func _armario_reforzado(r: Node3D) -> void:
	var wood := Color("7a5030")
	_p(r, _box(Vector3(1.3, 1.8, 0.68)), wood, Vector3(0, 1.02, 0))
	for k in 7:
		_p(r, _box(Vector3(0.17, 1.66, 0.03)), wood.lightened(0.05 * (k % 2)), Vector3(-0.54 + k * 0.18, 1.02, -0.35))
	for x in [-0.66, 0.66]:   # marco de hierro y patas
		for z in [-0.35, 0.35]:
			_p(r, _box(Vector3(0.08, 2.0, 0.08)), IRON, Vector3(x, 1.0, z))
	for y in [0.14, 1.0, 1.9]:
		_p(r, _box(Vector3(1.4, 0.08, 0.04)), IRON, Vector3(0, y, -0.37))
	for y in [0.5, 1.5]:   # bisagras y cierre
		_p(r, _box(Vector3(0.16, 0.06, 0.03)), RIVET, Vector3(-0.56, y, -0.38))
		_p(r, _box(Vector3(0.16, 0.06, 0.03)), RIVET, Vector3(0.56, y, -0.38))
	_p(r, _box(Vector3(0.12, 0.16, 0.05)), IRON.lightened(0.2), Vector3(0, 1.05, -0.4))


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


# ------------------------------------------------------- cocina de campo
## Hornillo de camping con mampara plegada, olla humeante y plato (diseño de la cocina).
static func _cocina(r: Node3D) -> void:
	var body := Color("6d6a64")
	var dark := Color("3e3c39")
	# patas de tijera
	for x in [-0.5, 0.5]:
		for z in [-0.28, 0.28]:
			_p(r, _box(Vector3(0.05, 0.62, 0.05)), dark, Vector3(x, 0.31, z))
	_p(r, _box(Vector3(1.05, 0.04, 0.04)), dark, Vector3(0, 0.2, -0.28))
	_p(r, _box(Vector3(1.05, 0.04, 0.04)), dark, Vector3(0, 0.2, 0.28))
	# cuerpo del hornillo y rejilla
	_p(r, _box(Vector3(1.15, 0.16, 0.66)), body, Vector3(0, 0.7, 0))
	_p(r, _box(Vector3(1.1, 0.02, 0.6)), Color("4a4845"), Vector3(0, 0.79, 0))
	for i in 5:
		_p(r, _box(Vector3(1.05, 0.025, 0.025)), Color("2c2b29"), Vector3(0, 0.81, -0.24 + i * 0.12))
	for x in [-0.27, 0.27]:
		_p(r, _cyl(0.12, 0.13, 0.03, 10), Color("2c2b29"), Vector3(x, 0.8, 0))
		_glow(r, _cyl(0.09, 0.09, 0.01, 10), Color(0.35, 0.55, 1.0), Vector3(x, 0.815, 0), 2.0)
	# mandos delante
	for x in [-0.3, 0.3]:
		_p(r, _cyl(0.04, 0.04, 0.04, 8), Color("1f1e1d"), Vector3(x, 0.7, -0.35), Vector3(90, 0, 0))
	# mampara: tapa de atrás levantada y alas
	_p(r, _box(Vector3(1.15, 0.5, 0.03)), body.lightened(0.08), Vector3(0, 1.05, 0.36), Vector3(-12, 0, 0))
	for x in [-0.59, 0.59]:
		_p(r, _box(Vector3(0.03, 0.3, 0.62)), body.lightened(0.04), Vector3(x, 0.93, 0.02))
	# olla con guiso
	_p(r, _cyl(0.2, 0.19, 0.24, 10), Color("57595c"), Vector3(-0.27, 0.95, 0))
	_p(r, _cyl(0.17, 0.17, 0.02, 10), Color("b8602e"), Vector3(-0.27, 1.05, 0))
	_p(r, _box(Vector3(0.22, 0.03, 0.04)), Color("3a3b3d"), Vector3(-0.53, 1.03, 0))
	# vapor
	for k in 3:
		_clear(r, Nature.blob(80 + k, 0.2, 6, 3), Color(0.95, 0.95, 0.93, 0.35), Vector3(-0.27 + k * 0.04, 1.14 + k * 0.1, 0.0), Vector3.ZERO, Vector3.ONE * (0.06 + k * 0.02))
	# plato con comida
	_p(r, _cyl(0.17, 0.13, 0.04, 10), Color("e9e4d8"), Vector3(0.27, 0.85, 0))
	for k in 5:
		var a := float(k) * 1.26
		_p(r, Nature.blob(90 + k, 0.25, 5, 3), [Color("8a3b26"), Color("d88a2e"), Color("6d8a3a")][k % 3], Vector3(0.27 + cos(a) * 0.07, 0.89, sin(a) * 0.07), Vector3.ZERO, Vector3.ONE * 0.06)


# ------------------------------------------------------------- destilería
## Alambique de cobre sobre peana: caldera con fuego de cristal, cuello, serpentín y colector.
static func _destileria(r: Node3D, level: int) -> void:
	var copper := Color("b8693a")
	var copper_d := Color("7f4424")
	var wood := Color("5d4a3c")
	_p(r, _cyl(0.72, 0.76, 0.12, 12), wood, Vector3(0, 0.06, 0))
	_p(r, _cyl(0.6, 0.66, 0.08, 12), wood.lightened(0.1), Vector3(0, 0.16, 0))
	# hogar de cristal con la llama dentro y patas
	for i in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		_p(r, _box(Vector3(0.04, 0.5, 0.04)), Color("2d2622"), Vector3(-0.18 + cos(a) * 0.28, 0.43, sin(a) * 0.28))
	_clear(r, _cyl(0.28, 0.3, 0.42, 8), Color(0.75, 0.85, 0.85, 0.3), Vector3(-0.18, 0.42, 0))
	_glow(r, Nature.blob(5, 0.1, 6, 4), Color(1.0, 0.92, 0.7), Vector3(-0.18, 0.32, 0), 2.6).scale = Vector3.ONE * 0.16
	_light(r, Vector3(-0.18, 0.5, -0.3), 4.0, 0.9)
	# caldera de cobre con tejadillo
	_p(r, _cyl(0.34, 0.34, 0.14, 8), copper_d, Vector3(-0.18, 0.7, 0))
	_p(r, _cyl(0.12, 0.38, 0.42, 8), copper, Vector3(-0.18, 0.98, 0))
	_p(r, _cyl(0.06, 0.12, 0.18, 8), copper_d, Vector3(-0.18, 1.28, 0))
	# cuello que sube y cruza
	_stick(r, Vector3(-0.18, 1.35, 0), Vector3(-0.1, 1.62, 0), 0.04, copper)
	_stick(r, Vector3(-0.1, 1.62, 0), Vector3(0.42, 1.45, 0), 0.035, copper)
	# serpentín
	for k in 7:
		var t := _p(r, TorusMesh.new(), copper.lightened(0.05), Vector3(0.45, 1.38 - k * 0.075, 0), Vector3(6 if k % 2 == 0 else -6, 0, 0), Vector3(0.15, 0.3, 0.15))
		(t.mesh as TorusMesh).inner_radius = 0.75
		(t.mesh as TorusMesh).outer_radius = 1.0
		(t.mesh as TorusMesh).rings = 10
		(t.mesh as TorusMesh).ring_segments = 5
	# colector pequeño sobre trípode
	for i in 3:
		var a := TAU * float(i) / 3.0
		_stick(r, Vector3(0.45 + cos(a) * 0.14, 0.2, sin(a) * 0.14), Vector3(0.45 + cos(a) * 0.07, 0.62, sin(a) * 0.07), 0.018, Color("2d2622"))
	_p(r, _cyl(0.04, 0.16, 0.18, 8), copper, Vector3(0.45, 0.72, 0))
	_p(r, _cyl(0.16, 0.12, 0.1, 8), copper_d, Vector3(0.45, 0.58, 0))
	_stick(r, Vector3(0.45, 0.86, 0), Vector3(0.45, 0.93, 0), 0.03, copper)
	if level >= 2:
		# nivel 2: bidón de combustible al lado
		_p(r, _box(Vector3(0.26, 0.34, 0.14)), Color("6f7348"), Vector3(0.3, 0.37, 0.45), Vector3(0, 20, 0))
		_p(r, _cyl(0.035, 0.035, 0.06, 6), Color("3a3b2c"), Vector3(0.36, 0.57, 0.42))


# ------------------------------------------------------------ mesa química
## Mesa de laboratorio con matraces verdes que brillan, gradilla de tubos y mechero.
static func _mesa_quimica(r: Node3D) -> void:
	var top := Color("4b4f52")
	_legs(r, 1.55, 0.85, 0.86, 0.07, Color("2e3133"))
	_p(r, _box(Vector3(1.4, 0.04, 0.7)), Color("2e3133"), Vector3(0, 0.25, 0))
	_p(r, _box(Vector3(1.6, 0.06, 0.88)), top, Vector3(0, 0.89, 0))
	var green := Color(0.35, 1.0, 0.45)
	var glass := Color(0.8, 0.9, 0.88, 0.4)
	# matraz grande (frasco tallado con tapón)
	_clear(r, _cyl(0.15, 0.17, 0.3, 6), glass, Vector3(-0.45, 1.07, 0.05))
	_glow(r, _cyl(0.13, 0.15, 0.2, 6), green, Vector3(-0.45, 1.03, 0.05), 1.6)
	_clear(r, _cyl(0.06, 0.09, 0.1, 6), glass, Vector3(-0.45, 1.27, 0.05))
	_p(r, _cyl(0.07, 0.06, 0.06, 6), Color("8a6440"), Vector3(-0.45, 1.34, 0.05))
	# matraz cónico
	_clear(r, _cyl(0.03, 0.13, 0.24, 8), glass, Vector3(-0.1, 1.04, -0.15))
	_glow(r, _cyl(0.07, 0.12, 0.1, 8), Color(0.95, 0.75, 0.2), Vector3(-0.1, 0.97, -0.15), 1.2)
	# gradilla con tubos
	_p(r, _box(Vector3(0.42, 0.05, 0.12)), Color("6b4a2f"), Vector3(0.3, 1.02, 0.18))
	_p(r, _box(Vector3(0.42, 0.04, 0.12)), Color("6b4a2f"), Vector3(0.3, 0.94, 0.18))
	for k in 5:
		var c: Color = [green, Color(0.4, 0.7, 1.0), Color(1.0, 0.45, 0.3), green, Color(0.95, 0.85, 0.3)][k]
		_clear(r, _cyl(0.025, 0.025, 0.24, 6), glass, Vector3(0.14 + k * 0.08, 1.06, 0.18))
		_glow(r, _cyl(0.022, 0.022, 0.1, 6), c, Vector3(0.14 + k * 0.08, 1.0, 0.18), 1.4)
	# mechero con llama azul
	_p(r, _cyl(0.06, 0.08, 0.06, 8), Color("2b2b2b"), Vector3(0.5, 0.95, -0.2))
	_p(r, _cyl(0.02, 0.02, 0.16, 6), Color("9aa0a4"), Vector3(0.5, 1.05, -0.2))
	_glow(r, _cyl(0.0, 0.035, 0.1, 6), Color(0.35, 0.55, 1.0), Vector3(0.5, 1.18, -0.2), 2.5)
	# libreta
	_p(r, _box(Vector3(0.26, 0.02, 0.2)), Color("d8ccb0"), Vector3(0.05, 0.93, 0.2), Vector3(0, -12, 0))


# ------------------------------------------------------- banco de electrónica
## Mesa de metal con placa de circuitos, pila verde y (por fases) soldador y fuente.
static func _banco_electronica(r: Node3D) -> void:
	_legs(r, 1.65, 0.85, 0.86, 0.07, Color("3a3e42"))
	_p(r, _box(Vector3(1.5, 0.04, 0.7)), Color("3a3e42"), Vector3(0, 0.25, 0))
	_p(r, _box(Vector3(1.7, 0.06, 0.9)), Color("5a5550"), Vector3(0, 0.89, 0))
	_p(r, _box(Vector3(1.7, 0.4, 0.04)), Color("4a4642"), Vector3(0, 1.12, 0.43))
	# placa de circuitos con chips
	_p(r, _box(Vector3(0.55, 0.03, 0.4)), Color("2f6b45"), Vector3(-0.2, 0.94, -0.02), Vector3(0, 12, 0))
	for k in 8:
		var cx := -0.38 + float(k % 4) * 0.12
		var cz := -0.1 + float(k / 4) * 0.16
		_p(r, _box(Vector3(0.08, 0.03, 0.06)), Color("1e2420"), Vector3(cx, 0.965, cz), Vector3(0, 12, 0))
	_p(r, _box(Vector3(0.12, 0.04, 0.12)), Color("3a3532"), Vector3(-0.18, 0.97, 0.0), Vector3(0, 12, 0))
	_fase = 1
	# soldador en su soporte y lupa
	_p(r, _cyl(0.05, 0.07, 0.04, 8), Color("2b2b2b"), Vector3(0.35, 0.94, -0.15))
	_stick(r, Vector3(0.35, 0.96, -0.15), Vector3(0.5, 1.12, -0.05), 0.02, Color("c43a2e"))
	_stick(r, Vector3(0.5, 1.12, -0.05), Vector3(0.58, 1.17, 0.0), 0.008, Color("c3c7ca"))
	_stick(r, Vector3(-0.55, 0.92, 0.25), Vector3(-0.55, 1.25, 0.25), 0.015, Color("2b2b2b"))
	var lens := _clear(r, _cyl(0.12, 0.12, 0.02, 12), Color(0.75, 0.9, 0.95, 0.5), Vector3(-0.45, 1.27, 0.15), Vector3(60, 0, 0))
	lens.name = "lupa"
	_fase = 2
	# fuente de alimentación con pantalla y pila verde
	_p(r, _box(Vector3(0.36, 0.24, 0.26)), Color("2c3034"), Vector3(0.55, 1.04, 0.22))
	_glow(r, _box(Vector3(0.2, 0.08, 0.01)), Color(0.4, 1.0, 0.5), Vector3(0.52, 1.08, 0.085), 2.0)
	_p(r, _cyl(0.08, 0.08, 0.04, 8), Color("6a6560"), Vector3(0.25, 0.94, 0.25))
	_glow(r, _cyl(0.07, 0.07, 0.2, 8), Color(0.3, 1.0, 0.4), Vector3(0.25, 1.06, 0.25), 1.8)
	_p(r, _cyl(0.08, 0.08, 0.04, 8), Color("6a6560"), Vector3(0.25, 1.18, 0.25))


# ------------------------------------------------------ trampa de pinchos
## Caballo de frisa: dos aspas de madera unidas por travesaños con estacas afiladas (diseño de objetos).
static func trap() -> Node3D:
	var r := Node3D.new()
	var w := Color("8a5a32")
	var tip := Color("d8c29a")
	for x in [-0.45, 0.45]:
		_p(r, _box(Vector3(0.07, 0.75, 0.07)), w, Vector3(x, 0.3, -0.12), Vector3(-30, 0, 0))
		_p(r, _box(Vector3(0.07, 0.75, 0.07)), w, Vector3(x, 0.3, 0.12), Vector3(30, 0, 0))
	for z in [-0.28, 0.28]:
		_p(r, _box(Vector3(1.05, 0.06, 0.06)), Color("6e4526"), Vector3(0, 0.08, z))
	_p(r, _box(Vector3(1.05, 0.08, 0.08)), Color("6e4526"), Vector3(0, 0.55, 0))
	for k in 5:
		var x := -0.36 + k * 0.18
		for side in [-1.0, 1.0]:
			var a := Vector3(x, 0.5, 0)
			var b := Vector3(x, 0.95, side * 0.32)
			_stick(r, a, b, 0.025, w)
			var tipm := _stick(r, b, b + (b - a).normalized() * 0.12, 0.022, tip)
			tipm.mesh = _cyl(0.0, 0.025, 0.12, 5)
	return r


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
