class_name CharacterModel
extends Node3D
## Superviviente low poly de proporciones realistas. Cada parte del cuerpo es una
## malla facetada hecha por secciones (anillos elípticos unidos), con anatomía:
## gemelos, rodillas, pecho, mandíbula, nariz, ceja… Las piezas cuelgan de
## articulaciones (Node3D) que se giran para animar. Mira hacia -Z; derecha = +X.
##
## look:     sexo, piel, pelo, color de pelo, ojos, color de ojos, nariz, boca
## physique: fuerza y resistencia (0..1) cambian el cuerpo
## outfit:   ranuras de ropa (cabeza, torso, piernas, pies, manos, espalda)

const SKINS := [Color("efcfb4"), Color("dcae8a"), Color("bf855d"), Color("8a5a3c"), Color("5a3a28")]
const HAIR_COLORS := [Color("221a15"), Color("553820"), Color("b8914e"), Color("8e3a1c"), Color("a9a49c")]
const EYE_COLORS := [Color("3b2516"), Color("33608f"), Color("3f6e3a"), Color("596269"), Color("8f6418")]

const HAIR_NAMES_M := ["Rapado", "Corto", "Tupé", "Melena", "Corto con barba"]
const HAIR_NAMES_F := ["Pixie", "Coleta", "Melena", "Moño", "Trenzas"]
const EYE_NAMES := ["Redondos", "Almendrados", "Grandes", "Rasgados", "Cansados"]
const NOSE_NAMES := ["Pequeña", "Puntiaguda", "Ancha", "Aguileña", "Chata"]
const MOUTH_NAMES := ["Neutra", "Sonrisa", "Labios gruesos", "Fina", "Seria"]
const SKIN_NAMES := ["Muy clara", "Clara", "Morena", "Oscura", "Muy oscura"]
const HAIR_COLOR_NAMES := ["Negro", "Castaño", "Rubio", "Pelirrojo", "Canoso"]
const EYE_COLOR_NAMES := ["Marrones", "Azules", "Verdes", "Grises", "Ámbar"]

const CLOTH := {
	"camiseta": Color("5d6340"), "chaqueta_piel": Color("6a4a2f"), "chaleco": Color("8a7a5a"),
	"pantalon_tela": Color("8a7a58"), "pantalon_cargo": Color("6f6a48"),
	"botas": Color("4a3a2c"), "zapatillas": Color("5f646a"),
	"gorra": Color("6f6450"), "casco_obra": Color("d9a925"),
	"guantes": Color("3d3732"), "mochila": Color("6b6243"),
}

var look := {"sex": "m", "skin": 1, "hair": 1, "hair_color": 1, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 1}
var physique := {"fuerza": 0.0, "resistencia": 0.0}
var outfit := {"cabeza": "", "torso": "", "piernas": "", "pies": "", "manos": "", "espalda": ""}
var explode := 0.0           # separa las piezas (vista de despiece)

var j: Dictionary = {}       # articulaciones
var hand: Node3D             # mano derecha: aquí se cuelga la herramienta

static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}


func _init(p_look: Dictionary = {}, p_physique: Dictionary = {}, p_outfit: Dictionary = {}) -> void:
	for k in p_look:
		look[k] = p_look[k]
	for k in p_physique:
		physique[k] = p_physique[k]
	for k in p_outfit:
		outfit[k] = p_outfit[k]


func _ready() -> void:
	rebuild()


# ============================================================ geometría

## Malla por secciones. Cada anillo: [y, rx, rz, cx = 0, cz = 0].
## arc: fracción de vuelta (1 = cerrado). arc_start en radianes (0 = +X, -PI/2 = frente).
static func loft(rings: Array, sides := 8, caps := true, arc := 1.0, arc_start := 0.0) -> Mesh:
	var key := "L%s|%d|%s|%.3f|%.3f" % [str(rings), sides, caps, arc, arc_start]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var closed := arc >= 0.999
	var n := sides if closed else sides + 1
	var pts: Array = []
	for r in rings:
		var row: Array = []
		var cx: float = float(r[3]) if r.size() > 3 else 0.0
		var cz: float = float(r[4]) if r.size() > 4 else 0.0
		for i in n:
			var a := arc_start + TAU * arc * float(i) / float(sides)
			row.append(Vector3(cx + cos(a) * float(r[1]), float(r[0]), cz + sin(a) * float(r[2])))
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var tris: Array = []
	for k in pts.size() - 1:
		var r0: Array = pts[k]
		var r1: Array = pts[k + 1]
		for i in sides:
			var i2 := (i + 1) % n if closed else i + 1
			tris.append([r0[i], r1[i2], r1[i]])
			tris.append([r0[i], r0[i2], r1[i2]])
	if caps and closed:
		var first: Array = pts[0]
		var last: Array = pts[pts.size() - 1]
		var c0 := Vector3.ZERO
		var c1 := Vector3.ZERO
		for p in first:
			c0 += p
		for p in last:
			c1 += p
		c0 /= float(first.size())
		c1 /= float(last.size())
		for i in n:
			var i2 := (i + 1) % n
			tris.append([c0, first[i], first[i2]])
			tris.append([c1, last[i2], last[i]])
	for t in tris:
		var v := 1.0 - rng.randf() * 0.07
		st.set_color(Color(v, v, v))
		st.add_vertex(t[0])
		st.add_vertex(t[1])
		st.add_vertex(t[2])
	st.generate_normals()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


static func box(size: Vector3) -> Mesh:
	var h := size / 2.0
	return loft([[-h.y, h.x * 1.4142, h.z * 1.4142], [h.y, h.x * 1.4142, h.z * 1.4142]], 4, true, 1.0, PI / 4.0)


static func mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m


func _p(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color)
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


## Escala los radios de una lista de anillos (y el desplazamiento del centro).
static func grow(rings: Array, f: float, fz := -1.0) -> Array:
	var out: Array = []
	var gz := f if fz < 0.0 else fz
	for r in rings:
		var c: Array = r.duplicate()
		c[1] = float(c[1]) * f
		c[2] = float(c[2]) * gz
		out.append(c)
	return out


## Se queda con los anillos entre dos alturas.
static func slice(rings: Array, y_top: float, y_bottom: float) -> Array:
	var out: Array = []
	for r in rings:
		if float(r[0]) <= y_top + 0.0001 and float(r[0]) >= y_bottom - 0.0001:
			out.append(r)
	return out


# ============================================================== medidas

func dims() -> Dictionary:
	var f := float(physique.get("fuerza", 0.0))
	var r := float(physique.get("resistencia", 0.0))
	var male: bool = look.get("sex", "m") == "m"
	var s := 1.0 if male else 0.94
	return {
		"s": s, "male": male, "f": f, "r": r,
		"thigh": 0.43 * s, "shin": 0.42 * s, "ankle": 0.08 * s,
		"upper": 0.29 * s, "fore": 0.26 * s,
		"shoulder": (0.178 if male else 0.152) * s * (1.0 + 0.12 * f),
		"arm": (1.0 if male else 0.84) * (1.0 + 0.5 * f),
		"leg": (1.0 if male else 0.96) * (1.0 + 0.28 * f),
		"chest": (1.0 if male else 0.88) * (1.0 + 0.14 * f),
		"waist": (1.0 if male else 0.86) * (1.0 - 0.08 * r) * (1.0 + 0.04 * f),
		"hips": (1.0 if male else 1.1),
	}


# --------------------------------------------------- perfiles anatómicos

func _pelvis(d: Dictionary) -> Array:
	var h: float = d["hips"]
	var w: float = d["waist"]
	return [[0.08, 0.135 * w, 0.09 * w], [0.03, 0.142 * h, 0.095 * h], [-0.04, 0.15 * h, 0.1 * h], [-0.1, 0.135 * h, 0.09 * h], [-0.14, 0.085 * h, 0.07, 0.0, 0.005]]


func _torso(d: Dictionary) -> Array:
	var c: float = d["chest"]
	var w: float = d["waist"]
	var s: float = d["s"]
	var bust := 0.0 if d["male"] else 0.022
	return [
		[0.0, 0.135 * w, 0.09 * w],
		[0.09 * s, 0.14 * w, 0.095 * w],
		[0.19 * s, 0.155 * c, 0.105 * c + bust * 0.5, 0.0, -bust * 0.5],
		[0.27 * s, 0.17 * c, 0.115 * c + bust, 0.0, -bust],
		[0.35 * s, 0.178 * c, 0.11 * c + bust * 0.4, 0.0, -bust * 0.4],
		[0.405 * s, float(d["shoulder"]) * 0.98, 0.1 * c],
		[0.445 * s, float(d["shoulder"]) * 0.8, 0.085 * c],
		[0.48 * s, 0.09 * c, 0.065 * c],
		[0.5 * s, 0.055, 0.05],
	]


func _thigh(d: Dictionary) -> Array:
	var g: float = d["leg"]
	var t: float = d["thigh"]
	return [[0.03, 0.085 * g, 0.088 * g], [-0.06, 0.088 * g, 0.09 * g], [-t * 0.45, 0.075 * g, 0.078 * g], [-t * 0.85, 0.06 * g, 0.062 * g, 0.0, -0.004], [-t - 0.015, 0.052 * g, 0.054 * g, 0.0, -0.008]]


func _shin(d: Dictionary) -> Array:
	var g: float = d["leg"]
	var sh: float = d["shin"]
	return [[0.01, 0.052 * g, 0.054 * g, 0.0, -0.008], [-sh * 0.2, 0.054 * g, 0.06 * g, 0.0, 0.008], [-sh * 0.42, 0.05 * g, 0.054 * g, 0.0, 0.006], [-sh * 0.8, 0.036 * g, 0.038 * g], [-sh - 0.01, 0.032, 0.034]]


func _foot() -> Array:
	# a lo largo del pie (luego se gira para que apunte hacia delante)
	return [[-0.055, 0.032, 0.035, 0.0, -0.03], [-0.01, 0.04, 0.05, 0.0, -0.03], [0.07, 0.046, 0.036, 0.0, -0.046], [0.15, 0.044, 0.024, 0.0, -0.058], [0.185, 0.032, 0.016, 0.0, -0.062]]


func _upper_arm(d: Dictionary) -> Array:
	var a: float = d["arm"]
	var u: float = d["upper"]
	return [[0.045, 0.02 * a, 0.022 * a], [0.032, 0.042 * a, 0.046 * a], [0.008, 0.054 * a, 0.057 * a], [-0.03, 0.054 * a, 0.056 * a], [-u * 0.3, 0.05 * a, 0.054 * a, 0.0, -0.004 * a], [-u * 0.7, 0.043 * a, 0.045 * a], [-u - 0.01, 0.037 * a, 0.039 * a]]


func _fore_arm(d: Dictionary) -> Array:
	var a: float = d["arm"]
	var fo: float = d["fore"]
	return [[0.01, 0.038 * a, 0.04 * a], [-fo * 0.25, 0.043 * a, 0.041 * a], [-fo * 0.7, 0.033 * a, 0.03 * a], [-fo, 0.027, 0.022]]


func _head_rings() -> Array:
	# y relativo al centro de la cabeza; cz < 0 adelanta la cara
	return [
		[-0.12, 0.034, 0.035, 0.0, -0.036],
		[-0.104, 0.058, 0.06, 0.0, -0.026],
		[-0.07, 0.076, 0.086, 0.0, -0.012],
		[-0.032, 0.084, 0.097, 0.0, -0.004],
		[0.005, 0.088, 0.1],
		[0.045, 0.09, 0.102, 0.0, 0.004],
		[0.082, 0.085, 0.098, 0.0, 0.01],
		[0.11, 0.066, 0.08, 0.0, 0.014],
		[0.128, 0.03, 0.04, 0.0, 0.014],
	]


# ============================================================ construcción

func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	j.clear()
	var d := dims()
	var skin: Color = SKINS[clampi(int(look["skin"]), 0, 4)]
	var e := explode
	var s: float = d["s"]

	var hip_h: float = float(d["thigh"]) + float(d["shin"]) + float(d["ankle"]) + 0.06
	var hips := _joint(self, "hips", Vector3(0, hip_h, 0))
	_p(hips, loft(_pelvis(d), 9), skin)

	for side in [-1, 1]:
		var tag := "l" if side < 0 else "r"
		var leg := _joint(hips, "leg_" + tag, Vector3(side * 0.082 * s * float(d["hips"]) + side * e * 0.12, -0.06 - e * 0.1, 0))
		_p(leg, loft(_thigh(d), 8), skin)
		var knee := _joint(leg, "knee_" + tag, Vector3(0, -float(d["thigh"]) - e * 0.08, 0))
		_p(knee, loft(_shin(d), 8), skin)
		var foot := _joint(knee, "foot_" + tag, Vector3(0, -float(d["shin"]) - e * 0.06, 0))
		_p(foot, loft(_foot(), 7), skin, Vector3.ZERO, Vector3(-PI / 2.0, 0, 0))

	var spine := _joint(hips, "spine", Vector3(0, 0.07 + e * 0.12, 0))
	_p(spine, loft(_torso(d), 10), skin)

	var head := _joint(spine, "head", Vector3(0, 0.615 * s + e * 0.18, 0))
	head.scale = Vector3.ONE * (1.0 if d["male"] else 0.94)
	_build_head(head, skin)

	for side in [-1, 1]:
		var tag := "l" if side < 0 else "r"
		var arm := _joint(spine, "arm_" + tag, Vector3(side * (float(d["shoulder"]) + 0.004 + e * 0.22), 0.395 * s, 0.0))
		arm.rotation.z = side * 0.08
		_p(arm, loft(_upper_arm(d), 8), skin)
		var elbow := _joint(arm, "elbow_" + tag, Vector3(0, -float(d["upper"]) - e * 0.06, 0))
		elbow.rotation.x = -0.12
		_p(elbow, loft(_fore_arm(d), 8), skin)
		var h := _joint(elbow, "hand_" + tag, Vector3(0, -float(d["fore"]) - e * 0.05, 0))
		_build_hand(h, side, skin)
		if side > 0:
			hand = Node3D.new()
			hand.name = "Hand"
			hand.position = Vector3(0, -0.06, -0.015)
			h.add_child(hand)

	_build_underwear(d)
	_build_outfit(d)


func _build_hand(h: Node3D, side: int, skin: Color) -> void:
	# palma y dedos juntos (manopla facetada) y pulgar aparte
	_p(h, loft([[0.0, 0.026, 0.017], [-0.035, 0.034, 0.016], [-0.065, 0.034, 0.014], [-0.1, 0.028, 0.011], [-0.112, 0.018, 0.008]], 6), skin, Vector3.ZERO, Vector3(0.15, 0, 0))
	_p(h, loft([[0.0, 0.011, 0.011], [-0.03, 0.01, 0.009], [-0.048, 0.007, 0.006]], 5), skin, Vector3(-side * 0.02, -0.018, -0.016), Vector3(0.45, 0, side * 0.35))


func _build_head(head: Node3D, skin: Color) -> void:
	var male: bool = look["sex"] == "m"
	var hc: Color = HAIR_COLORS[clampi(int(look["hair_color"]), 0, 4)]
	var rings := _head_rings()
	if not male:
		# cara más fina: mandíbula y barbilla más estrechas
		var soft: Array = []
		for r in grow(rings, 0.96, 0.97):
			var n: Array = r.duplicate()
			if float(n[0]) < -0.02:
				n[1] = float(n[1]) * lerpf(1.0, 0.84, clampf((-0.02 - float(n[0])) / 0.08, 0.0, 1.0))
			soft.append(n)
		rings = soft
	_p(head, loft(rings, 10), skin)
	# cuello
	_p(head, loft([[-0.2, 0.052, 0.052, 0.0, 0.01], [-0.09, 0.046, 0.048, 0.0, 0.012]], 8), skin)
	# arco de las cejas (relieve) y orejas
	_p(head, loft([[0.0, 0.07, 0.012], [0.02, 0.066, 0.01]], 6, true, 0.5, PI), skin.darkened(0.03), Vector3(0, 0.035, -0.088))
	for side in [-1, 1]:
		_p(head, box(Vector3(0.018, 0.04, 0.03)), skin.darkened(0.06), Vector3(side * 0.089, 0.0, 0.012), Vector3(0, side * 0.25, 0))
	var fz := -0.102
	# Ojos: pequeños y oscuros
	var ec: Color = EYE_COLORS[clampi(int(look["eye_color"]), 0, 4)]
	var es := int(look["eyes"])
	for side in [-1, 1]:
		var x: float = side * 0.032
		var w := 0.02
		var hgt := 0.009
		var tilt := 0.0
		match es:
			1:
				w = 0.024
				hgt = 0.007
				tilt = side * -0.15
			2:
				w = 0.024
				hgt = 0.013
			3:
				w = 0.024
				hgt = 0.005
				tilt = side * -0.3
			4:
				hgt = 0.007
		_p(head, box(Vector3(w, hgt, 0.006)), Color("ece6da"), Vector3(x, 0.02, fz), Vector3(0, 0, tilt))
		_p(head, box(Vector3(hgt * 1.1, hgt, 0.007)), ec.darkened(0.35), Vector3(x + side * 0.002, 0.02, fz - 0.002), Vector3(0, 0, tilt))
		if es == 4:
			_p(head, box(Vector3(w + 0.004, 0.006, 0.008)), skin.darkened(0.15), Vector3(x, 0.026, fz - 0.002))
		if male:
			_p(head, box(Vector3(0.03, 0.007, 0.01)), hc.darkened(0.15), Vector3(x + side * 0.003, 0.038, fz - 0.002), Vector3(0, 0, side * (-0.1 if es != 4 else 0.15)))
		else:
			# pestañas (línea oscura con la punta hacia fuera) y ceja fina arqueada
			_p(head, box(Vector3(w + 0.006, 0.0035, 0.008)), Color("1c1411"), Vector3(x + side * 0.001, 0.02 + hgt * 0.5 + 0.001, fz - 0.003), Vector3(0, 0, tilt - side * 0.12))
			_p(head, box(Vector3(0.012, 0.003, 0.008)), Color("1c1411"), Vector3(x + side * 0.016, 0.023 + hgt * 0.5, fz - 0.002), Vector3(0, 0, side * 0.5))
			_p(head, box(Vector3(0.028, 0.0045, 0.009)), hc.darkened(0.2), Vector3(x + side * 0.004, 0.039, fz - 0.002), Vector3(0, 0, side * -0.22))
	# Nariz: cuña facetada
	var nl := 0.05
	var nw := 0.016
	var np := 0.022
	match int(look["nose"]):
		1:
			np = 0.03
			nw = 0.013
		2:
			nw = 0.024
			np = 0.02
		3:
			nl = 0.06
			np = 0.03
		4:
			nl = 0.035
			np = 0.016
			nw = 0.02
	_p(head, loft([[0.0, nw * 0.4, 0.004], [-nl * 0.6, nw * 0.7, np * 0.5, 0.0, -np * 0.45], [-nl, nw, np * 0.5, 0.0, -np * 0.5]], 4, true, 1.0, PI / 4.0), skin.darkened(0.04), Vector3(0, 0.03, fz + 0.005))
	# Boca
	var lip := skin.darkened(0.32).lerp(Color("8a4b45"), 0.35)
	if not male:
		lip = skin.darkened(0.2).lerp(Color("a8524e"), 0.55)
	var my := -0.052
	var mz := -0.103
	match int(look["mouth"]):
		0:
			_p(head, box(Vector3(0.036, 0.006, 0.006)), lip, Vector3(0, my, mz))
		1:
			for side in [-1, 1]:
				_p(head, box(Vector3(0.022, 0.005, 0.006)), lip, Vector3(side * 0.01, my + 0.002, mz), Vector3(0, 0, side * 0.25))
		2:
			_p(head, box(Vector3(0.04, 0.009, 0.008)), lip.lightened(0.1), Vector3(0, my + 0.003, mz))
			_p(head, box(Vector3(0.036, 0.009, 0.008)), lip, Vector3(0, my - 0.007, mz + 0.001))
		3:
			_p(head, box(Vector3(0.03, 0.004, 0.006)), lip.darkened(0.2), Vector3(0, my, mz))
		4:
			_p(head, box(Vector3(0.036, 0.005, 0.006)), lip.darkened(0.2), Vector3(0, my, mz))
			for side in [-1, 1]:
				_p(head, box(Vector3(0.01, 0.005, 0.006)), lip.darkened(0.2), Vector3(side * 0.021, my - 0.003, mz), Vector3(0, 0, side * -0.5))
	if not male and int(look["mouth"]) != 2:
		_p(head, box(Vector3(0.024, 0.0055, 0.007)), lip.lightened(0.08), Vector3(0, my - 0.0065, mz + 0.001))
	_build_hair(head, rings, hc, male)


## Pelo de mujer: flequillo ladeado y mechones a los lados de la cara.
func _frame_face(head: Node3D, hc: Color, lock_len: float, bangs := true) -> void:
	if bangs:
		_p(head, loft([[0.0, 0.075, 0.016], [0.03, 0.082, 0.02, 0.0, 0.004]], 7, false, 0.5, PI), hc.darkened(0.04), Vector3(0.0, 0.052, -0.084), Vector3(0.12, 0, 0.18))
	if lock_len <= 0.0:
		return
	for side in [-1, 1]:
		_p(head, loft([[0.0, 0.022, 0.03], [-lock_len * 0.5, 0.02, 0.026, side * 0.004, -0.004], [-lock_len, 0.012, 0.016, side * 0.008, 0.0]], 5), hc, Vector3(side * 0.083, 0.06, -0.05), Vector3(0.1, 0, side * 0.05))


## Mechones: pirámides que salen del casquete (pelo despeinado).
func _spikes(head: Node3D, hc: Color, count: int, front_bias: float, seed_: int, length := 0.045) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	for i in count:
		var a := rng.randf_range(0, TAU)
		var up := rng.randf_range(0.3, 0.9)
		var dir := Vector3(cos(a) * (1.0 - up), up, sin(a) * (1.0 - up)).normalized()
		if dir.z < 0.0:
			dir.z *= front_bias
		var pos := Vector3(dir.x * 0.088, 0.075 + dir.y * 0.05, dir.z * 0.098 + 0.014)
		var holder := Node3D.new()
		holder.position = pos
		head.add_child(holder)
		# peinado hacia atrás: apunta sobre todo a la nuca, un poco hacia fuera
		var out := (dir * 0.45 + Vector3(dir.x * 0.3, -0.1, 1.0)).normalized()
		var basis := Basis.looking_at(out, Vector3.UP if absf(out.y) < 0.95 else Vector3.FORWARD)
		holder.basis = basis * Basis(Vector3.RIGHT, -PI / 2.0)
		_p(holder, loft([[0.0, 0.026, 0.014], [length * 0.6, 0.016, 0.01], [length, 0.003, 0.003]], 4), hc.darkened(rng.randf() * 0.12))


func _build_hair(head: Node3D, rings: Array, hc: Color, male: bool) -> void:
	var style := int(look["hair"])
	# casquete: la parte alta de la cabeza algo más grande; la frente queda libre
	var cap := func(g: float, from_y: float):
		_p(head, loft(grow(slice(rings, 0.2, from_y), g, g * 1.02), 10), hc)
		# nuca: media vuelta trasera para que el pelo baje por detrás
		_p(head, loft(grow(slice(rings, from_y + 0.001, -0.04), g, g * 1.02), 10, false, 0.5, 0.0), hc)
	if male:
		match style:
			0:
				cap.call(1.015, 0.05)
			1:
				cap.call(1.05, 0.045)
				_spikes(head, hc, 18, 0.6, 11, 0.06)
			2:
				cap.call(1.04, 0.05)
				_spikes(head, hc, 12, 0.3, 21, 0.05)
				_p(head, loft([[0.0, 0.07, 0.05], [0.05, 0.06, 0.045, 0.0, -0.02], [0.07, 0.03, 0.03, 0.0, -0.03]], 7), hc, Vector3(0, 0.1, -0.03), Vector3(-0.35, 0, 0))
			3:
				cap.call(1.07, 0.045)
				_spikes(head, hc, 16, 0.5, 31, 0.07)
				_p(head, loft([[0.06, 0.098, 0.085, 0.0, 0.025], [-0.04, 0.102, 0.09, 0.0, 0.03], [-0.13, 0.098, 0.075, 0.0, 0.04]], 9, true, 0.66, -0.3 * PI), hc)
			4:
				cap.call(1.05, 0.045)
				_spikes(head, hc, 18, 0.6, 41, 0.06)
				_beard(head, rings, hc)
	else:
		match style:
			0:
				cap.call(1.06, 0.04)
				_spikes(head, hc, 14, 0.9, 51, 0.045)
				_frame_face(head, hc, 0.07)
			1:
				cap.call(1.05, 0.04)
				_spikes(head, hc, 6, 0.4, 61, 0.035)
				_frame_face(head, hc, 0.12)
				_p(head, loft([[0.0, 0.03, 0.03], [-0.07, 0.032, 0.03], [-0.16, 0.018, 0.018], [-0.2, 0.006, 0.006]], 6), hc, Vector3(0, 0.07, 0.115), Vector3(-0.35, 0, 0))
			2:
				cap.call(1.07, 0.04)
				_spikes(head, hc, 6, 0.4, 61, 0.035)
				_frame_face(head, hc, 0.2)
				_p(head, loft([[0.07, 0.1, 0.085, 0.0, 0.025], [-0.05, 0.105, 0.095, 0.0, 0.03], [-0.2, 0.11, 0.085, 0.0, 0.045], [-0.27, 0.095, 0.06, 0.0, 0.055]], 10, true, 0.7, -0.35 * PI), hc)
			3:
				cap.call(1.04, 0.04)
				_frame_face(head, hc, 0.1)
				_p(head, loft([[0.0, 0.04, 0.04], [0.03, 0.05, 0.05], [0.07, 0.03, 0.03]], 7), hc, Vector3(0, 0.1, 0.085), Vector3(0.6, 0, 0))
			4:
				cap.call(1.05, 0.04)
				_frame_face(head, hc, 0.0)
				for side in [-1, 1]:
					_p(head, loft([[0.0, 0.016, 0.016], [-0.06, 0.02, 0.018], [-0.12, 0.016, 0.016], [-0.18, 0.019, 0.017], [-0.24, 0.012, 0.012]], 5), hc, Vector3(side * 0.07, -0.02, -0.02), Vector3(-0.1, 0, side * 0.08))


func _beard(head: Node3D, rings: Array, hc: Color) -> void:
	var low := grow(slice(rings, -0.03, -0.14), 1.06, 1.06)
	_p(head, loft(low, 10, false, 0.6, PI * 0.9), hc)
	_p(head, loft([[0.0, 0.034, 0.008], [0.012, 0.03, 0.008]], 6), hc.darkened(0.1), Vector3(0, -0.044, -0.098))


# ---------------------------------------------------------------- ropa

func _has(slot: String) -> bool:
	return str(outfit.get(slot, "")) != ""


func _build_underwear(d: Dictionary) -> void:
	var under := Color("d8d3c6") if d["male"] else Color("cdc4b4")
	if not d["male"] and not _has("torso"):
		_p(j["spine"], loft(grow(slice(_torso(d), 0.36 * float(d["s"]), 0.18 * float(d["s"])), 1.04, 1.07), 10, false), under)
	if _has("piernas"):
		return
	_p(j["hips"], loft(grow(slice(_pelvis(d), 0.05, -0.14), 1.04, 1.05), 9), under)
	for side in [-1, 1]:
		_p(j["leg_" + ("l" if side < 0 else "r")], loft(grow(slice(_thigh(d), 0.04, -0.07), 1.08), 8, false), under)


func _build_outfit(d: Dictionary) -> void:
	var s: float = d["s"]
	var ws: float = d["waist"]
	var ch: float = d["chest"]
	var ar: float = d["arm"]
	var lg: float = d["leg"]
	var spine: Node3D = j["spine"]
	var t := str(outfit.get("torso", ""))
	if t != "":
		var c: Color = CLOTH.get(t, Color.GRAY)
		var g := 1.06 if t == "camiseta" else 1.1
		var shirt := grow(slice(_torso(d), 0.47 * s, -0.05), g, g * 1.04)
		shirt.push_front([-0.06, 0.142 * ws * g, 0.097 * ws * g])
		_p(spine, loft(shirt, 10, false), c)
		_p(spine, loft([[-0.06, 0.15 * ws * g, 0.103 * ws * g], [-0.035, 0.15 * ws * g, 0.103 * ws * g]], 10, false), c.darkened(0.12))
		for side in [-1, 1]:
			var tag := "l" if side < 0 else "r"
			var arm: Node3D = j["arm_" + tag]
			var sleeve_len: float = float(d["upper"]) * (0.45 if t == "camiseta" else 1.0)
			if t != "chaleco":
				var sl := grow(slice(_upper_arm(d), 0.08, -sleeve_len), 1.18)
				var end_r: Array = sl[sl.size() - 1]
				sl.append([-sleeve_len, float(end_r[1]), float(end_r[2])])
				_p(arm, loft(sl, 8, false), c)
				_p(arm, loft([[-sleeve_len + 0.018, float(end_r[1]) * 1.08, float(end_r[2]) * 1.08], [-sleeve_len, float(end_r[1]) * 1.08, float(end_r[2]) * 1.08]], 8, false), c.darkened(0.15))
			if t == "chaqueta_piel":
				var elbow: Node3D = j["elbow_" + tag]
				_p(elbow, loft(grow(_fore_arm(d).slice(0, 3), 1.2), 8, false), c)
				_p(elbow, loft([[-float(d["fore"]) * 0.6, 0.041 * ar, 0.038 * ar], [-float(d["fore"]) * 0.7, 0.04 * ar, 0.037 * ar]], 8, false), c.darkened(0.2))
		if t == "camiseta":
			# cuello en pico (triángulo de piel)
			_p(spine, loft([[0.0, 0.002, 0.002], [0.055, 0.024, 0.002]], 3, true, 1.0, -PI / 2.0), SKINS[clampi(int(look["skin"]), 0, 4)], Vector3(0, 0.405 * s, -0.12 * ch * g))
		elif t == "chaqueta_piel":
			_p(spine, loft([[0.0, 0.085, 0.07], [0.06, 0.09, 0.075]], 9, false), c.darkened(0.15), Vector3(0, 0.45 * s, 0.005))
			_p(spine, box(Vector3(0.008, 0.42 * s, 0.01)), c.darkened(0.35), Vector3(0, 0.2 * s, -0.128 * ch))
			for side in [-1, 1]:
				_p(spine, box(Vector3(0.06, 0.05, 0.012)), c.darkened(0.12), Vector3(side * 0.07, 0.3 * s, -0.122 * ch))
		elif t == "chaleco":
			_p(spine, box(Vector3(0.27, 0.3 * s, 0.035)), c, Vector3(0, 0.25 * s, -0.125 * ch))
			_p(spine, box(Vector3(0.27, 0.32 * s, 0.035)), c, Vector3(0, 0.26 * s, 0.11 * ch))
			for i in 4:
				_p(spine, box(Vector3(0.055, 0.075, 0.03)), c.darkened(0.12), Vector3(-0.09 + i * 0.06, 0.15 * s, -0.152 * ch))
			for side in [-1, 1]:
				_p(spine, box(Vector3(0.05, 0.04, 0.26)), c.darkened(0.08), Vector3(side * 0.085, 0.43 * s, -0.005))
	var pz := str(outfit.get("piernas", ""))
	if pz != "":
		var c2: Color = CLOTH.get(pz, Color.GRAY)
		_p(j["hips"], loft(grow(_pelvis(d), 1.06, 1.08), 9), c2)
		_p(j["hips"], loft([[0.07, 0.14 * ws * 1.08, 0.095 * ws * 1.1], [0.05, 0.14 * ws * 1.08, 0.095 * ws * 1.1]], 9, false), Color("2e2a26"))
		for side in [-1, 1]:
			var tag := "l" if side < 0 else "r"
			_p(j["leg_" + tag], loft(grow(_thigh(d), 1.12, 1.14), 8, false), c2)
			_p(j["knee_" + tag], loft(grow(_shin(d), 1.2, 1.22), 8, false), c2)
			_p(j["knee_" + tag], loft([[0.03, 0.062 * lg, 0.066 * lg], [-0.03, 0.064 * lg, 0.068 * lg]], 8, false), c2.darkened(0.1))
			var sh: float = d["shin"]
			_p(j["knee_" + tag], loft([[-sh * 0.86, 0.05, 0.052], [-sh * 0.97, 0.052, 0.054]], 8, false), c2.darkened(0.15))
			if pz == "pantalon_cargo":
				_p(j["leg_" + tag], box(Vector3(0.025, 0.1, 0.08)), c2.darkened(0.15), Vector3(side * 0.085 * lg, -float(d["thigh"]) * 0.5, 0))
				_p(j["leg_" + tag], box(Vector3(0.02, 0.025, 0.084)), c2.darkened(0.25), Vector3(side * 0.088 * lg, -float(d["thigh"]) * 0.5 + 0.045, 0))
	var pies := str(outfit.get("pies", ""))
	if pies != "":
		var c3: Color = CLOTH.get(pies, Color.GRAY)
		for side in [-1, 1]:
			var tag := "l" if side < 0 else "r"
			_p(j["foot_" + tag], loft(grow(_foot(), 1.16, 1.2), 7), c3, Vector3(0, 0.004, 0), Vector3(-PI / 2.0, 0, 0))
			var sole: Array = []
			for fr in _foot():
				sole.append([float(fr[0]) * 1.06, float(fr[1]) * 1.2, 0.008, 0.0, -0.072])
			_p(j["foot_" + tag], loft(sole, 7), c3.darkened(0.45) if pies == "botas" else Color("d8d4cc"), Vector3.ZERO, Vector3(-PI / 2.0, 0, 0))
			if pies == "botas":
				var sh2: float = d["shin"]
				_p(j["knee_" + tag], loft([[-sh2 * 0.62, 0.05, 0.052], [-sh2 - 0.01, 0.042, 0.046]], 8), c3)
				_p(j["knee_" + tag], loft([[-sh2 * 0.6, 0.053, 0.055], [-sh2 * 0.65, 0.053, 0.055]], 8, false), c3.darkened(0.25))
	var cab := str(outfit.get("cabeza", ""))
	if cab != "":
		var c4: Color = CLOTH.get(cab, Color.GRAY)
		var hr := grow(slice(_head_rings(), 0.2, 0.045), 1.12, 1.1)
		if cab == "gorra":
			_p(j["head"], loft(hr, 10), c4, Vector3(0, 0.012, 0))
			_p(j["head"], loft([[0.0, 0.07, 0.06, 0.0, -0.03], [0.006, 0.07, 0.06, 0.0, -0.03]], 8, true, 0.5, PI), c4.darkened(0.15), Vector3(0, 0.055, -0.06))
		else:
			_p(j["head"], loft(grow(hr, 1.1, 1.08), 10), c4, Vector3(0, 0.02, 0))
			_p(j["head"], loft([[0.0, 0.112, 0.13], [0.008, 0.112, 0.13]], 10), c4.darkened(0.1), Vector3(0, 0.06, 0.005))
			_p(j["head"], box(Vector3(0.02, 0.012, 0.22)), c4.darkened(0.08), Vector3(0, 0.15, 0.01))
	if _has("manos"):
		for side in [-1, 1]:
			var hh: Node3D = j["hand_" + ("l" if side < 0 else "r")]
			_p(hh, loft([[0.005, 0.032, 0.022], [-0.035, 0.038, 0.02], [-0.07, 0.037, 0.018]], 6), CLOTH["guantes"], Vector3.ZERO, Vector3(0.15, 0, 0))
	if _has("espalda"):
		var c6: Color = CLOTH["mochila"]
		var back := 0.115 * ch + 0.07
		_p(spine, loft([[0.0, 0.13, 0.06], [0.2 * s, 0.14, 0.07], [0.33 * s, 0.12, 0.06], [0.36 * s, 0.08, 0.03]], 8), c6, Vector3(0, 0.08 * s, back))
		_p(spine, box(Vector3(0.18, 0.1, 0.04)), c6.darkened(0.15), Vector3(0, 0.16 * s, back + 0.07))
		# saco de dormir enrollado encima
		_p(spine, loft([[-0.2, 0.05, 0.05], [0.2, 0.05, 0.05]], 8), Color("8f8460"), Vector3(0, 0.5 * s, back - 0.01), Vector3(0, 0, PI / 2.0))
		for side in [-1, 1]:
			_p(spine, box(Vector3(0.035, 0.36 * s, 0.012)), c6.darkened(0.3), Vector3(side * 0.085, 0.27 * s, -0.12 * ch - 0.012))


# ============================================================== animación

## Paso de andar: phase avanza con la velocidad, amount 0..1.
func animate_walk(phase: float, amount: float) -> void:
	if j.is_empty():
		return
	var s := sin(phase) * 0.55 * amount
	j["leg_l"].rotation.x = s
	j["leg_r"].rotation.x = -s
	j["knee_l"].rotation.x = maxf(0.0, -sin(phase)) * 0.75 * amount
	j["knee_r"].rotation.x = maxf(0.0, sin(phase)) * 0.75 * amount
	j["arm_l"].rotation.x = -s * 0.7
	j["arm_r"].rotation.x = s * 0.7
	j["spine"].rotation.y = s * 0.1
	var d := dims()
	j["hips"].position.y = float(d["thigh"]) + float(d["shin"]) + float(d["ankle"]) + 0.06 + absf(cos(phase)) * 0.02 * amount


## Golpe con el brazo derecho (0..1).
func animate_swing(t: float) -> void:
	if j.is_empty():
		return
	j["arm_r"].rotation.x = -sin(t * PI) * 2.0
	j["elbow_r"].rotation.x = -0.12 - sin(t * PI) * 0.6
