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

const SKINS := [Color("efcfb4"), Color("d6a98d"), Color("bf855d"), Color("8a5a3c"), Color("5a3a28")]
const HAIR_COLORS := [Color("221a15"), Color("46382f"), Color("b8914e"), Color("8e3a1c"), Color("a9a49c")]
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
	"mochila_excursion": Color("3f5f73"), "mochila_tactica": Color("4b4d3f"),
	"traje_buzo": Color("27313a"),
}

var look := {"sex": "m", "skin": 1, "hair": 1, "hair_color": 1, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 1}
var physique := {"fuerza": 0.0, "resistencia": 0.0}
var outfit := {"cabeza": "", "torso": "", "piernas": "", "pies": "", "manos": "", "espalda": ""}
var tint: Dictionary = {}    # color propio de una prenda (infectados): {"camiseta": Color}
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
		var shp: Array = r[5] if r.size() > 5 else []
		for i in n:
			var a := arc_start + TAU * arc * float(i) / float(sides)
			var f := 1.0 if shp.is_empty() else _shape(shp, a)
			row.append(Vector3(cx + cos(a) * float(r[1]) * f, float(r[0]), cz + sin(a) * float(r[2]) * f))
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
			if (i + k) % 2 == 0:
				tris.append([r0[i], r1[i2], r1[i]])
				tris.append([r0[i], r0[i2], r1[i2]])
			else:   # diagonal alternada: caras en rombo, como el low poly del diseño
				tris.append([r0[i], r0[i2], r1[i]])
				tris.append([r0[i2], r1[i2], r1[i]])
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
		st.set_color(Color.WHITE)   # un solo tono por cara: lo da la luz
		st.add_vertex(t[0])
		st.add_vertex(t[1])
		st.add_vertex(t[2])
	st.generate_normals()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


static func _bell(v: float, c: float, w: float) -> float:
	return maxf(0.0, 1.0 - pow((v - c) / w, 2.0))


## Relieve muscular de un anillo: [tipo, cantidad]. La cara de delante es -z.
static func _shape(shp: Array, a: float) -> float:
	var x := cos(a)
	var front := maxf(0.0, -sin(a))
	var back := maxf(0.0, sin(a))
	var k := float(shp[1])
	match str(shp[0]):
		"pec":     # pectorales: dos bultos delante
			return 1.0 + k * front * _bell(absf(x), 0.45, 0.4)
		"abs":     # abdominales: dos columnas con surco en el centro
			return 1.0 + k * front * _bell(absf(x), 0.4, 0.38) - k * 0.4 * front * _bell(x, 0.0, 0.2)
		"back":    # omóplatos
			return 1.0 + k * back * _bell(absf(x), 0.5, 0.4)
		"quad":    # cuádriceps
			return 1.0 + k * front * _bell(x, 0.0, 0.9)
		"knee":    # rótula
			return 1.0 + k * front * _bell(x, 0.0, 0.55)
		"calf":    # gemelos
			return 1.0 + k * back
		"bicep":
			return 1.0 + k * front * _bell(x, 0.0, 0.8)
		"jaw":     # esquinas de la mandíbula
			return 1.0 + k * front * _bell(absf(x), 0.72, 0.3) - k * 0.5 * front * _bell(x, 0.0, 0.25)
		"cheek":   # pómulos
			return 1.0 + k * front * _bell(absf(x), 0.62, 0.3)
	return 1.0


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
	if _tag >= 0:
		mi.set_meta("capa", _tag)
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
		if c.size() > 5 and f >= 1.05:   # la ropa suaviza el relieve
			c[5] = [c[5][0], float(c[5][1]) * 0.5]
		out.append(c)
	return out


## Anillo interpolado a una altura (sin relieve).
static func ring_at(rings: Array, y: float) -> Array:
	for k in rings.size() - 1:
		var a: Array = rings[k]
		var b: Array = rings[k + 1]
		if (float(a[0]) - y) * (float(b[0]) - y) <= 0.0:
			var t := (y - float(a[0])) / (float(b[0]) - float(a[0]) + 0.00001)
			var out := [y]
			for i in range(1, 5):
				var va: float = float(a[i]) if a.size() > i else 0.0
				var vb: float = float(b[i]) if b.size() > i else 0.0
				out.append(lerpf(va, vb, t))
			return out
	return rings.back().duplicate()


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
		"thigh": 0.385 * s, "shin": (0.355 if male else 0.385 * s), "ankle": 0.08 * s,
		"upper": (0.3 if male else 0.29 * s), "fore": (0.2 if male else 0.25 * s),
		"shoulder": (0.23 if male else 0.155) * s * (1.0 + 0.12 * f),
		"arm": (1.0 if male else 0.9) * (1.0 + 0.5 * f),
		"leg": (1.0 if male else 1.0) * (1.0 + 0.28 * f),
		"chest": (1.0 if male else 0.88) * (1.0 + 0.14 * f),
		"waist": (1.0 if male else 0.86) * (1.0 - 0.08 * r) * (1.0 + 0.04 * f),
		"hips": (0.95 if male else 1.1),
	}


# --------------------------------------------------- perfiles anatómicos

func _pelvis(d: Dictionary) -> Array:
	var h: float = d["hips"]
	var w: float = d["waist"]
	if d["male"]:   # medidas del diseño de frente y de perfil
		return [[0.1, 0.14 * w, 0.1 * w], [0.03, 0.15, 0.108, 0.0, -0.004], [-0.06, 0.148, 0.112, 0.0, -0.008], [-0.13, 0.124, 0.1, 0.0, -0.006], [-0.17, 0.075, 0.07, 0.0, 0.0]]
	return [[0.08, 0.135 * w, 0.09 * w], [0.03, 0.142 * h, 0.095 * h], [-0.04, 0.15 * h, 0.1 * h], [-0.1, 0.125 * h, 0.088 * h], [-0.14, 0.08 * h, 0.066, 0.0, 0.005]]


func _torso(d: Dictionary) -> Array:
	var c: float = d["chest"]
	var w: float = d["waist"]
	var s: float = d["s"]
	var sh: float = d["shoulder"]
	if d["male"]:
		# tronco medido del diseño: cintura, abdominales, pectorales, hombros y trapecio
		return [
			[0.0, 0.14 * w, 0.1 * w, 0.0, 0.0, ["abs", 0.03]],
			[0.04 * s, 0.136 * w, 0.105 * w, 0.0, -0.004, ["abs", 0.12]],
			[0.09 * s, 0.131 * w, 0.108 * w, 0.0, -0.006, ["abs", 0.04]],
			[0.14 * s, 0.135 * c, 0.108 * c, 0.0, -0.006, ["abs", 0.12]],
			[0.19 * s, 0.148 * c, 0.112 * c, 0.0, -0.008, ["pec", 0.09]],
			[0.235 * s, 0.163 * c, 0.13 * c, 0.0, 0.0, ["pec", 0.24]],
			[0.28 * s, 0.17 * c, 0.138 * c, 0.0, 0.006, ["pec", 0.08]],
			[0.33 * s, 0.175 * c, 0.13 * c, 0.0, 0.014, ["back", 0.08]],
			[0.38 * s, 0.19 * c, 0.11 * c, 0.0, 0.02],
			[0.42 * s, 0.17 * c, 0.09 * c, 0.0, 0.025],
			[0.45 * s, 0.135 * c, 0.075 * c, 0.0, 0.03],
			[0.475 * s, 0.085, 0.066, 0.0, 0.035],
		]
	var bust := 0.022
	return [
		[0.0, 0.135 * w, 0.09 * w],
		[0.09 * s, 0.14 * w, 0.095 * w],
		[0.19 * s, 0.155 * c, 0.105 * c + bust * 0.5, 0.0, -bust * 0.5],
		[0.27 * s, 0.17 * c, 0.115 * c + bust, 0.0, -bust],
		[0.35 * s, 0.178 * c, 0.11 * c + bust * 0.4, 0.0, -bust * 0.4],
		[0.405 * s, sh * 0.98, 0.1 * c],
		[0.445 * s, sh * 0.8, 0.085 * c],
		[0.48 * s, 0.09 * c, 0.065 * c],
		[0.5 * s, 0.055, 0.05],
	]


func _thigh(d: Dictionary) -> Array:
	var g: float = d["leg"]
	var t: float = d["thigh"]
	if d["male"]:
		return [[0.03, 0.08 * g, 0.09 * g], [-0.06, 0.08 * g, 0.095 * g, 0.0, -0.004, ["quad", 0.05]], [-0.2, 0.073 * g, 0.088 * g, 0.0, -0.005, ["quad", 0.1]], [-0.3, 0.058 * g, 0.07 * g, 0.0, -0.004, ["quad", 0.08]], [-0.36, 0.046 * g, 0.068 * g, 0.0, 0.0, ["knee", 0.1]], [-t - 0.015, 0.044 * g, 0.064 * g, 0.0, 0.0, ["knee", 0.14]]]
	return [[0.03, 0.08 * g, 0.084 * g], [-0.06, 0.084 * g, 0.088 * g, 0.0, -0.004, ["quad", 0.05]], [-t * 0.4, 0.074 * g, 0.078 * g, 0.0, -0.008, ["quad", 0.1]], [-t * 0.72, 0.058 * g, 0.062 * g, 0.0, -0.006, ["quad", 0.09]], [-t * 0.9, 0.046 * g, 0.05 * g, 0.0, -0.008], [-t - 0.015, 0.044 * g, 0.048 * g, 0.0, -0.01]]


func _shin(d: Dictionary) -> Array:
	var g: float = d["leg"]
	var sh: float = d["shin"]
	if d["male"]:
		return [[0.01, 0.043 * g, 0.064 * g, 0.0, 0.0, ["knee", 0.12]], [-0.04, 0.044 * g, 0.066 * g, 0.0, 0.008], [-0.1, 0.062 * g, 0.076 * g, 0.0, 0.032, ["calf", 0.06]], [-0.2, 0.042 * g, 0.064 * g, 0.0, 0.034], [-0.3, 0.03 * g, 0.054 * g, 0.0, 0.026], [-sh - 0.01, 0.028, 0.044, 0.0, 0.016]]
	return [[0.01, 0.044 * g, 0.048 * g, 0.0, -0.01], [-sh * 0.12, 0.044 * g, 0.05 * g, 0.0, 0.0], [-sh * 0.3, 0.05 * g, 0.06 * g, 0.0, 0.012, ["calf", 0.09]], [-sh * 0.5, 0.044 * g, 0.05 * g, 0.0, 0.008], [-sh * 0.78, 0.03 * g, 0.033 * g], [-sh - 0.01, 0.028 * g, 0.03 * g]]


func _foot() -> Array:
	# a lo largo del pie (luego se gira para que apunte hacia delante)
	return [[-0.055, 0.032, 0.035, 0.0, -0.03], [-0.01, 0.04, 0.05, 0.0, -0.03], [0.07, 0.046, 0.036, 0.0, -0.046], [0.15, 0.044, 0.024, 0.0, -0.058], [0.185, 0.032, 0.016, 0.0, -0.062]]


func _upper_arm(d: Dictionary, side := 0) -> Array:
	var a: float = d["arm"]
	var u: float = d["upper"]
	var o := float(side) * 0.012 * a   # el deltoides abulta hacia fuera
	if d["male"]:
		return [[0.045, 0.032 * a, 0.034 * a, o * 0.3], [0.025, 0.058 * a, 0.058 * a, o * 0.7], [-0.03, 0.068 * a, 0.064 * a, o * 1.2], [-0.08, 0.06 * a, 0.06 * a, o * 0.8, 0.0, ["bicep", 0.06]], [-0.15, 0.055 * a, 0.058 * a, o * 0.4, -0.004, ["bicep", 0.12]], [-0.24, 0.046 * a, 0.048 * a], [-u - 0.01, 0.038 * a, 0.04 * a]]
	# hombro redondo, deltoides, bíceps y codo estrecho
	return [[0.045, 0.02 * a, 0.022 * a, o * 0.3], [0.035, 0.042 * a, 0.044 * a, o * 0.7], [0.012, 0.056 * a, 0.056 * a, o], [-0.03, 0.058 * a, 0.054 * a, o, 0.0, ["bicep", 0.05]], [-0.07, 0.048 * a, 0.05 * a, o * 0.4, -0.004, ["bicep", 0.1]], [-u * 0.5, 0.047 * a, 0.052 * a, 0.0, -0.006, ["bicep", 0.14]], [-u * 0.8, 0.04 * a, 0.042 * a], [-u - 0.01, 0.034 * a, 0.036 * a]]


func _fore_arm(d: Dictionary) -> Array:
	var a: float = d["arm"]
	var fo: float = d["fore"]
	if d["male"]:
		return [[0.01, 0.038 * a, 0.038 * a], [-0.05, 0.045 * a, 0.041 * a], [-0.11, 0.037 * a, 0.033 * a], [-0.17, 0.028 * a, 0.024 * a], [-fo - 0.005, 0.025 * a, 0.021 * a]]
	return [[0.01, 0.036 * a, 0.038 * a], [-fo * 0.2, 0.046 * a, 0.042 * a], [-fo * 0.45, 0.04 * a, 0.035 * a], [-fo * 0.78, 0.028 * a, 0.025 * a], [-fo, 0.024 * a, 0.02 * a]]


func _head_rings() -> Array:
	# y relativo al centro de la cabeza; cz < 0 adelanta la cara
	return [
		[-0.122, 0.036, 0.034, 0.0, -0.04],
		[-0.108, 0.062, 0.06, 0.0, -0.028, ["jaw", 0.1]],
		[-0.075, 0.074, 0.086, 0.0, -0.014, ["jaw", 0.1]],
		[-0.035, 0.082, 0.096, 0.0, -0.005, ["cheek", 0.05]],
		[0.005, 0.087, 0.1, 0.0, 0.0, ["cheek", 0.03]],
		[0.045, 0.09, 0.102, 0.0, 0.004],
		[0.082, 0.085, 0.098, 0.0, 0.01],
		[0.11, 0.066, 0.08, 0.0, 0.014],
		[0.128, 0.03, 0.04, 0.0, 0.014],
	]


# ============================================================ construcción

func rebuild() -> void:
	for c in get_children():
		remove_child(c)   # fuera ya: si no, los nombres nuevos chocan con los viejos
		c.queue_free()
	j.clear()
	_parts.clear()
	_skel = null
	_skin_mi = null
	process_priority = 100   # después de las animaciones del frame
	var d := dims()
	var skin: Color = SKINS[clampi(int(look["skin"]), 0, 4)]
	if look.has("skin_color"):    # infectados: piel fuera de la paleta
		skin = look["skin_color"]
	var e := explode
	var s: float = d["s"]

	var hip_h: float = float(d["thigh"]) + float(d["shin"]) + float(d["ankle"]) + 0.06
	var hips := _joint(self, "hips", Vector3(0, hip_h, 0))
	_tag = 0 if _proj() else -1
	_p(hips, loft(_pelvis(d), 9), skin)

	for side in [-1, 1]:
		var tag := "l" if side < 0 else "r"
		var leg := _joint(hips, "leg_" + tag, Vector3(side * (0.094 if d["male"] else 0.082 * s * float(d["hips"])) + side * e * 0.12, -0.06 - e * 0.1, 0))
		leg.rotation.z = side * 0.06   # piernas algo abiertas
		_p(leg, loft(_thigh(d), 9), skin)
		var knee := _joint(leg, "knee_" + tag, Vector3(0, -float(d["thigh"]) - e * 0.08, 0))
		_p(knee, loft(_shin(d), 9), skin)
		var foot := _joint(knee, "foot_" + tag, Vector3(0, -float(d["shin"]) - e * 0.06, 0))
		_p(foot, loft(_foot(), 7), skin, Vector3.ZERO, Vector3(-PI / 2.0, 0, 0))

	var spine := _joint(hips, "spine", Vector3(0, (0.1 if d["male"] else 0.07) + e * 0.12, 0))
	_p(spine, loft(_torso(d), 12), skin)

	var head := _joint(spine, "head", Vector3(0, (0.61 if d["male"] else 0.63 * s) + e * 0.18, -0.018 if d["male"] else 0.0))
	head.scale = Vector3(1.1, 1.1, 1.2) if d["male"] else Vector3.ONE * 0.97
	_build_head(head, skin)

	for side in [-1, 1]:
		var tag := "l" if side < 0 else "r"
		var arm := _joint(spine, "arm_" + tag, Vector3(side * (float(d["shoulder"]) - 0.03 + e * 0.22), (0.33 if d["male"] else 0.365 * s), 0.0))
		arm.rotation.z = side * 0.22
		_p(arm, loft(_upper_arm(d, side), 9), skin)
		var elbow := _joint(arm, "elbow_" + tag, Vector3(0, -float(d["upper"]) - e * 0.06, 0))
		elbow.rotation.x = 0.12   # codo algo doblado (positivo = la mano va hacia delante)
		_p(elbow, loft(_fore_arm(d), 8), skin)
		var h := _joint(elbow, "hand_" + tag, Vector3(0, -float(d["fore"]) - e * 0.05, 0))
		_build_hand(h, side, skin)
		if side > 0:
			hand = Node3D.new()
			hand.name = "Hand"
			hand.position = Vector3(0, -0.06, -0.015)
			h.add_child(hand)

	if _tag >= 0:
		_tag = 2
	_build_underwear(d)
	_tag = -1
	_build_outfit(d)
	_rest_q.clear()
	for jn in j:
		_rest_q[jn] = (j[jn] as Node3D).quaternion
	merge_parts()


## Piel continua: todas las piezas pasan a UNA malla deformada por un esqueleto
## que copia las articulaciones. Así rodillas, codos, hombros y cuello se doblan
## sin huecos ni piezas que se cruzan. La mano del arma ("Hand") queda aparte.
## [y del punto de unión con el padre, ancho de la mezcla, 1 = la pieza crece hacia arriba]
const BLEND := {"leg": [0.0, 0.07, 0], "knee": [0.0, 0.06, 0], "foot": [0.0, 0.035, 0], "arm": [0.0, 0.06, 0],
	"elbow": [0.0, 0.05, 0], "hand": [0.0, 0.03, 0], "spine": [0.0, 0.06, 1], "head": [-0.13, 0.04, 1]}

## Textura del diseño (tools/iconos/personaje.py): cada triángulo de piel, pelo y ropa
## interior toma las sombras y la cara del dibujo de frente/perfil del usuario.
const DESIGN_TEX := "res://assets/characters/superviviente.png"
const DESIGN_ATLAS := Vector2(2430, 1240)
const DESIGN_LAYER := 810.0
const DESIGN_FRONT := [130.0, 30.0, 2.0]          # columna, fila, escala
const DESIGN_SIDE := [680.0, 30.0, 1.5, 540.0]
const DESIGN_PX := 0.003017                      # metros por píxel del dibujo
const DESIGN_CX := [266.47, -0.003, 765.69, -0.0038]   # centro del dibujo / del modelo (frente, perfil)
var design := true    # los infectados lo desactivan
var _tag := -1        # capa de la pieza que se está creando (0 piel, 1 pelo, 2 ropa interior)
static var _design_mat: StandardMaterial3D

var _parts: Array = []      # [nombre de articulación, malla, transform local, color]
var _skel: Skeleton3D
var _skin_mi: MeshInstance3D
var _bones: Array = []      # articulación de cada hueso


func merge_parts() -> void:
	if j.is_empty():
		return
	# recoge las piezas nuevas de cada articulación (las de rebuild y las que añada el infectado)
	for jn in j:
		_collect(jn, j[jn], Transform3D.IDENTITY)
	_build_skin()


func _collect(jn: String, n: Node3D, xf: Transform3D) -> void:
	for c in n.get_children():
		if c.name == "Hand" or (j.has(String(c.name)) and j[String(c.name)] == c) or not (c is Node3D):
			continue
		if not (c is MeshInstance3D):
			_collect(jn, c, xf * (c as Node3D).transform)   # soportes (mechones de pelo...)
			if c.get_child_count() == 0:
				c.queue_free()
			continue
		if c.has_meta("rigid"):
			continue
		var m: Material = c.material_override
		if not (m is StandardMaterial3D) or m.emission_enabled or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			c.set_meta("rigid", true)   # brillos y transparencias: se quedan como pieza aparte
			continue
		_parts.append([jn, c.mesh, xf * c.transform, (m as StandardMaterial3D).albedo_color, int(c.get_meta("capa", -1))])
		n.remove_child(c)
		c.free()


static func _kind(jn: String) -> String:
	return jn.get_slice("_", 0)


func _build_skin() -> void:
	if _skel == null or not is_instance_valid(_skel):
		_skel = Skeleton3D.new()
		_skel.name = "Piel"
		add_child(_skel)
		_bones.clear()
		var todo: Array = [j["hips"]]
		var idx := {}
		while not todo.is_empty():
			var n: Node3D = todo.pop_front()
			var b := _skel.add_bone(n.name)
			var par := n.get_parent()
			_skel.set_bone_parent(b, idx[par.name] if idx.has(par.name) else -1)
			_skel.set_bone_rest(b, n.transform)
			idx[n.name] = b
			_bones.append(n)
			for c in n.get_children():
				if c is Node3D and j.has(String(c.name)) and j[String(c.name)] == c:
					todo.append(c)
		_skel.reset_bone_poses()
		_skin_mi = MeshInstance3D.new()
		_skel.add_child(_skin_mi)
	var bi := {}
	for b in _bones.size():
		bi[String(_bones[b].name)] = b
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_proj := false
	for part in _parts:
		var jn: String = part[0]
		var b: int = bi[jn]
		var rest: Transform3D = _rest_global(_bones[b])
		var lx: Transform3D = part[2]
		var col: Color = part[3]
		var layer: int = part[4] if _proj() else -1
		any_proj = any_proj or layer >= 0
		var arr: Array = (part[1] as Mesh).surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var cs = arr[Mesh.ARRAY_COLOR]
		var ids = arr[Mesh.ARRAY_INDEX]
		var order: PackedInt32Array = ids if ids != null and ids.size() > 0 else PackedInt32Array(range(vs.size()))
		var nb := (lx.basis).inverse().transposed()
		var gb := rest.basis.inverse().transposed()
		for t in range(0, order.size() - 2, 3):
			var gp: Array = []
			for q in 3:
				gp.append(rest * (lx * vs[order[t + q]]))
			var fn := Vector3.ZERO
			for q in 3:
				fn += gb * (nb * ns[order[t + q]])
			# ¿el triángulo mira hacia delante? -> vista de frente; si no, de perfil
			var front := fn.normalized().z < -0.3
			for q in 3:
				var vi: int = order[t + q]
				var lp := lx * vs[vi]
				var w := _weights(jn, lp, bi)
				st.set_bones(w[0])
				st.set_weights(w[1])
				var vc: Color = col if cs == null or cs.size() == 0 else col * cs[vi]
				st.set_color(Color(vc.r, vc.g, vc.b, 1.0))
				st.set_normal((gb * (nb * ns[vi])).normalized())
				st.set_uv(_design_uv(gp[q], front, layer))
				st.add_vertex(gp[q])
	var mesh := st.commit()
	_skin_mi.mesh = mesh
	_skin_mi.material_override = _design_material() if any_proj else mat(Color.WHITE)
	var sk := Skin.new()
	for b in _bones.size():
		sk.add_bind(b, _rest_global(_bones[b]).affine_inverse())
	_skin_mi.skin = sk
	_skin_mi.skeleton = NodePath("..")
	_sync_pose()


func _proj() -> bool:
	return design and look.get("sex", "m") == "m"


## Punto del dibujo donde cae un vértice (en reposo): vista de frente o de perfil.
static func _design_uv(p: Vector3, front: bool, layer: int) -> Vector2:
	var neutral := Vector2(1.0 - 1.5 / DESIGN_ATLAS.x, 1.0 - 1.5 / DESIGN_ATLAS.y)
	if layer < 0:
		return neutral
	var row := 640.0 - p.y / DESIGN_PX
	var u: float
	var v: float
	var lo: float
	var hi: float
	if front:
		var col := float(DESIGN_CX[0]) + (-p.x - float(DESIGN_CX[1])) / DESIGN_PX
		u = (col - float(DESIGN_FRONT[0])) * float(DESIGN_FRONT[2])
		v = (row - float(DESIGN_FRONT[1])) * float(DESIGN_FRONT[2])
		lo = 0.0
		hi = float(DESIGN_SIDE[3])
	else:
		var col := float(DESIGN_CX[2]) + (-p.z - float(DESIGN_CX[3])) / DESIGN_PX
		u = float(DESIGN_SIDE[3]) + (col - float(DESIGN_SIDE[0])) * float(DESIGN_SIDE[2])
		v = (row - float(DESIGN_SIDE[1])) * float(DESIGN_SIDE[2])
		lo = float(DESIGN_SIDE[3])
		hi = DESIGN_LAYER
	if u < lo or u >= hi - 1.0 or v < 0.0 or v >= DESIGN_ATLAS.y - 1.0:
		return neutral
	return Vector2((float(layer) * DESIGN_LAYER + u) / DESIGN_ATLAS.x, v / DESIGN_ATLAS.y)


static func _design_material() -> StandardMaterial3D:
	if _design_mat == null:
		_design_mat = mat(Color.WHITE).duplicate() as StandardMaterial3D
		_design_mat.albedo_texture = load(DESIGN_TEX)
		_design_mat.albedo_color = Color(2.0, 2.0, 2.0)   # la textura guarda la mitad del factor
		_design_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _design_mat


## Transformación de reposo de una articulación respecto al personaje.
func _rest_global(n: Node3D) -> Transform3D:
	if n.has_meta("rest"):
		return n.get_meta("rest")
	var t := n.transform
	var p := n.get_parent()
	while p != null and p != self:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	n.set_meta("rest", t)
	return t


## Pesos de un vértice (en coordenadas de su articulación): se reparte con el
## padre cerca de la unión y con el hijo cerca de la siguiente articulación.
func _weights(jn: String, lp: Vector3, bi: Dictionary) -> Array:
	var w := {jn: 1.0}
	var cfg: Array = BLEND.get(_kind(jn), [])
	var par := String(j[jn].get_parent().name)
	if not cfg.is_empty() and bi.has(par):
		var t := (lp.y - float(cfg[0])) / (2.0 * float(cfg[1]))
		var wp := clampf(0.5 - t if int(cfg[2]) == 1 else 0.5 + t, 0.0, 1.0)
		w[jn] = 1.0 - wp
		w[par] = wp
	for c in j[jn].get_children():
		var cn := String(c.name)
		if not j.has(cn) or j[cn] != c:
			continue
		var cc: Array = BLEND.get(_kind(cn), [])
		if cc.is_empty() or _kind(cn) == "arm":
			continue
		var cy: float = (c as Node3D).position.y + float(cc[0]) * (c as Node3D).scale.y
		var t2 := (lp.y - cy) / (2.0 * float(cc[1]))
		var wc := clampf(0.5 + t2 if int(cc[2]) == 1 else 0.5 - t2, 0.0, 1.0)
		if _kind(cn) == "leg":   # cada pierna se lleva su lado de la ingle
			var sx := signf((c as Node3D).position.x)
			wc *= clampf(0.5 + sx * lp.x / 0.08, 0.0, 1.0)
		if wc <= 0.0:
			continue
		for k in w:
			w[k] = float(w[k]) * (1.0 - wc)
		w[cn] = wc
	var items: Array = []
	for k in w:
		if float(w[k]) > 0.001:
			items.append([bi[k], float(w[k])])
	items.sort_custom(func(a, b): return a[1] > b[1])
	items = items.slice(0, 4)
	var tot := 0.0
	for it in items:
		tot += float(it[1])
	var bones := PackedInt32Array()
	var ws := PackedFloat32Array()
	for q in 4:
		bones.append(int(items[q][0]) if q < items.size() else 0)
		ws.append(float(items[q][1]) / tot if q < items.size() else 0.0)
	return [bones, ws]


var auto_idle := false   # vistas previas (inventario, creación): respira solo
var _idle_clock := 0.0


func _process(delta: float) -> void:
	if auto_idle:
		_idle_clock += delta
		animate_walk(0.0, 0.0)
		animate_idle(_idle_clock, 1.0)
	_sync_pose()


## El esqueleto copia la pose de las articulaciones (que mueven las animaciones).
func _sync_pose() -> void:
	if _skel == null or not is_instance_valid(_skel):
		return
	for b in _bones.size():
		var n: Node3D = _bones[b]
		_skel.set_bone_pose_position(b, n.position)
		_skel.set_bone_pose_rotation(b, n.quaternion)
		_skel.set_bone_pose_scale(b, n.scale)


func _build_hand(h: Node3D, side: int, skin: Color) -> void:
	# palma y dedos juntos (manopla facetada) y pulgar aparte
	var hs := Vector3(1.15, 0.88, 1.25) if look.get("sex", "m") == "m" else Vector3.ONE   # mano más maciza
	_p(h, loft([[0.0, 0.026, 0.017], [-0.035, 0.034, 0.016], [-0.065, 0.034, 0.014], [-0.1, 0.028, 0.011], [-0.112, 0.018, 0.008]], 6), skin, Vector3.ZERO, Vector3(0.15, 0, 0), hs)
	_p(h, loft([[0.0, 0.011, 0.011], [-0.03, 0.01, 0.009], [-0.048, 0.007, 0.006]], 5), skin, Vector3(-side * 0.02, -0.018, -0.016) * hs, Vector3(0.45, 0, side * 0.35), hs)


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
	_p(head, loft(rings, 12), skin)
	# cuello
	var nk := 1.18 if male else 1.0
	_p(head, loft([[-0.2, 0.052 * nk, 0.052 * nk, 0.0, 0.01], [-0.09, 0.046 * nk, 0.048 * nk, 0.0, 0.012]], 8), skin)
	# arco de las cejas (relieve) y orejas
	_p(head, loft([[0.0, 0.07, 0.012], [0.02, 0.066, 0.01]], 6, true, 0.5, PI), skin.darkened(0.03), Vector3(0, 0.035, -0.088))
	for side in [-1, 1]:
		_p(head, box(Vector3(0.018, 0.04, 0.03)), skin.darkened(0.06), Vector3(side * 0.089, 0.0, 0.012), Vector3(0, side * 0.25, 0))
	var fz := -0.102
	# Ojos: pequeños y oscuros
	var ec: Color = EYE_COLORS[clampi(int(look["eye_color"]), 0, 4)]
	var es := int(look["eyes"])
	var painted := _proj()   # ojos, cejas y boca ya vienen en la textura del diseño
	for side in ([] if painted else [-1, 1]):
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
	match (-1 if painted else int(look["mouth"])):
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
	var t0 := _tag
	if t0 >= 0:
		_tag = 1
	_build_hair(head, rings, hc, male)
	_tag = t0


## Pelo de mujer: flequillo ladeado y mechones a los lados de la cara.
func _frame_face(head: Node3D, hc: Color, lock_len: float, bangs := true) -> void:
	if bangs:
		_p(head, loft([[0.0, 0.075, 0.016], [0.03, 0.082, 0.02, 0.0, 0.004]], 7, false, 0.5, PI), hc.darkened(0.04), Vector3(0.0, 0.052, -0.084), Vector3(0.12, 0, 0.18))
	if lock_len <= 0.0:
		return
	for side in [-1, 1]:
		_p(head, loft([[0.0, 0.022, 0.03], [-lock_len * 0.5, 0.02, 0.026, side * 0.004, -0.004], [-lock_len, 0.012, 0.016, side * 0.008, 0.0]], 5), hc, Vector3(side * 0.083, 0.06, -0.05), Vector3(0.1, 0, side * 0.05))


## Mechones: pirámides que salen del casquete (pelo despeinado).
func _spikes(head: Node3D, hc: Color, count: int, front_bias: float, seed_: int, length := 0.045, messy := false) -> void:
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
		var ln := length
		if messy:
			# despeinado: de punta y hacia fuera; delante cae sobre la frente
			var jit := Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.1, 0.2), rng.randf_range(-0.3, 0.3))
			out = (dir * 0.75 + Vector3(0.0, -0.2, -0.25) + jit * 0.8).normalized()   # mechones gruesos que caen hacia delante y a los lados
			if dir.z < -0.2:   # mechones que caen sobre la frente
				out = (dir * 0.4 + Vector3(dir.x * 0.5, -0.25, -0.75) + jit * 0.5).normalized()
			ln = length * rng.randf_range(0.75, 1.3)
		var basis := Basis.looking_at(out, Vector3.UP if absf(out.y) < 0.95 else Vector3.FORWARD)
		holder.basis = basis * Basis(Vector3.RIGHT, -PI / 2.0)
		var bw := 2.1 if messy else 1.0
		_p(holder, loft([[0.0, 0.026 * bw, 0.014 * bw], [ln * 0.6, 0.016 * bw, 0.01 * bw], [ln, 0.003, 0.003]], 4), hc.darkened(rng.randf() * 0.12).lightened(rng.randf() * 0.06))


func _build_hair(head: Node3D, rings: Array, hc: Color, male: bool) -> void:
	var style := int(look["hair"])
	# casquete: la parte alta de la cabeza algo más grande; la frente queda libre
	var cap := func(g: float, from_y: float):
		_p(head, loft(grow(slice(rings, 0.2, from_y), g, g * 1.02), 12), hc)
		# nuca: media vuelta trasera para que el pelo baje por detrás
		_p(head, loft(grow(slice(rings, from_y + 0.001, -0.04), g, g * 1.02), 12, false, 0.5, 0.0), hc)
	if male and style != 4 and not _proj():
		_stubble(head, rings, hc)
	if male:
		match style:
			0:
				cap.call(1.015, 0.05)
			1:
				cap.call(1.05, 0.045)
				_spikes(head, hc, 30, 1.0, 11, 0.07, true)
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


## Barba de pocos días: una capa fina, casi del color de la piel.
func _stubble(head: Node3D, rings: Array, hc: Color) -> void:
	var low := grow(slice(rings, -0.06, -0.124), 1.02, 1.02)
	var sk: Color = SKINS[clampi(int(look["skin"]), 0, 4)]
	_p(head, loft(low, 12, false, 0.55, PI * 0.95), sk.lerp(hc, 0.1).darkened(0.03))


func _beard(head: Node3D, rings: Array, hc: Color) -> void:
	var low := grow(slice(rings, -0.03, -0.14), 1.06, 1.06)
	_p(head, loft(low, 12, false, 0.6, PI * 0.9), hc)
	_p(head, loft([[0.0, 0.034, 0.008], [0.012, 0.03, 0.008]], 6), hc.darkened(0.1), Vector3(0, -0.044, -0.098))


# ---------------------------------------------------------------- ropa

func _has(slot: String) -> bool:
	return str(outfit.get(slot, "")) != ""


func _build_underwear(d: Dictionary) -> void:
	var under := Color("a9aca4") if d["male"] else Color("cdc4b4")
	if not d["male"] and not _has("torso"):
		_p(j["spine"], loft(grow(slice(_torso(d), 0.36 * float(d["s"]), 0.18 * float(d["s"])), 1.04, 1.07), 12, false), under)
	if _has("piernas"):
		return
	_p(j["hips"], loft(grow(slice(_pelvis(d), 0.1, -0.17), 1.03, 1.04), 9), under)
	var wb := 1.05
	var pv: Array = _pelvis(d)[0]
	# goma de la cintura, más oscura
	var pt := float(pv[0])
	_p(j["hips"], loft([[pt - 0.04, float(pv[1]) * wb, float(pv[2]) * wb], [pt - 0.005, float(pv[1]) * wb, float(pv[2]) * wb]], 9, false), under.darkened(0.3))
	var leg_len := 0.19 if d["male"] else 0.07
	for side in [-1, 1]:
		var tag := "l" if side < 0 else "r"
		var cut := ring_at(_thigh(d), -leg_len)
		var tr := slice(_thigh(d), 0.04, -leg_len)
		tr.append(cut)
		_p(j["leg_" + tag], loft(grow(tr, 1.04, 1.05), 9, false), under)
		_p(j["leg_" + tag], loft([[-leg_len, float(cut[1]) * 1.07, float(cut[2]) * 1.08, 0.0, -0.004], [-leg_len + 0.012, float(cut[1]) * 1.07, float(cut[2]) * 1.08, 0.0, -0.004]], 9, false), under.darkened(0.12))


func _cloth(id: String) -> Color:
	return tint.get(id, CLOTH.get(id, Color.GRAY))


func _build_outfit(d: Dictionary) -> void:
	var s: float = d["s"]
	var ws: float = d["waist"]
	var ch: float = d["chest"]
	var ar: float = d["arm"]
	var lg: float = d["leg"]
	var spine: Node3D = j["spine"]
	var t := str(outfit.get("torso", ""))
	if t != "":
		var c: Color = _cloth(t)
		var g := 1.06 if t == "camiseta" else 1.1
		var shirt := grow(slice(_torso(d), 0.47 * s, -0.05), g, g * 1.04)
		shirt.push_front([-0.06, 0.142 * ws * g, 0.097 * ws * g])
		_p(spine, loft(shirt, 12, false), c)
		_p(spine, loft([[-0.06, 0.15 * ws * g, 0.103 * ws * g], [-0.035, 0.15 * ws * g, 0.103 * ws * g]], 12, false), c.darkened(0.12))
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
			if t == "chaqueta_piel" or t == "traje_buzo":
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
		elif t == "traje_buzo":   # neopreno: cuello alto, cremallera amarilla y franjas
			_p(spine, loft([[0.0, 0.08, 0.068], [0.08, 0.075, 0.064]], 9, false), c, Vector3(0, 0.44 * s, 0.005))
			_p(spine, box(Vector3(0.012, 0.4 * s, 0.01)), Color("d9a925"), Vector3(0, 0.22 * s, -0.128 * ch))
			for side in [-1, 1]:
				_p(spine, box(Vector3(0.025, 0.3 * s, 0.012)), Color("3f6a8a"), Vector3(side * 0.11, 0.25 * s, -0.12 * ch))
		elif t == "chaleco":
			_p(spine, box(Vector3(0.27, 0.3 * s, 0.035)), c, Vector3(0, 0.25 * s, -0.125 * ch))
			_p(spine, box(Vector3(0.27, 0.32 * s, 0.035)), c, Vector3(0, 0.26 * s, 0.11 * ch))
			for i in 4:
				_p(spine, box(Vector3(0.055, 0.075, 0.03)), c.darkened(0.12), Vector3(-0.09 + i * 0.06, 0.15 * s, -0.152 * ch))
			for side in [-1, 1]:
				_p(spine, box(Vector3(0.05, 0.04, 0.26)), c.darkened(0.08), Vector3(side * 0.085, 0.43 * s, -0.005))
	var pz := str(outfit.get("piernas", ""))
	if pz != "":
		var c2: Color = _cloth(pz)
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
		var c3: Color = _cloth(pies)
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
		var c4: Color = _cloth(cab)
		var hr := grow(slice(_head_rings(), 0.2, 0.045), 1.12, 1.1)
		if cab == "gorra":
			_p(j["head"], loft(hr, 12), c4, Vector3(0, 0.012, 0))
			_p(j["head"], loft([[0.0, 0.07, 0.06, 0.0, -0.03], [0.006, 0.07, 0.06, 0.0, -0.03]], 8, true, 0.5, PI), c4.darkened(0.15), Vector3(0, 0.055, -0.06))
		else:
			_p(j["head"], loft(grow(hr, 1.1, 1.08), 12), c4, Vector3(0, 0.02, 0))
			_p(j["head"], loft([[0.0, 0.112, 0.13], [0.008, 0.112, 0.13]], 12), c4.darkened(0.1), Vector3(0, 0.06, 0.005))
			_p(j["head"], box(Vector3(0.02, 0.012, 0.22)), c4.darkened(0.08), Vector3(0, 0.15, 0.01))
	if _has("manos"):
		for side in [-1, 1]:
			var hh: Node3D = j["hand_" + ("l" if side < 0 else "r")]
			_p(hh, loft([[0.005, 0.032, 0.022], [-0.035, 0.038, 0.02], [-0.07, 0.037, 0.018]], 6), _cloth("guantes"), Vector3.ZERO, Vector3(0.15, 0, 0))
	if _has("espalda"):
		var c6: Color = CLOTH.get(str(outfit.get("espalda", "")), CLOTH["mochila"])
		var back := 0.115 * ch + 0.07
		_p(spine, loft([[0.0, 0.13, 0.06], [0.2 * s, 0.14, 0.07], [0.33 * s, 0.12, 0.06], [0.36 * s, 0.08, 0.03]], 8), c6, Vector3(0, 0.08 * s, back))
		_p(spine, box(Vector3(0.18, 0.1, 0.04)), c6.darkened(0.15), Vector3(0, 0.16 * s, back + 0.07))
		# saco de dormir enrollado encima
		_p(spine, loft([[-0.2, 0.05, 0.05], [0.2, 0.05, 0.05]], 8), Color("8f8460"), Vector3(0, 0.5 * s, back - 0.01), Vector3(0, 0, PI / 2.0))
		for side in [-1, 1]:
			_p(spine, box(Vector3(0.035, 0.36 * s, 0.012)), c6.darkened(0.3), Vector3(side * 0.085, 0.27 * s, -0.12 * ch - 0.012))


# ============================================================== animación

# ============================================================ animaciones
# Animaciones de captura de la Universal Animation Library (Quaternius, CC0) pasadas a
# nuestras articulaciones con tools/bake_anims.gd. Las funciones de siempre (andar,
# agacharse, golpe, reposo) mezclan esos clips.

const ANIMS := "res://assets/characters/animaciones.res"
const UPPER := ["spine", "head", "arm_l", "elbow_l", "hand_l", "arm_r", "elbow_r", "hand_r"]
static var _anims: AnimSet
var _phase := 0.0
var _move := 0.0


static func anims() -> AnimSet:
	if _anims == null:
		_anims = load(ANIMS)
	return _anims


static func clip_length(clip: String) -> float:
	var c: Dictionary = anims().clips.get(clip, {})
	return 0.0 if c.is_empty() else float(int(c["frames"]) - 1) / float(c["fps"])


var _rest_q := {}   # giro de reposo de cada articulación


## Pone (o mezcla con peso w) la pose del clip en el instante t (segundos).
func pose(clip: String, t: float, w := 1.0, only: Array = [], loop := true) -> void:
	if j.is_empty() or w <= 0.001:
		return
	var c: Dictionary = anims().clips.get(clip, {})
	if c.is_empty():
		return
	var n: int = c["frames"]
	var ft := t * float(c["fps"])
	ft = fposmod(ft, float(n - 1)) if loop else clampf(ft, 0.0, float(n - 1))
	var i0 := int(ft)
	var i1 := mini(i0 + 1, n - 1)
	var fr := ft - float(i0)
	var rot: Dictionary = c["rot"]
	for jn in rot:
		if not only.is_empty() and not only.has(jn):
			continue
		var a: PackedFloat32Array = rot[jn]
		var q0 := Quaternion(a[i0 * 4], a[i0 * 4 + 1], a[i0 * 4 + 2], a[i0 * 4 + 3])
		var q1 := Quaternion(a[i1 * 4], a[i1 * 4 + 1], a[i1 * 4 + 2], a[i1 * 4 + 3])
		var q := q0.slerp(q1, fr)
		if jn == "spine" and not only.is_empty() and not only.has("hips"):
			# solo de cintura para arriba: el tronco conserva su giro respecto al mundo
			var h: PackedFloat32Array = rot["hips"]
			var hq := Quaternion(h[i0 * 4], h[i0 * 4 + 1], h[i0 * 4 + 2], h[i0 * 4 + 3]).slerp(Quaternion(h[i1 * 4], h[i1 * 4 + 1], h[i1 * 4 + 2], h[i1 * 4 + 3]), fr)
			q = (j["hips"].quaternion as Quaternion).inverse() * hq * q
		var node: Node3D = j[jn]
		node.quaternion = q if w >= 0.999 else node.quaternion.slerp(q, w)
	if only.is_empty() or only.has("hips"):
		var hy: PackedFloat32Array = c["hy"]
		var base := _hip_h()
		var off := lerpf(hy[i0], hy[i1], fr)
		j["hips"].position.y = lerpf(j["hips"].position.y, base + off, w)


func _hip_h() -> float:
	var d := dims()
	return float(d["thigh"]) + float(d["shin"]) + float(d["ankle"]) + 0.06


## Andar/correr: phase avanza con la velocidad (TAU = un ciclo de dos pasos), amount 0..1
## (0 = quieto), run 0..1 de andar a correr. Siempre es lo primero de cada fotograma.
func animate_walk(phase: float, amount: float, run := 0.0) -> void:
	if j.is_empty():
		return
	_phase = phase
	_move = clampf(amount, 0.0, 1.0)
	j["hips"].position = Vector3(0, _hip_h(), 0)
	pose("Idle_Loop", 0.0)
	if _move > 0.001:
		var u := fposmod(phase, TAU) / TAU
		pose("Walk_Loop", u * clip_length("Walk_Loop"), _move)
		if run > 0.001:
			pose("Jog_Fwd_Loop", u * clip_length("Jog_Fwd_Loop"), _move * clampf(run, 0.0, 1.0))


## Agachado (sigilo): quieto o andando agachado.
func animate_crouch(amount: float) -> void:
	if j.is_empty() or amount <= 0.001:
		return
	pose("Crouch_Idle_Loop", 0.0, amount * (1.0 - _move))
	if _move > 0.001:
		var u := fposmod(_phase, TAU) / TAU
		pose("Crouch_Fwd_Loop", u * clip_length("Crouch_Fwd_Loop"), amount * _move)


## Golpe (0..1): ataque con arma de la librería, solo de cintura para arriba para
## poder golpear andando. Entra y sale mezclándose con la pose de antes.
func animate_swing(t: float) -> void:
	if j.is_empty():
		return
	var w := smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(0.8, 1.0, t))
	# parado, todo el cuerpo (con el paso adelante); andando, de cintura para arriba
	# tramo del clip con la carga y el golpe (del 15 % al 70 %)
	pose("Sword_Attack", (0.15 + 0.55 * t) * clip_length("Sword_Attack"), w, UPPER if _move > 0.3 else [], false)


## Picar (kind "pickaxe": de arriba abajo, con las dos manos) o talar (kind "axe": golpe
## cruzado desde el hombro derecho). t 0..1: carga (hasta 0,45), golpe (0,45-0,6) y vuelta.
## La librería no trae estos gestos: se hacen girando las articulaciones (ángulos en radianes,
## signos de CLAUDE.md). Parado mueve también el tronco; andando, solo los brazos.
const CHOP_KEYS := {
	"pickaxe": [
		[0.0, {}],
		[0.45, {"spine": Vector3(0.18, 0, 0), "head": Vector3(0.2, 0, 0),
			"arm_r": Vector3(2.75, 0, -0.35), "elbow_r": Vector3(1.3, 0, 0), "hand_r": Vector3(-0.95, 0, 0),
			"arm_l": Vector3(2.6, 0, 0.55), "elbow_l": Vector3(1.35, 0, 0), "hand_l": Vector3(-0.8, 0, 0)}],
		[0.6, {"spine": Vector3(-0.6, 0, 0), "head": Vector3(-0.2, 0, 0),
			"arm_r": Vector3(1.0, 0, -0.2), "elbow_r": Vector3(0.15, 0, 0), "hand_r": Vector3(0.1, 0, 0),
			"arm_l": Vector3(1.1, 0, 0.5), "elbow_l": Vector3(0.3, 0, 0), "hand_l": Vector3(0.1, 0, 0)}],
		[0.75, {"spine": Vector3(-0.55, 0, 0), "head": Vector3(-0.15, 0, 0),
			"arm_r": Vector3(0.95, 0, -0.2), "elbow_r": Vector3(0.2, 0, 0), "hand_r": Vector3(0.1, 0, 0),
			"arm_l": Vector3(1.05, 0, 0.5), "elbow_l": Vector3(0.35, 0, 0), "hand_l": Vector3(0.1, 0, 0)}],
	],
	"axe": [
		[0.0, {}],
		[0.45, {"spine": Vector3(0.1, 0.75, 0), "head": Vector3(0, -0.45, 0),
			"arm_r": Vector3(2.3, 0, 0.35), "elbow_r": Vector3(1.45, 0, 0), "hand_r": Vector3(-0.9, 0, 0),
			"arm_l": Vector3(2.0, 0, 0.9), "elbow_l": Vector3(1.4, 0, 0), "hand_l": Vector3(-0.7, 0, 0)}],
		[0.6, {"spine": Vector3(-0.3, -0.45, 0), "head": Vector3(-0.1, 0.3, 0),
			"arm_r": Vector3(1.15, 0, -0.55), "elbow_r": Vector3(0.15, 0, 0), "hand_r": Vector3(0.0, 0, 0),
			"arm_l": Vector3(1.15, 0, 0.1), "elbow_l": Vector3(0.3, 0, 0), "hand_l": Vector3(0.0, 0, 0)}],
		[0.75, {"spine": Vector3(-0.28, -0.5, 0), "head": Vector3(-0.1, 0.3, 0),
			"arm_r": Vector3(1.05, 0, -0.6), "elbow_r": Vector3(0.2, 0, 0), "hand_r": Vector3(0.0, 0, 0),
			"arm_l": Vector3(1.05, 0, 0.1), "elbow_l": Vector3(0.35, 0, 0), "hand_l": Vector3(0.0, 0, 0)}],
	],
}


## Cómo va la herramienta en la mano: w = 0 la lleva como siempre (mango hacia delante, cogido
## por el medio); w = 1 cogida por el extremo del mango y apuntando hacia delante y abajo, para
## que al picar o talar la cabeza llegue al suelo o al tronco.
static func grip_tool(tool: Node3D, w: float) -> void:
	var ang := deg_to_rad(lerpf(-80.0, -150.0, w))
	var grip := Vector3(0, -0.36 * w, -0.2 * w)   # punto del mango que queda en el puño
	tool.rotation = Vector3(ang, 0, 0)
	tool.position = -(Basis(Vector3.RIGHT, ang) * grip)


## Peso del agarre de golpear en el instante t de animate_chop (para grip_tool).
static func chop_grip(t: float) -> float:
	return smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.85, 1.0, t))


func animate_chop(t: float, kind: String) -> void:
	if j.is_empty() or not CHOP_KEYS.has(kind):
		return
	var keys: Array = CHOP_KEYS[kind]
	var w := smoothstep(0.0, 0.4, t) * (1.0 - smoothstep(0.8, 1.0, t))
	# tramo de claves en el que cae t (la primera, vacía, es «como estaba»: solo entra el peso)
	var k := 1
	while k < keys.size() - 1 and t > float(keys[k][0]):
		k += 1
	var a: Dictionary = keys[maxi(k - 1, 1)][1]
	var b: Dictionary = keys[k][1]
	var t0 := float(keys[maxi(k - 1, 1)][0])
	var t1 := float(keys[k][0])
	var f := 1.0 if t1 <= t0 or t >= t1 else clampf((t - t0) / (t1 - t0), 0.0, 1.0)
	if t <= float(keys[1][0]):
		f = 1.0   # durante la carga se va hacia la primera clave con el peso
	f = f * f * (3.0 - 2.0 * f)
	for jn in b:
		if _move > 0.3 and (jn == "spine" or jn == "head"):
			continue
		var e: Vector3 = (a.get(jn, b[jn]) as Vector3).lerp(b[jn], f)
		var node: Node3D = j[jn]
		var q := Quaternion.from_euler(e)
		if jn.begins_with("arm_"):
			# el brazo cuelga algo abierto: se respeta ese giro lateral de reposo
			q = Quaternion.from_euler(Vector3(e.x, e.y, e.z + (-0.22 if jn == "arm_l" else 0.22)))
		node.quaternion = node.quaternion.slerp(q, w)


## Recoger con la mano (t 0..1): "waist" coge a la altura de la cintura (arbustos, bayas) con el
## gesto de la librería; "ground" se agacha y estira el brazo hasta el suelo (piedras, ramas,
## hierba, setas). Andando solo se mueve de cintura para arriba.
func animate_pickup(t: float, kind: String) -> void:
	if j.is_empty():
		return
	var still := _move <= 0.3
	if kind == "waist":
		var w := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.85, 1.0, t))
		var ln := clip_length("PickUp_Table")
		pose("PickUp_Table", (0.1 + 0.7 * t) * ln, w, [] if still else UPPER, false)
		return
	# abajo hasta 0,45, la mano en el suelo hasta 0,6 y vuelta arriba
	var w := smoothstep(0.0, 0.45, t) * (1.0 - smoothstep(0.6, 1.0, t))
	if still:
		pose("Crouch_Idle_Loop", 0.0, w)
	var reach := smoothstep(0.15, 0.5, t) * (1.0 - smoothstep(0.65, 1.0, t))
	var target := {
		"spine": Vector3(-1.0, 0.0, 0.0), "head": Vector3(-0.1, 0.0, 0.0),
		"arm_r": Vector3(0.75, 0.0, -0.1), "elbow_r": Vector3(0.05, 0.0, 0.0), "hand_r": Vector3(0.3, 0.0, 0.0),
		"arm_l": Vector3(0.35, 0.0, -0.4), "elbow_l": Vector3(0.6, 0.0, 0.0),
	}
	for jn in target:
		if not still and (jn == "spine" or jn == "head"):
			continue
		var e: Vector3 = target[jn]
		if jn.begins_with("arm_"):
			e.z += -0.22 if jn == "arm_l" else 0.22
		var node: Node3D = j[jn]
		node.quaternion = node.quaternion.slerp(Quaternion.from_euler(e), reach)


## Reposo: respiración y pequeños movimientos (w 0..1). t en segundos.
func animate_idle(t: float, w: float) -> void:
	pose("Idle_Loop", t, w)
	# brazos más sueltos que en el clip (el maniquí original es mucho más ancho)
	for jn in ["arm_l", "arm_r", "elbow_l", "elbow_r"]:
		var r: Quaternion = _rest_q[jn] if _rest_q.has(jn) else Quaternion.IDENTITY
		j[jn].quaternion = (j[jn].quaternion as Quaternion).slerp(r, (0.3 if jn.begins_with("elbow") else 0.2) * w)
