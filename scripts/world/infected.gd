class_name Infected
## Infectados hechos con el mismo cuerpo que el superviviente: piel, ropa,
## tamaño, postura y añadidos (sangre, pústulas, placas) propios de cada tipo.

const BLOOD := Color("5e1410")
const PUS := Color("b9c24a")

# look, físico, ropa, escala, altura (para la barra de vida)
const KINDS := {
	"infectado": {"look": {"sex": "m", "hair": 1, "hair_color": 0, "eyes": 4, "mouth": 4, "skin_color": Color("8a9a78")}, "phys": {"fuerza": 0.15}, "outfit": {"torso": "camiseta", "piernas": "pantalon_tela"}},
	"acorazado": {"look": {"sex": "m", "hair": 0, "eyes": 2, "mouth": 2, "skin_color": Color("8b97a0")}, "phys": {"fuerza": 1.0}, "outfit": {"piernas": "pantalon_cargo"}, "scale": Vector3(1.18, 1.1, 1.25), "top": 2.2},
	"corredora": {"look": {"sex": "f", "hair": 2, "hair_color": 0, "eyes": 3, "mouth": 3, "skin_color": Color("a9ad9a")}, "phys": {}, "outfit": {"torso": "camiseta", "piernas": "pantalon_tela", "pies": "zapatillas"}, "top": 1.75},
	"minero": {"look": {"sex": "m", "hair": 4, "hair_color": 0, "eyes": 4, "mouth": 4, "skin_color": Color("93957a")}, "phys": {"fuerza": 0.4}, "outfit": {"cabeza": "casco_obra", "torso": "chaleco", "piernas": "pantalon_cargo", "pies": "botas"}},
	# --- prototipos (aún no están en el juego)
	"escupidor": {"look": {"sex": "m", "hair": 0, "eyes": 2, "mouth": 2, "skin_color": Color("9aa56a")}, "phys": {"fuerza": 0.1}, "outfit": {"piernas": "pantalon_tela"}},
	"gritona": {"look": {"sex": "f", "hair": 4, "hair_color": 4, "eyes": 2, "mouth": 2, "skin_color": Color("b7b0b4")}, "phys": {}, "outfit": {"torso": "camiseta", "piernas": "pantalon_tela"}, "top": 1.8},
	"acechador": {"look": {"sex": "m", "hair": 0, "eyes": 3, "mouth": 3, "skin_color": Color("5f6a66")}, "phys": {"fuerza": 0.3}, "outfit": {"piernas": "pantalon_tela"}, "top": 1.0},
	"purulento": {"look": {"sex": "m", "hair": 0, "eyes": 4, "mouth": 2, "skin_color": Color("a39a72")}, "phys": {"fuerza": 0.7}, "outfit": {"piernas": "pantalon_tela"}, "scale": Vector3(1.05, 1.0, 1.2)},
	"blindado": {"look": {"sex": "m", "hair": 1, "eyes": 4, "mouth": 4, "skin_color": Color("7f8f80")}, "phys": {"fuerza": 0.6}, "outfit": {"cabeza": "casco_obra", "torso": "chaleco", "piernas": "pantalon_cargo", "pies": "botas", "manos": "guantes"}},
	"coloso": {"look": {"sex": "m", "hair": 0, "eyes": 4, "mouth": 4, "skin_color": Color("6f7a86")}, "phys": {"fuerza": 1.0}, "outfit": {"piernas": "pantalon_cargo", "pies": "botas"}, "scale": Vector3(1.65, 1.55, 1.75), "top": 3.1},
}


static func has(kind: String) -> bool:
	return KINDS.has(kind)


static func top(kind: String) -> float:
	return float(KINDS[kind].get("top", 1.95))


static func build(kind: String) -> CharacterModel:
	var k: Dictionary = KINDS[kind]
	var c := CharacterModel.new(k["look"], k.get("phys", {}), k.get("outfit", {}))
	c.scale = k.get("scale", Vector3.ONE)
	c.set_meta("kind", kind)
	return c


static func _blob(parent: Node3D, seed_: int, color: Color, pos: Vector3, scl: Vector3) -> void:
	var w := MeshInstance3D.new()
	w.mesh = Nature.blob(seed_, 0.3, 6, 3, false)
	w.material_override = CharacterModel.mat(color)
	w.position = pos
	w.scale = scl
	parent.add_child(w)


static func _plate(parent: Node3D, color: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	var w := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	w.mesh = bm
	w.material_override = CharacterModel.mat(color)
	w.position = pos
	w.rotation = rot
	parent.add_child(w)


## Añadidos de cada tipo. Se llama una vez, con el modelo ya en el árbol.
static func dress(c: CharacterModel) -> void:
	if c.j.is_empty() or c.j["spine"].has_meta("dressed"):
		return
	c.j["spine"].set_meta("dressed", true)
	var kind := str(c.get_meta("kind", "infectado"))
	var sp: Node3D = c.j["spine"]
	var hd: Node3D = c.j["head"]
	var zf := -0.118 if kind not in ["acorazado", "purulento", "coloso"] else -0.158   # frente del pecho
	_blob(hd, 77, Color("4e100c"), Vector3(0.005, -0.082, -0.1), Vector3(0.028, 0.02, 0.012))   # boca
	match kind:
		"escupidor":   # buche hinchado y baba ácida
			_blob(sp, 3, PUS, Vector3(0, 0.5, -0.09), Vector3(0.075, 0.07, 0.07))
			_blob(sp, 4, PUS.darkened(0.15), Vector3(0.0, 0.14, -0.12), Vector3(0.12, 0.11, 0.09))
			_blob(hd, 5, PUS, Vector3(0.0, -0.11, -0.1), Vector3(0.02, 0.05, 0.015))
		"gritona":     # boca desencajada y sangre por la barbilla
			_blob(hd, 6, Color("2a0806"), Vector3(0.0, -0.085, -0.1), Vector3(0.03, 0.035, 0.015))
			_blob(sp, 7, BLOOD, Vector3(0.0, 0.36, zf), Vector3(0.035, 0.06, 0.012))
		"acechador":   # espinas en el lomo
			for i in 4:
				_plate(sp, Color("3a423f"), Vector3(0, 0.12 + i * 0.11, 0.13), Vector3(0.03, 0.03, 0.12), Vector3(-0.6, 0, 0))
		"purulento":   # pústulas por todo el cuerpo
			var spots := [Vector3(0.1, 0.34, zf), Vector3(-0.09, 0.22, zf - 0.005), Vector3(0.03, 0.1, zf + 0.01), Vector3(-0.17, 0.4, -0.05), Vector3(0.15, 0.18, 0.1), Vector3(-0.05, 0.36, 0.15), Vector3(0.18, 0.44, 0.02)]
			for i in spots.size():
				_blob(sp, 20 + i, PUS if i % 2 == 0 else Color("c98a3a"), spots[i], Vector3.ONE * (0.05 + 0.012 * (i % 3)))
			_blob(hd, 30, PUS, Vector3(0.07, 0.05, -0.06), Vector3.ONE * 0.035)
		"blindado":    # placas de chatarra atornilladas
			_plate(sp, Color("6a7178"), Vector3(0, 0.27, -0.15), Vector3(0.34, 0.36, 0.03), Vector3(0.05, 0, 0.04))
			_plate(sp, Color("7a5a3a"), Vector3(0.0, 0.3, 0.14), Vector3(0.3, 0.3, 0.03))
			for side in [-1, 1]:
				_plate(c.j["arm_l" if side < 0 else "arm_r"], Color("5d646a"), Vector3(side * 0.03, -0.08, 0), Vector3(0.13, 0.2, 0.15))
		"coloso":      # cadenas y placa en un hombro, cicatrices
			_plate(c.j["arm_r"], Color("555b61"), Vector3(0.03, -0.02, 0), Vector3(0.17, 0.16, 0.2))
			for i in 3:
				_blob(sp, 50 + i, BLOOD, Vector3(-0.1 + i * 0.1, 0.2 + i * 0.07, zf), Vector3(0.02, 0.09, 0.012))
		_:             # sangre en el pecho
			var s := 1.3 if kind == "acorazado" else 1.0
			for d in [[Vector3(0.06, 0.3, zf), Vector3(0.05, 0.07, 0.012)], [Vector3(0.02, 0.2, zf - 0.004), Vector3(0.03, 0.05, 0.012)], [Vector3(-0.09, 0.14, zf + 0.003), Vector3(0.035, 0.03, 0.012)]]:
				_blob(sp, 40 + int(d[0].y * 100.0), BLOOD, d[0], d[1] * s)


## Postura y animación: phase/amount del paso, attack 0..1 (zarpazo).
static func pose(c: CharacterModel, phase: float, amount: float, attack := 0.0) -> void:
	if c.j.is_empty():
		return
	dress(c)
	var kind := str(c.get_meta("kind", "infectado"))
	var j := c.j
	c.animate_walk(phase, amount)
	var sway := sin(phase * 0.5) * 0.08 * amount
	match kind:
		"acorazado", "purulento", "coloso":
			j["spine"].rotation = Vector3(-0.12, 0, sway * 1.5)
			j["head"].rotation.x = -0.15
			j["arm_l"].rotation = Vector3(0.15 + j["arm_l"].rotation.x * 0.4, 0, -0.35)
			j["arm_r"].rotation = Vector3(0.3 + j["arm_r"].rotation.x * 0.4, 0, 0.35)
			j["elbow_l"].rotation.x = 0.5
			j["elbow_r"].rotation.x = 0.6
		"corredora", "gritona":
			j["spine"].rotation.x = -0.55
			j["head"].rotation.x = 0.45
			j["arm_l"].rotation = Vector3(-0.7, 0, -0.25)
			j["arm_r"].rotation = Vector3(-0.5, 0, 0.25)
			j["elbow_l"].rotation.x = 0.9
			j["elbow_r"].rotation.x = 1.1
			if kind == "gritona":   # erguida, brazos abiertos, cabeza atrás
				j["spine"].rotation.x = 0.12
				j["head"].rotation.x = -0.45
				j["arm_l"].rotation = Vector3(0.2, 0, -0.9)
				j["arm_r"].rotation = Vector3(0.2, 0, 0.9)
		"acechador":   # a cuatro patas
			j["hips"].position.y -= 0.38
			j["spine"].rotation.x = -1.3
			j["head"].rotation.x = 1.0
			for side in ["l", "r"]:
				j["leg_" + side].rotation.x += 1.2
				j["knee_" + side].rotation.x -= 1.9
				j["arm_" + side].rotation = Vector3(1.25 + j["arm_" + side].rotation.x * 0.6, 0, -0.2 if side == "l" else 0.2)
				j["elbow_" + side].rotation.x = 0.25
		"escupidor":
			j["spine"].rotation.x = 0.1
			j["head"].rotation.x = -0.3 + attack * 0.7
			j["arm_l"].rotation = Vector3(0.1, 0, -0.2)
			j["arm_r"].rotation = Vector3(0.1, 0, 0.2)
		_:             # común, minero, blindado: encorvado y brazos al frente
			j["spine"].rotation = Vector3(-0.3, 0, sway)
			j["head"].rotation = Vector3(0.25, 0.2, 0.3)
			j["arm_l"].rotation.x = 1.35 + sin(phase) * 0.08
			j["arm_r"].rotation.x = 1.1 - sin(phase) * 0.08
			j["elbow_r"].rotation.x = 0.5
	if attack > 0.0 and kind not in ["escupidor", "gritona"]:
		var a := sin(attack * PI)
		j["arm_r"].rotation.x += 0.9 * a
		j["arm_l"].rotation.x += 0.7 * a
		j["spine"].rotation.x -= 0.25 * a
