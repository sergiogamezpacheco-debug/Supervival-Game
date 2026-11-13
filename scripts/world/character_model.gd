class_name CharacterModel
extends Node3D
## Superviviente low poly hecho por piezas (sin esqueleto): cada articulación es
## un Node3D que se puede girar para animar. Mira hacia -Z. Derecha = +X.
##
## look:     sexo, piel, pelo, color de pelo, ojos, color de ojos, nariz, boca
## physique: fuerza y resistencia (0..1) cambian el cuerpo
## outfit:   ranuras de ropa (cabeza, torso, piernas, pies, manos, espalda)

const SKINS := [Color("f2d3b8"), Color("e2b48f"), Color("c68b63"), Color("8e5b3c"), Color("5b3a28")]
const HAIR_COLORS := [Color("231a14"), Color("5a3a22"), Color("c9a25a"), Color("9a3d1c"), Color("b9b5ad")]
const EYE_COLORS := [Color("4a2e1a"), Color("3f74b8"), Color("4f8a4a"), Color("6f7a82"), Color("b07a1e")]
const LIP := Color("a85b52")

const HAIR_NAMES_M := ["Rapado", "Corto", "Tupé", "Melena", "Corto con barba"]
const HAIR_NAMES_F := ["Pixie", "Coleta", "Melena", "Moño", "Trenzas"]
const EYE_NAMES := ["Redondos", "Almendrados", "Grandes", "Rasgados", "Cansados"]
const NOSE_NAMES := ["Pequeña", "Puntiaguda", "Ancha", "Aguileña", "Chata"]
const MOUTH_NAMES := ["Neutra", "Sonrisa", "Labios gruesos", "Fina", "Seria"]
const SKIN_NAMES := ["Muy clara", "Clara", "Morena", "Oscura", "Muy oscura"]
const HAIR_COLOR_NAMES := ["Negro", "Castaño", "Rubio", "Pelirrojo", "Canoso"]
const EYE_COLOR_NAMES := ["Marrones", "Azules", "Verdes", "Grises", "Ámbar"]

var look := {"sex": "m", "skin": 1, "hair": 1, "hair_color": 1, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 0}
var physique := {"fuerza": 0.0, "resistencia": 0.0}
var outfit := {"cabeza": "", "torso": "", "piernas": "", "pies": "", "manos": "", "espalda": ""}
var explode := 0.0           # separa las piezas (para la vista de despiece)

var j: Dictionary = {}       # articulaciones: hips, spine, head, arm_l, elbow_l, hand_l, …
var hand: Node3D             # mano derecha (aquí se cuelga la herramienta)

static var _mesh_cache: Dictionary = {}


func _init(p_look: Dictionary = {}, p_physique: Dictionary = {}, p_outfit: Dictionary = {}) -> void:
	for k in p_look:
		look[k] = p_look[k]
	for k in p_physique:
		physique[k] = p_physique[k]
	for k in p_outfit:
		outfit[k] = p_outfit[k]


func _ready() -> void:
	rebuild()


# ------------------------------------------------------------ utilidades

## Malla con sombreado plano (aspecto low poly), cacheada.
static func flat(key: String, mesh: PrimitiveMesh) -> Mesh:
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.deindex()
	st.generate_normals()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


static func prism(top: float, bottom: float, h: float, sides := 6) -> Mesh:
	var key := "p_%.3f_%.3f_%.3f_%d" % [top, bottom, h, sides]
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return flat(key, c)


static func ball(r: float, h: float, seg := 8, rings := 5) -> Mesh:
	var key := "s_%.3f_%.3f_%d_%d" % [r, h, seg, rings]
	var s := SphereMesh.new()
	s.radius = r
	s.height = h
	s.radial_segments = seg
	s.rings = rings
	return flat(key, s)


static func cube(size: Vector3) -> Mesh:
	var key := "b_%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	var b := BoxMesh.new()
	b.size = size
	return flat(key, b)


func _p(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _joint(parent: Node3D, name_: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name_
	n.position = pos
	parent.add_child(n)
	j[name_] = n
	return n


# ------------------------------------------------------------- medidas

func dims() -> Dictionary:
	var f := float(physique.get("fuerza", 0.0))
	var r := float(physique.get("resistencia", 0.0))
	var male: bool = look.get("sex", "m") == "m"
	var s := 1.0 if male else 0.95
	return {
		"s": s,
		"shoulder": (0.2 if male else 0.168) * (1.0 + 0.2 * f),
		"waist": (0.155 if male else 0.128) * (1.0 - 0.10 * r) * (1.0 + 0.04 * f),
		"hip": (0.152 if male else 0.17),
		"arm": (0.052 if male else 0.044) * (1.0 + 0.5 * f),
		"leg": (0.088 if male else 0.084) * (1.0 + 0.28 * f),
		"thigh": 0.42 * s, "shin": 0.4 * s, "torso": 0.5 * s,
		"upper": 0.28 * s, "fore": 0.25 * s, "head": 0.145 * s,
		"depth": 0.62 + 0.1 * f,
	}


# ----------------------------------------------------------- construcción

func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	j.clear()
	var d := dims()
	var skin: Color = SKINS[clampi(int(look["skin"]), 0, 4)]
	var e := explode
	var male: bool = look["sex"] == "m"

	var hips := _joint(self, "hips", Vector3(0, d["thigh"] + d["shin"] + 0.05, 0))
	_p(hips, prism(d["hip"] * 0.95, d["hip"], 0.17), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.62))

	for side in [-1, 1]:
		var tag := "l" if side < 0 else "r"
		var leg := _joint(hips, "leg_" + tag, Vector3(side * 0.085 * d["s"] + side * e * 0.12, -0.05 - e * 0.1, 0))
		_p(leg, prism(d["leg"], d["leg"] * 0.8, d["thigh"]), skin, Vector3(0, -d["thigh"] / 2.0, 0))
		var knee := _joint(leg, "knee_" + tag, Vector3(0, -d["thigh"] - e * 0.08, 0))
		_p(knee, prism(d["leg"] * 0.78, d["leg"] * 0.55, d["shin"]), skin, Vector3(0, -d["shin"] / 2.0, 0))
		var foot := _joint(knee, "foot_" + tag, Vector3(0, -d["shin"] - e * 0.06, 0))
		_p(foot, cube(Vector3(0.085, 0.055, 0.2) * d["s"]), skin.darkened(0.05), Vector3(0, -0.02, -0.045))

	var spine := _joint(hips, "spine", Vector3(0, 0.06 + e * 0.12, 0))
	var torso := _p(spine, prism(d["shoulder"], d["waist"], d["torso"]), skin, Vector3(0, d["torso"] / 2.0, 0), Vector3.ZERO, Vector3(1, 1, d["depth"]))
	torso.name = "Torso"
	_p(spine, prism(0.05, 0.056, 0.08), skin, Vector3(0, d["torso"] + 0.03, 0))

	var head := _joint(spine, "head", Vector3(0, d["torso"] + 0.04 + d["head"] * 0.95 + e * 0.18, 0))
	_build_head(head, d, skin)

	for side in [-1, 1]:
		var tag := "l" if side < 0 else "r"
		var arm := _joint(spine, "arm_" + tag, Vector3(side * (d["shoulder"] + d["arm"] * 0.55 + e * 0.22), d["torso"] - 0.05, 0))
		arm.rotation.z = side * 0.1
		_p(arm, ball(d["arm"] * 1.25, d["arm"] * 2.3, 6, 4), skin, Vector3(0, 0, 0))
		_p(arm, prism(d["arm"], d["arm"] * 0.85, d["upper"]), skin, Vector3(0, -d["upper"] / 2.0, 0))
		var elbow := _joint(arm, "elbow_" + tag, Vector3(0, -d["upper"] - e * 0.06, 0))
		_p(elbow, prism(d["arm"] * 0.85, d["arm"] * 0.68, d["fore"]), skin, Vector3(0, -d["fore"] / 2.0, 0))
		var h := _joint(elbow, "hand_" + tag, Vector3(0, -d["fore"] - 0.01 - e * 0.05, 0))
		_p(h, cube(Vector3(0.07, 0.1, 0.045) * d["s"]), skin, Vector3(0, -0.045, 0))
		_p(h, cube(Vector3(0.025, 0.05, 0.03) * d["s"]), skin, Vector3(-side * 0.035, -0.035, -0.02), Vector3(0, 0, -side * 0.4))
		if side > 0:
			hand = Node3D.new()
			hand.name = "Hand"
			hand.position = Vector3(0, -0.06, -0.02)
			h.add_child(hand)

	_build_underwear(d)
	_build_outfit(d)


func _has(slot: String) -> bool:
	return str(outfit.get(slot, "")) != ""


func _build_head(head: Node3D, d: Dictionary, skin: Color) -> void:
	var r: float = d["head"]
	var male: bool = look["sex"] == "m"
	var hc: Color = HAIR_COLORS[clampi(int(look["hair_color"]), 0, 4)]
	_p(head, ball(r, r * 2.25, 8, 5), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1.0 if male else 0.95, 1, 0.98))
	_p(head, cube(Vector3(r * 1.25, r * 0.5, r * 1.2)), skin, Vector3(0, -r * 0.55, -r * 0.05))  # mandíbula
	for side in [-1, 1]:
		_p(head, cube(Vector3(0.025, 0.05, 0.035)), skin.darkened(0.06), Vector3(side * r * 1.0, -0.005, 0.0))
	var fz := -r * 0.93
	# Ojos
	var ec: Color = EYE_COLORS[clampi(int(look["eye_color"]), 0, 4)]
	var es := int(look["eyes"])
	for side in [-1, 1]:
		var x: float = side * 0.045
		var w := 0.03
		var hgt := 0.022
		var tilt := 0.0
		match es:
			1: hgt = 0.015; w = 0.034; tilt = side * -0.18
			2: w = 0.036; hgt = 0.03
			3: hgt = 0.011; w = 0.034; tilt = side * -0.32
			4: hgt = 0.016
		_p(head, cube(Vector3(w, hgt, 0.012)), Color("f4f1ea"), Vector3(x, 0.018, fz), Vector3(0, 0, tilt))
		_p(head, cube(Vector3(hgt * 0.95, hgt * 0.95, 0.014)), ec, Vector3(x, 0.018, fz - 0.002), Vector3(0, 0, tilt))
		_p(head, cube(Vector3(hgt * 0.4, hgt * 0.4, 0.016)), Color("141010"), Vector3(x, 0.018, fz - 0.004))
		if es == 4:
			_p(head, cube(Vector3(w + 0.004, 0.009, 0.016)), skin.darkened(0.12), Vector3(x, 0.018 + hgt * 0.45, fz - 0.003))
		# cejas
		_p(head, cube(Vector3(0.038, 0.009, 0.014)), hc.darkened(0.1), Vector3(x, 0.052, fz + 0.002), Vector3(0, 0, side * (-0.12 if es != 4 else 0.12)))
	# Nariz
	var nz := -r * 1.0
	match int(look["nose"]):
		0: _p(head, cube(Vector3(0.022, 0.04, 0.03)), skin.darkened(0.04), Vector3(0, -0.018, nz))
		1: _p(head, prism(0.0, 0.018, 0.045, 4), skin.darkened(0.04), Vector3(0, -0.02, nz - 0.01), Vector3(-1.2, 0, 0))
		2: _p(head, cube(Vector3(0.042, 0.035, 0.03)), skin.darkened(0.05), Vector3(0, -0.022, nz))
		3:
			_p(head, cube(Vector3(0.022, 0.055, 0.028)), skin.darkened(0.04), Vector3(0, -0.012, nz - 0.004), Vector3(0.25, 0, 0))
		4: _p(head, ball(0.02, 0.034, 6, 3), skin.darkened(0.05), Vector3(0, -0.026, nz + 0.006))
	# Boca
	var mz := -r * 0.88
	var my := -0.064
	match int(look["mouth"]):
		0: _p(head, cube(Vector3(0.05, 0.01, 0.012)), LIP.darkened(0.2), Vector3(0, my, mz))
		1:
			for side in [-1, 1]:
				_p(head, cube(Vector3(0.03, 0.009, 0.012)), LIP.darkened(0.2), Vector3(side * 0.013, my + 0.002, mz), Vector3(0, 0, side * 0.3))
		2:
			_p(head, cube(Vector3(0.056, 0.016, 0.014)), LIP, Vector3(0, my + 0.006, mz))
			_p(head, cube(Vector3(0.05, 0.016, 0.014)), LIP.darkened(0.08), Vector3(0, my - 0.01, mz))
		3: _p(head, cube(Vector3(0.042, 0.006, 0.012)), LIP.darkened(0.3), Vector3(0, my, mz))
		4:
			_p(head, cube(Vector3(0.05, 0.008, 0.012)), LIP.darkened(0.3), Vector3(0, my, mz))
			for side in [-1, 1]:
				_p(head, cube(Vector3(0.012, 0.008, 0.012)), LIP.darkened(0.3), Vector3(side * 0.028, my - 0.004, mz), Vector3(0, 0, side * -0.5))
	_build_hair(head, r, hc, male)


func _build_hair(head: Node3D, r: float, hc: Color, male: bool) -> void:
	var cap_h := r * 1.25
	var style := int(look["hair"])
	# Casquete inclinado: la línea del pelo queda alta en la frente y baja en la nuca.
	var cap := func(thick: float):
		_p(head, ball(r * (1.07 + thick), r * 1.45 * (1.0 + thick), 8, 4), hc, Vector3(0, r * 0.6, r * 0.04), Vector3(0.45, 0, 0), Vector3(1, 1, 1.02))
	if male:
		match style:
			0:
				_p(head, ball(r * 1.03, r * 1.45, 8, 4), hc.lerp(Color("8a7a6a"), 0.25), Vector3(0, r * 0.6, r * 0.04), Vector3(0.45, 0, 0))
			1:
				cap.call(0.05)
				_p(head, cube(Vector3(r * 1.6, r * 0.3, r * 0.5)), hc, Vector3(0, r * 0.9, -r * 0.45), Vector3(-0.3, 0, 0))
			2:
				cap.call(0.0)
				_p(head, cube(Vector3(r * 1.45, r * 0.75, r * 1.2)), hc, Vector3(0, r * 1.2, -r * 0.3), Vector3(-0.5, 0, 0))
				_p(head, cube(Vector3(r * 1.2, r * 0.45, r * 0.5)), hc.lightened(0.08), Vector3(0, r * 1.38, -r * 0.85), Vector3(-0.9, 0, 0))
			3:
				cap.call(0.08)
				_p(head, cube(Vector3(r * 2.1, r * 1.6, r * 0.5)), hc, Vector3(0, -r * 0.2, r * 0.75))
				for side in [-1, 1]:
					_p(head, cube(Vector3(r * 0.35, r * 1.3, r * 1.2)), hc, Vector3(side * r * 0.95, -r * 0.15, r * 0.15))
			4:
				cap.call(0.02)
				_p(head, cube(Vector3(r * 1.0, r * 0.4, r * 0.35)), hc, Vector3(0, -r * 0.92, -r * 0.62))
				for side in [-1, 1]:
					_p(head, cube(Vector3(r * 0.22, r * 0.75, r * 0.8)), hc, Vector3(side * r * 0.78, -r * 0.5, -r * 0.28))
				_p(head, cube(Vector3(r * 0.62, r * 0.1, r * 0.1)), hc, Vector3(0, -r * 0.33, -r * 0.97))
	else:
		match style:
			0:
				cap.call(0.07)
				_p(head, cube(Vector3(r * 1.5, r * 0.35, r * 0.4)), hc, Vector3(r * 0.2, r * 0.62, -r * 0.8), Vector3(0, 0, -0.25))
			1:
				cap.call(0.05)
				_p(head, ball(r * 0.4, r * 1.6, 6, 4), hc, Vector3(0, -r * 0.1, r * 1.25), Vector3(0.5, 0, 0))
			2:
				cap.call(0.08)
				_p(head, cube(Vector3(r * 2.15, r * 2.4, r * 0.55)), hc, Vector3(0, -r * 0.6, r * 0.72))
				for side in [-1, 1]:
					_p(head, cube(Vector3(r * 0.38, r * 2.0, r * 1.3)), hc, Vector3(side * r * 0.97, -r * 0.45, r * 0.12))
			3:
				cap.call(0.05)
				_p(head, ball(r * 0.48, r * 0.9, 6, 4), hc, Vector3(0, r * 0.95, r * 0.7))
			4:
				cap.call(0.06)
				for side in [-1, 1]:
					_p(head, prism(r * 0.17, r * 0.12, r * 2.6, 5), hc, Vector3(side * r * 0.85, -r * 1.25, -r * 0.3), Vector3(-0.12, 0, side * 0.1))


func _build_underwear(d: Dictionary) -> void:
	var under := Color("d9d4c8") if look["sex"] == "m" else Color("c9c2b2")
	var hips: Node3D = j["hips"]
	if look["sex"] == "f" and not _has("torso"):
		var spine0: Node3D = j["spine"]
		_p(spine0, prism(d["shoulder"] * 0.98, d["shoulder"] * 0.86, 0.13), under, Vector3(0, d["torso"] * 0.7, -0.012), Vector3.ZERO, Vector3(1.04, 1, d["depth"] + 0.26))
	if _has("piernas"):
		return
	_p(hips, prism(d["hip"] * 1.02, d["hip"] * 1.06, 0.17), under, Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(1.03, 1, 0.7))
	for side in [-1, 1]:
		var leg: Node3D = j["leg_" + ("l" if side < 0 else "r")]
		_p(leg, prism(d["leg"] * 1.16, d["leg"] * 1.12, 0.09), under, Vector3(0, -0.03, 0))



# ------------------------------------------------------------------ ropa

const CLOTH := {
	"camiseta": Color("8a9a6a"), "chaqueta_piel": Color("6b4a2e"), "chaleco": Color("4f5a4a"),
	"pantalon_tela": Color("7d7462"), "pantalon_cargo": Color("4e5a3c"),
	"botas": Color("3d2b1e"), "zapatillas": Color("b8b2a2"),
	"gorra": Color("8c3a2a"), "casco_obra": Color("e1b12c"),
	"guantes": Color("3a3430"), "mochila": Color("5d6b3c"),
}


func _build_outfit(d: Dictionary) -> void:
	var spine: Node3D = j["spine"]
	var t := str(outfit.get("torso", ""))
	if t != "":
		var c: Color = CLOTH.get(t, Color.GRAY)
		var grow := 1.06 if t != "chaqueta_piel" else 1.1
		var extra := 0.06 if look["sex"] == "m" else 0.16
		_p(spine, prism(d["shoulder"] * grow, d["waist"] * grow * 1.02, d["torso"] * 0.98), c, Vector3(0, d["torso"] / 2.0, 0), Vector3.ZERO, Vector3(1, 1, d["depth"] + extra))
		for side in [-1, 1]:
			var arm: Node3D = j["arm_" + ("l" if side < 0 else "r")]
			if t != "chaleco":
				_p(arm, ball(d["arm"] * 1.45, d["arm"] * 2.6, 6, 4), c, Vector3.ZERO)
			if t == "camiseta":
				_p(arm, prism(d["arm"] * 1.3, d["arm"] * 1.2, d["upper"] * 0.45), c, Vector3(0, -d["upper"] * 0.2, 0))
			elif t == "chaqueta_piel":
				_p(arm, prism(d["arm"] * 1.35, d["arm"] * 1.2, d["upper"]), c, Vector3(0, -d["upper"] / 2.0, 0))
				var elbow: Node3D = j["elbow_" + ("l" if side < 0 else "r")]
				_p(elbow, prism(d["arm"] * 1.15, d["arm"] * 1.0, d["fore"] * 0.9), c, Vector3(0, -d["fore"] * 0.45, 0))
		if t == "chaqueta_piel":
			_p(spine, prism(d["shoulder"] * 0.55, d["shoulder"] * 0.62, 0.08), c.darkened(0.15), Vector3(0, d["torso"] + 0.0, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
		if t == "chaleco":
			for side in [-1, 1]:
				_p(spine, cube(Vector3(0.08, 0.07, 0.03)), c.darkened(0.2), Vector3(side * 0.07, d["torso"] * 0.45, -d["waist"] * d["depth"] - 0.03))
	var pz := str(outfit.get("piernas", ""))
	if pz != "":
		var c2: Color = CLOTH.get(pz, Color.GRAY)
		_p(j["hips"], prism(d["hip"] * 1.06, d["hip"] * 1.1, 0.18), c2, Vector3(0, -0.01, 0), Vector3.ZERO, Vector3(1.04, 1, 0.68))
		for side in [-1, 1]:
			var tag := "l" if side < 0 else "r"
			_p(j["leg_" + tag], prism(d["leg"] * 1.14, d["leg"] * 0.95, d["thigh"]), c2, Vector3(0, -d["thigh"] / 2.0, 0))
			_p(j["knee_" + tag], prism(d["leg"] * 0.92, d["leg"] * 0.72, d["shin"] * 0.92), c2, Vector3(0, -d["shin"] * 0.46, 0))
			if pz == "pantalon_cargo":
				_p(j["leg_" + tag], cube(Vector3(0.03, 0.09, 0.08)), c2.darkened(0.2), Vector3(side * d["leg"] * 1.1, -d["thigh"] * 0.5, 0))
	var pies := str(outfit.get("pies", ""))
	if pies != "":
		var c3: Color = CLOTH.get(pies, Color.GRAY)
		for side in [-1, 1]:
			var tag := "l" if side < 0 else "r"
			_p(j["foot_" + tag], cube(Vector3(0.1, 0.07, 0.23) * d["s"]), c3, Vector3(0, -0.017, -0.045))
			if pies == "botas":
				_p(j["knee_" + tag], prism(d["leg"] * 0.8, d["leg"] * 0.75, 0.14), c3, Vector3(0, -d["shin"] + 0.06, 0))
	var cab := str(outfit.get("cabeza", ""))
	if cab != "":
		var c4: Color = CLOTH.get(cab, Color.GRAY)
		var r: float = d["head"]
		if cab == "gorra":
			_p(j["head"], ball(r * 1.12, r * 1.3, 8, 3), c4, Vector3(0, r * 0.72, r * 0.02), Vector3.ZERO, Vector3(1, 0.75, 1.02))
			_p(j["head"], cube(Vector3(r * 1.4, 0.015, r * 0.8)), c4.darkened(0.15), Vector3(0, r * 0.6, -r * 1.15))
		else:
			_p(j["head"], ball(r * 1.2, r * 1.6, 8, 3), c4, Vector3(0, r * 0.78, 0), Vector3.ZERO, Vector3(1, 0.8, 1.05))
			_p(j["head"], prism(r * 1.35, r * 1.35, 0.02, 8), c4.darkened(0.1), Vector3(0, r * 0.62, 0))
	if str(outfit.get("manos", "")) != "":
		for side in [-1, 1]:
			_p(j["hand_" + ("l" if side < 0 else "r")], cube(Vector3(0.068, 0.07, 0.042) * d["s"]), CLOTH["guantes"], Vector3(0, -0.035, 0))
	if str(outfit.get("espalda", "")) != "":
		var c6: Color = CLOTH["mochila"]
		_p(spine, cube(Vector3(0.3, 0.38, 0.16) * d["s"]), c6, Vector3(0, d["torso"] * 0.55, d["shoulder"] * d["depth"] + 0.06))
		_p(spine, cube(Vector3(0.26, 0.12, 0.08) * d["s"]), c6.darkened(0.2), Vector3(0, d["torso"] * 0.3, d["shoulder"] * d["depth"] + 0.15))
		for side in [-1, 1]:
			_p(spine, cube(Vector3(0.04, 0.4, 0.03)), c6.darkened(0.3), Vector3(side * 0.1, d["torso"] * 0.62, -d["shoulder"] * d["depth"] - 0.005))


# ------------------------------------------------------------- animación

## Paso de andar: phase avanza con la velocidad, amount 0..1.
func animate_walk(phase: float, amount: float) -> void:
	if j.is_empty():
		return
	var s := sin(phase) * 0.6 * amount
	j["leg_l"].rotation.x = s
	j["leg_r"].rotation.x = -s
	j["knee_l"].rotation.x = maxf(0.0, -sin(phase)) * 0.8 * amount
	j["knee_r"].rotation.x = maxf(0.0, sin(phase)) * 0.8 * amount
	j["arm_l"].rotation.x = -s * 0.8
	j["arm_r"].rotation.x = s * 0.8
	j["elbow_l"].rotation.x = -0.25 * amount
	j["elbow_r"].rotation.x = -0.25 * amount
	j["spine"].rotation.y = s * 0.12
	j["hips"].position.y = dims()["thigh"] + dims()["shin"] + 0.05 + absf(cos(phase)) * 0.025 * amount


## Golpe con el brazo derecho (0..1).
func animate_swing(t: float) -> void:
	if j.is_empty():
		return
	j["arm_r"].rotation.x = -sin(t * PI) * 2.0
	j["elbow_r"].rotation.x = -sin(t * PI) * 0.6
