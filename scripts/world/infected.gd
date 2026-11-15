class_name Infected
## Infectados hechos con el mismo cuerpo que el superviviente: piel, ropa
## (teñida), tamaño, postura y añadidos (sangre, pústulas, placas, púas).

const BLOOD := Color("5e1410")
const PUS := Color("d9b43a")
const PUS2 := Color("d0662e")
const BONE := Color("e6dcc2")
const METAL := Color("6c737a")

# look, físico, ropa, tinte de la ropa, escala y altura (para la barra de vida)
const KINDS := {
	"infectado": {"look": {"sex": "m", "hair": 1, "hair_color": 0, "eyes": 4, "mouth": 4, "skin_color": Color("8a9a78")}, "phys": {"fuerza": 0.15}, "outfit": {"torso": "camiseta", "piernas": "pantalon_tela"}},
	"acorazado": {"look": {"sex": "m", "hair": 0, "eyes": 2, "mouth": 2, "skin_color": Color("8b97a0")}, "phys": {"fuerza": 1.0}, "outfit": {"piernas": "pantalon_cargo"}, "scale": Vector3(1.18, 1.1, 1.25), "top": 2.2},
	"corredora": {"look": {"sex": "f", "hair": 2, "hair_color": 0, "eyes": 3, "mouth": 3, "skin_color": Color("a9ad9a")}, "phys": {}, "outfit": {"torso": "camiseta", "piernas": "pantalon_tela", "pies": "zapatillas"}, "top": 1.75},
	"minero": {"look": {"sex": "m", "hair": 4, "hair_color": 0, "eyes": 4, "mouth": 4, "skin_color": Color("93957a")}, "phys": {"fuerza": 0.4}, "outfit": {"cabeza": "casco_obra", "torso": "chaleco", "piernas": "pantalon_cargo", "pies": "botas"}},
	# Gritona: melena canosa, camiseta verde, vaqueros claros y zapatillas rosas
	"gritona": {"look": {"sex": "f", "hair": 2, "hair_color": 4, "eyes": 2, "mouth": 2, "skin_color": Color("c9c1c6")}, "phys": {}, "outfit": {"torso": "camiseta", "piernas": "pantalon_tela", "pies": "zapatillas"},
		"tint": {"camiseta": Color("5f8a3a"), "pantalon_tela": Color("c4b48e"), "zapatillas": Color("d9a3ad")}, "top": 1.8},
	# Acechador: piel parda, flaco, púas de hueso en el lomo y garras
	"acechador": {"look": {"sex": "m", "hair": 0, "hair_color": 0, "eyes": 3, "mouth": 3, "skin_color": Color("6b4a3a")}, "phys": {}, "outfit": {"piernas": "pantalon_tela"},
		"tint": {"pantalon_tela": Color("4e3527")}, "top": 1.3},
	# Purulento: vigilante obeso con uniforme beige, insignia y pústulas en la tripa
	"purulento": {"look": {"sex": "m", "hair": 1, "hair_color": 1, "eyes": 4, "mouth": 2, "skin_color": Color("9fae6c")}, "phys": {"fuerza": 0.5}, "outfit": {"torso": "camiseta", "piernas": "pantalon_tela", "pies": "botas"},
		"tint": {"camiseta": Color("cfc39c"), "pantalon_tela": Color("5c4834"), "botas": Color("3a2e24")}, "scale": Vector3(1.12, 1.0, 1.12), "top": 2.05},
	# Blindado: casco amarillo, ropa gris y placas de chatarra atadas con correas
	"blindado": {"look": {"sex": "m", "hair": 1, "hair_color": 0, "eyes": 4, "mouth": 4, "skin_color": Color("85988a")}, "phys": {"fuerza": 0.6}, "outfit": {"cabeza": "casco_obra", "torso": "chaqueta_piel", "piernas": "pantalon_cargo", "pies": "botas", "manos": "guantes"},
		"tint": {"chaqueta_piel": Color("5f666e"), "pantalon_cargo": Color("575d64"), "botas": Color("33302c"), "guantes": Color("3a3d40")}},
	# Coloso: gigante azulado sin camisa, hombreras de chapa y cicatrices
	"coloso": {"look": {"sex": "m", "hair": 0, "hair_color": 1, "eyes": 2, "mouth": 4, "skin_color": Color("7e8fa8")}, "phys": {"fuerza": 1.0}, "outfit": {"piernas": "pantalon_cargo", "pies": "botas"},
		"tint": {"pantalon_cargo": Color("9a8a5e"), "botas": Color("4a3a2c")}, "scale": Vector3(1.95, 1.62, 1.95), "top": 3.2},
}


static func has(kind: String) -> bool:
	return KINDS.has(kind)


static func top(kind: String) -> float:
	return float(KINDS[kind].get("top", 1.95))


static func build(kind: String) -> CharacterModel:
	var k: Dictionary = KINDS[kind]
	var c := CharacterModel.new(k["look"], k.get("phys", {}), k.get("outfit", {}))
	c.tint = k.get("tint", {})
	c.scale = k.get("scale", Vector3.ONE)
	c.set_meta("kind", kind)
	return c


static func _blob(parent: Node3D, seed_: int, color: Color, pos: Vector3, scl: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var w := MeshInstance3D.new()
	w.mesh = Nature.blob(seed_, 0.3, 6, 3, false)
	w.material_override = CharacterModel.mat(color)
	w.position = pos
	w.scale = scl
	w.rotation = rot
	parent.add_child(w)
	return w


static func _plate(parent: Node3D, color: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var w := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	w.mesh = bm
	w.material_override = CharacterModel.mat(color)
	w.position = pos
	w.rotation = rot
	parent.add_child(w)
	return w


## Púa o garra: cono facetado de 4 lados.
static func _spike(parent: Node3D, color: Color, pos: Vector3, length: float, radius: float, rot := Vector3.ZERO) -> void:
	var w := MeshInstance3D.new()
	w.mesh = CharacterModel.loft([[0.0, radius, radius], [length, 0.002, 0.002]], 4)
	w.material_override = CharacterModel.mat(color)
	w.position = pos
	w.rotation = rot
	parent.add_child(w)


## Hombrera de chapa: losa curvada sobre el hombro.
static func _pauldron(arm: Node3D, side: float, color: Color, size: float) -> void:
	_plate(arm, color, Vector3(side * 0.03, 0.015, 0.0), Vector3(0.15, 0.06, 0.17) * size, Vector3(0, 0, side * -0.35))
	_plate(arm, color.darkened(0.12), Vector3(side * 0.075, -0.05, 0.0), Vector3(0.05, 0.12, 0.16) * size, Vector3(0, 0, side * -0.1))
	_plate(arm, color.lightened(0.1), Vector3(side * 0.0, 0.05, 0.0), Vector3(0.1, 0.02, 0.12) * size, Vector3(0, 0, side * -0.4))


## Añadidos de cada tipo. Se llama una vez, con el modelo ya en el árbol.
static func dress(c: CharacterModel) -> void:
	if c.j.is_empty() or c.j["spine"].has_meta("dressed"):
		return
	c.j["spine"].set_meta("dressed", true)
	var kind := str(c.get_meta("kind", "infectado"))
	var sp: Node3D = c.j["spine"]
	var hd: Node3D = c.j["head"]
	var zf := -0.158 if kind in ["acorazado", "coloso"] else -0.118   # frente del pecho
	match kind:
		"gritona":
			# Boca abierta de par en par y sangre por la barbilla
			_blob(hd, 6, Color("2a0806"), Vector3(0.0, -0.078, -0.106), Vector3(0.034, 0.05, 0.014))
			_plate(hd, Color("e9e1d0"), Vector3(0.0, -0.048, -0.116), Vector3(0.036, 0.008, 0.006))   # dientes
			_blob(sp, 7, BLOOD, Vector3(0.03, 0.4, zf), Vector3(0.02, 0.04, 0.01))
			_plate(sp, Color("5f8a3a").darkened(0.2), Vector3(0.05, 0.12, zf - 0.004), Vector3(0.05, 0.03, 0.01), Vector3(0, 0, 0.4))   # rasgón
		"acechador":
			_blob(hd, 77, Color("2a0806"), Vector3(0.005, -0.08, -0.1), Vector3(0.026, 0.016, 0.012))
			# Púas de hueso por el lomo, los hombros y la cabeza
			for i in 6:
				_spike(sp, BONE, Vector3(0.0, 0.06 + i * 0.075, 0.12 - i * 0.004), 0.1 + 0.035 * (i % 3), 0.026, Vector3(1.1 + i * 0.05, 0, 0))
			for side in [-1.0, 1.0]:
				var arm: Node3D = c.j["arm_l" if side < 0.0 else "arm_r"]
				_spike(arm, BONE, Vector3(side * 0.04, 0.02, 0.03), 0.13, 0.025, Vector3(0.6, 0, side * -0.9))
				_spike(arm, BONE, Vector3(side * 0.05, -0.06, 0.04), 0.08, 0.018, Vector3(0.9, 0, side * -1.2))
				var hand: Node3D = c.j["hand_l" if side < 0.0 else "hand_r"]
				for k in 3:   # garras
					_spike(hand, BONE, Vector3((k - 1) * 0.016, -0.075, -0.02), 0.06, 0.008, Vector3(PI + 0.25, 0, 0))
			_spike(hd, BONE, Vector3(0.0, 0.09, 0.05), 0.07, 0.02, Vector3(1.2, 0, 0))
		"purulento":
			_blob(hd, 77, Color("4e100c"), Vector3(0.005, -0.08, -0.1), Vector3(0.03, 0.022, 0.012))
			var shirt: Color = c.tint["camiseta"]
			# Tripa enorme bajo la camisa del uniforme: elipsoide que sobresale por delante
			var belly := [[-0.04, 0.15, 0.13, 0.0, -0.02], [0.03, 0.19, 0.19, 0.0, -0.06], [0.12, 0.215, 0.22, 0.0, -0.085], [0.22, 0.205, 0.2, 0.0, -0.075], [0.31, 0.18, 0.15, 0.0, -0.045], [0.4, 0.155, 0.115, 0.0, -0.015]]
			var bm := MeshInstance3D.new()
			bm.mesh = CharacterModel.loft(belly, 10)
			bm.material_override = CharacterModel.mat(shirt)
			sp.add_child(bm)
			var surf := func(y: float, ang: float, out := 0.004) -> Vector3:
				# punto de la superficie de la tripa a la altura y, ang = 0 delante
				var rx := 0.215
				var rz := 0.22
				var cz := -0.085
				for k in belly.size() - 1:
					if y >= float(belly[k][0]) and y <= float(belly[k + 1][0]):
						var t := (y - float(belly[k][0])) / (float(belly[k + 1][0]) - float(belly[k][0]))
						rx = lerpf(float(belly[k][1]), float(belly[k + 1][1]), t)
						rz = lerpf(float(belly[k][2]), float(belly[k + 1][2]), t)
						cz = lerpf(float(belly[k][4]), float(belly[k + 1][4]), t)
				return Vector3(sin(ang) * (rx + out), y, cz - cos(ang) * (rz + out))
			# Cinturón y hebilla bajo la tripa
			var belt := MeshInstance3D.new()
			belt.mesh = CharacterModel.loft([[-0.05, 0.158, 0.138, 0.0, -0.022], [-0.01, 0.17, 0.16, 0.0, -0.035]], 10)
			belt.material_override = CharacterModel.mat(Color("3e2f22"))
			sp.add_child(belt)
			_plate(sp, Color("c9a640"), Vector3(0.0, -0.03, -0.198), Vector3(0.05, 0.035, 0.01))
			# Botones de la camisa por el centro de la tripa
			for y in [0.06, 0.15, 0.24, 0.33]:
				_blob(sp, 15, shirt.darkened(0.35), surf.call(y, 0.0, 0.002), Vector3.ONE * 0.008)
			# Charreteras, insignia y bolsillos del pecho
			for side in [-1.0, 1.0]:
				_plate(c.j["arm_l" if side < 0.0 else "arm_r"], shirt.darkened(0.25), Vector3(side * 0.01, 0.03, 0.0), Vector3(0.1, 0.02, 0.07))
				_plate(sp, shirt.darkened(0.1), Vector3(side * 0.08, 0.4, -0.13), Vector3(0.06, 0.05, 0.01))
			_blob(sp, 13, Color("c9a640"), Vector3(-0.08, 0.45, -0.137), Vector3(0.018, 0.022, 0.006))
			# Camisa rota y pústulas sobre la tripa
			var rip := _blob(sp, 14, c.look["skin_color"], surf.call(0.12, 0.45, -0.012), Vector3(0.07, 0.06, 0.014))
			rip.rotation.y = -0.45
			var spots := [[0.12, 0.38, 0.032], [0.07, 0.6, 0.024], [0.16, 0.62, 0.02], [0.09, 0.25, 0.018], [0.2, 0.3, 0.017], [0.04, 0.42, 0.015], [0.26, -0.45, 0.02], [0.18, -0.2, 0.014]]
			for i in spots.size():
				_blob(sp, 20 + i, PUS if i % 3 != 1 else PUS2, surf.call(float(spots[i][0]), float(spots[i][1]), 0.0), Vector3.ONE * float(spots[i][2]))
			_blob(hd, 30, PUS, Vector3(0.06, -0.05, -0.08), Vector3.ONE * 0.016)
			_blob(hd, 31, PUS2, Vector3(-0.05, 0.02, -0.09), Vector3.ONE * 0.012)
			_blob(hd, 32, Color("c9d050"), Vector3(0.0, -0.11, -0.1), Vector3(0.018, 0.03, 0.01))   # babas
		"blindado":
			_blob(hd, 77, Color("4e100c"), Vector3(0.005, -0.08, -0.1), Vector3(0.026, 0.018, 0.012))
			# Peto y espaldar de chapa con correas cruzadas
			_plate(sp, METAL, Vector3(0, 0.27, -0.145), Vector3(0.3, 0.3, 0.025), Vector3(0.06, 0, 0))
			_plate(sp, METAL.darkened(0.15), Vector3(0, 0.27, 0.135), Vector3(0.3, 0.32, 0.025))
			for side in [-1.0, 1.0]:
				_plate(sp, Color("6a4a2a"), Vector3(side * 0.06, 0.28, -0.162), Vector3(0.025, 0.42, 0.012), Vector3(0, 0, side * 0.45))
				var tag := "l" if side < 0.0 else "r"
				_pauldron(c.j["arm_" + tag], side, METAL.lightened(0.05), 1.0)
				_plate(c.j["elbow_" + tag], METAL, Vector3(0, -0.11, -0.02), Vector3(0.1, 0.14, 0.09))          # brazal
				_plate(c.j["knee_" + tag], METAL.darkened(0.08), Vector3(0, -0.12, -0.07), Vector3(0.11, 0.16, 0.03))  # espinillera
				_plate(c.j["knee_" + tag], METAL.lightened(0.08), Vector3(0, 0.0, -0.075), Vector3(0.09, 0.07, 0.03))  # rodillera
			_plate(sp, Color("6a4a2a"), Vector3(0, 0.12, -0.16), Vector3(0.3, 0.03, 0.012))
			_blob(sp, 44, BLOOD, Vector3(-0.08, 0.36, -0.162), Vector3(0.025, 0.03, 0.006))
		"coloso":
			_blob(hd, 6, Color("2a0806"), Vector3(0.0, -0.08, -0.102), Vector3(0.03, 0.02, 0.012))
			for k in 4:   # dientes
				_plate(hd, Color("e9e1d0"), Vector3(-0.018 + k * 0.012, -0.072, -0.11), Vector3(0.008, 0.01, 0.004))
			for side in [-1.0, 1.0]:
				_pauldron(c.j["arm_l" if side < 0.0 else "arm_r"], side, Color("70777e"), 1.25)
			# Pecho y cuello más anchos: músculo
			_blob(sp, 60, c.look["skin_color"], Vector3(0.0, 0.34, -0.04), Vector3(0.2, 0.12, 0.13))
			_blob(sp, 61, c.look["skin_color"].darkened(0.04), Vector3(0.0, 0.55, 0.0), Vector3(0.1, 0.06, 0.09))
			# Cicatrices y heridas
			for d in [[Vector3(-0.08, 0.34, zf), 0.4], [Vector3(-0.03, 0.27, zf + 0.006), -0.3], [Vector3(0.07, 0.31, zf), 0.5], [Vector3(0.1, 0.17, zf + 0.01), -0.2]]:
				_plate(sp, BLOOD, d[0], Vector3(0.012, 0.075, 0.008), Vector3(0, 0, float(d[1])))
		_:   # común, hinchado, corredora y minero: sangre en el pecho
			_blob(hd, 77, Color("4e100c"), Vector3(0.005, -0.082, -0.1), Vector3(0.028, 0.02, 0.012))
			var s := 1.3 if kind == "acorazado" else 1.0
			for d in [[Vector3(0.06, 0.3, zf), Vector3(0.05, 0.07, 0.012)], [Vector3(0.02, 0.2, zf - 0.004), Vector3(0.03, 0.05, 0.012)], [Vector3(-0.09, 0.14, zf + 0.003), Vector3(0.035, 0.03, 0.012)]]:
				_blob(sp, 40 + int(d[0].y * 100.0), BLOOD, d[0], d[1] * s)


## Postura y animación: phase/amount del paso, attack 0..1 (golpe),
## special 0..1 (grito, salto o pisotón según el tipo).
static func pose(c: CharacterModel, phase: float, amount: float, attack := 0.0, special := 0.0) -> void:
	if c.j.is_empty():
		return
	dress(c)
	var kind := str(c.get_meta("kind", "infectado"))
	var j := c.j
	c.animate_walk(phase, amount)
	var sway := sin(phase * 0.5) * 0.08 * amount
	match kind:
		"acorazado", "coloso":
			j["spine"].rotation = Vector3(-0.12, 0, sway * 1.5)
			j["head"].rotation.x = -0.15
			j["arm_l"].rotation = Vector3(0.15 + j["arm_l"].rotation.x * 0.4, 0, -0.35)
			j["arm_r"].rotation = Vector3(0.3 + j["arm_r"].rotation.x * 0.4, 0, 0.35)
			j["elbow_l"].rotation.x = 0.5
			j["elbow_r"].rotation.x = 0.6
			if kind == "coloso" and special > 0.0:   # pisotón: brazos arriba y caída
				var up := sin(special * PI)
				j["arm_l"].rotation = Vector3(-2.4 * up, 0, -0.5)
				j["arm_r"].rotation = Vector3(-2.4 * up, 0, 0.5)
				j["spine"].rotation.x = 0.15 * up - 0.35 * (1.0 - up) * float(special > 0.5)
				j["leg_r"].rotation.x = -0.8 * up
		"purulento":   # tambaleo con los brazos separados de la tripa
			j["spine"].rotation = Vector3(0.08, 0, sway * 2.0)
			j["head"].rotation = Vector3(0.2, 0.15, 0.25)
			j["arm_l"].rotation = Vector3(0.2 + j["arm_l"].rotation.x * 0.3, 0, -0.5)
			j["arm_r"].rotation = Vector3(0.25 + j["arm_r"].rotation.x * 0.3, 0, 0.5)
			j["elbow_l"].rotation.x = 0.35
			j["elbow_r"].rotation.x = 0.4
		"corredora":
			j["spine"].rotation.x = -0.55
			j["head"].rotation.x = 0.45
			j["arm_l"].rotation = Vector3(-0.7, 0, -0.25)
			j["arm_r"].rotation = Vector3(-0.5, 0, 0.25)
			j["elbow_l"].rotation.x = 0.9
			j["elbow_r"].rotation.x = 1.1
		"gritona":   # piernas flexionadas, brazos abiertos con las palmas hacia fuera
			var g := maxf(special, 0.25)
			for side in ["l", "r"]:
				j["leg_" + side].rotation.x += 0.35
				j["knee_" + side].rotation.x -= 0.6
				j["leg_" + side].rotation.z = 0.12 if side == "l" else -0.12
			j["hips"].position.y -= 0.07
			j["spine"].rotation.x = 0.05 + 0.1 * g
			j["head"].rotation.x = -0.25 - 0.35 * g
			j["arm_l"].rotation = Vector3(0.25, 0, -0.75 - 0.35 * g)
			j["arm_r"].rotation = Vector3(0.25, 0, 0.75 + 0.35 * g)
			j["elbow_l"].rotation = Vector3(0.9, 0, 0)
			j["elbow_r"].rotation = Vector3(0.9, 0, 0)
		"acechador":   # agazapado, brazos colgando hasta el suelo
			j["hips"].position.y -= 0.32
			j["spine"].rotation.x = -0.95
			j["head"].rotation.x = 0.85
			for side in ["l", "r"]:
				j["leg_" + side].rotation.x += 1.0
				j["knee_" + side].rotation.x -= 1.6
				j["foot_" + side].rotation.x = 0.55
				j["arm_" + side].rotation = Vector3(0.95 + j["arm_" + side].rotation.x * 0.5, 0, -0.18 if side == "l" else 0.18)
				j["elbow_" + side].rotation.x = 0.35
			if special > 0.0:   # salto: se estira hacia delante con las garras
				j["spine"].rotation.x = -1.25
				j["arm_l"].rotation.x = 2.3
				j["arm_r"].rotation.x = 2.3
				j["elbow_l"].rotation.x = 0.0
				j["elbow_r"].rotation.x = 0.0
				for side in ["l", "r"]:
					j["knee_" + side].rotation.x = -0.4
		"blindado":   # erguido, puños cerrados y brazos algo abiertos
			j["spine"].rotation = Vector3(-0.08, 0, sway)
			j["head"].rotation = Vector3(0.1, 0.1, 0.15)
			j["arm_l"].rotation = Vector3(0.25 + j["arm_l"].rotation.x * 0.4, 0, -0.32)
			j["arm_r"].rotation = Vector3(0.3 + j["arm_r"].rotation.x * 0.4, 0, 0.32)
			j["elbow_l"].rotation.x = 0.45
			j["elbow_r"].rotation.x = 0.5
		_:   # común y minero: encorvado y brazos al frente
			j["spine"].rotation = Vector3(-0.3, 0, sway)
			j["head"].rotation = Vector3(0.25, 0.2, 0.3)
			j["arm_l"].rotation.x = 1.35 + sin(phase) * 0.08
			j["arm_r"].rotation.x = 1.1 - sin(phase) * 0.08
			j["elbow_r"].rotation.x = 0.5
	if attack > 0.0 and kind != "gritona":
		var a := sin(attack * PI)
		j["arm_r"].rotation.x += 0.9 * a
		j["arm_l"].rotation.x += 0.7 * a
		j["spine"].rotation.x -= 0.25 * a
