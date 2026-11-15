extends Node
## Renders del superviviente para las propuestas de diseño (fondo transparente).
##   xvfb-run godot --rendering-driver opengl3 res://tools/character_sheet.tscn -- /carpeta

var out := "/tmp/chars"
var vp: SubViewport
var stage: Node3D
var cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9cfd6")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 150, 0)
	key.light_energy = 1.45
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -60, 0)
	fill.light_energy = 0.35
	vp.add_child(fill)
	cam = Camera3D.new()
	vp.add_child(cam)
	stage = Node3D.new()
	vp.add_child(stage)
	if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "props":
		await _props()
	elif OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "inv":
		await _inventory()
	elif OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "heads":
		await _all(true)
	elif OS.get_cmdline_user_args().size() > 1:
		await _quick()
	else:
		await _all()
	get_tree().quit()


func _clear() -> void:
	for c in stage.get_children():
		c.queue_free()


func _char(look: Dictionary, phys := {}, outfit := {}, pos := Vector3.ZERO, rot_y := 0.0, explode := 0.0) -> CharacterModel:
	var c := CharacterModel.new(look, phys, outfit)
	c.explode = explode
	c.position = pos
	c.rotation.y = rot_y
	stage.add_child(c)
	return c


func _shot(file: String, size: Vector2i, eye: Vector3, target: Vector3, fov := 30.0) -> void:
	vp.size = size
	cam.fov = fov
	cam.position = eye
	cam.look_at(target, Vector3.UP)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, file])
	print("render ", file)


## Infectado de propuesta: piel, ropa, físico y postura.
func _zombie(kind: String, pos: Vector3, rot_y := 0.3) -> CharacterModel:
	var c: CharacterModel
	match kind:
		"a":   # Infectado común: encorvado, brazos al frente, ropa rota
			c = _char({"sex": "m", "hair": 1, "hair_color": 0, "eyes": 4, "mouth": 4, "skin_color": Color("8a9a78")}, {"fuerza": 0.15}, {"torso": "camiseta", "piernas": "pantalon_tela"}, pos, rot_y)
		"b":   # Hinchado: enorme, sin camisa, lento
			c = _char({"sex": "m", "hair": 0, "eyes": 2, "mouth": 2, "skin_color": Color("8b97a0")}, {"fuerza": 1.0}, {"piernas": "pantalon_cargo"}, pos, rot_y)
			c.scale = Vector3(1.18, 1.1, 1.25)
		_:     # Corredora: delgada, inclinada, rápida
			c = _char({"sex": "f", "hair": 2, "hair_color": 0, "eyes": 3, "mouth": 3, "skin_color": Color("a9ad9a")}, {}, {"torso": "camiseta", "piernas": "pantalon_tela", "pies": "zapatillas"}, pos, rot_y)
	await get_tree().process_frame
	c.animate_walk(0.9, 0.7)
	var j := c.j
	match kind:
		"a":
			j["spine"].rotation.x = -0.3
			j["head"].rotation = Vector3(0.25, 0.2, 0.3)
			j["arm_l"].rotation.x = 1.35
			j["arm_r"].rotation.x = 1.1
			j["elbow_r"].rotation.x = 0.5
		"b":
			j["spine"].rotation.x = -0.12
			j["head"].rotation.x = -0.15
			j["arm_l"].rotation = Vector3(0.15, 0, -0.35)
			j["arm_r"].rotation = Vector3(0.3, 0, 0.35)
			j["elbow_l"].rotation.x = 0.5
			j["elbow_r"].rotation.x = 0.6
		_:
			j["spine"].rotation.x = -0.55
			j["head"].rotation.x = 0.45
			j["arm_l"].rotation = Vector3(-0.7, 0, -0.25)
			j["arm_r"].rotation = Vector3(-0.5, 0, 0.25)
			j["elbow_l"].rotation.x = 0.9
			j["elbow_r"].rotation.x = 1.1
	# Manchas de sangre irregulares en el pecho y la boca
	var spots := [[Vector3(0.06, 0.3, -0.118), Vector3(0.05, 0.07, 0.012)], [Vector3(0.02, 0.2, -0.122), Vector3(0.03, 0.05, 0.012)], [Vector3(-0.09, 0.14, -0.115), Vector3(0.035, 0.03, 0.012)]]
	if kind == "b":
		spots = [[Vector3(0.1, 0.32, -0.158), Vector3(0.06, 0.08, 0.014)], [Vector3(-0.1, 0.2, -0.16), Vector3(0.04, 0.09, 0.014)], [Vector3(0.02, 0.12, -0.15), Vector3(0.05, 0.03, 0.014)]]
	for k in spots.size():
		var w := MeshInstance3D.new()
		w.mesh = Nature.blob(40 + k, 0.3, 6, 3, false)
		w.material_override = CharacterModel.mat(Color("5e1410"))
		w.position = spots[k][0]
		w.scale = spots[k][1]
		j["spine"].add_child(w)
	var jaw := MeshInstance3D.new()
	jaw.mesh = Nature.blob(77, 0.3, 6, 3, false)
	jaw.material_override = CharacterModel.mat(Color("4e100c"))
	jaw.position = Vector3(0.005, -0.082, -0.1)
	jaw.scale = Vector3(0.028, 0.02, 0.012)
	j["head"].add_child(jaw)
	return c


## Propuestas de modelos: pinos, rocas e infectados (A, B, C).
func _props() -> void:
	var ground := func():
		var g := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 9.0
		pm.bottom_radius = 9.0
		pm.height = 0.02
		g.mesh = pm
		g.material_override = CharacterModel.mat(Color("6f9a56"))
		g.position.y = -0.01
		stage.add_child(g)
	# Pinos (con el superviviente para la escala)
	_clear()
	ground.call()
	var makers := [Nature.pine_a, Nature.pine_b, Nature.pine_c]
	for k in 3:
		for v in 2:
			var t: Node3D = makers[k].call(k * 10 + v + 1)
			t.position = Vector3(4.2 - k * 4.2 - v * 1.7, 0, v * 1.6)
			t.scale = Vector3.ONE * (1.0 if v == 0 else 0.8)
			stage.add_child(t)
	_char({"sex": "m", "hair": 4}, {}, {"torso": "camiseta", "piernas": "pantalon_cargo", "pies": "botas"}, Vector3(6.0, 0, -0.6), 0.4)
	await _shot("prop_pinos", Vector2i(1400, 760), Vector3(0.4, 4.2, -12.5), Vector3(0.4, 1.7, 0), 32)
	# Rocas
	_clear()
	ground.call()
	var rocks := [Nature.rock_a, Nature.rock_b, Nature.rock_c]
	for k in 3:
		for v in 2:
			var r: Node3D = rocks[k].call(k * 10 + v + 1)
			r.position = Vector3(3.6 - k * 3.6 - v * 1.5, 0, v * 1.5 - 0.2)
			r.scale = Vector3.ONE * (1.0 if v == 0 else 0.7)
			r.rotation.y = v * 1.7
			stage.add_child(r)
	_char({"sex": "m", "hair": 4}, {}, {"torso": "camiseta", "piernas": "pantalon_cargo", "pies": "botas"}, Vector3(5.3, 0, -0.3), 0.4)
	await _shot("prop_rocas", Vector2i(1400, 620), Vector3(0.3, 3.0, -9.0), Vector3(0.3, 0.6, 0), 34)
	# Infectados
	_clear()
	ground.call()
	await _zombie("a", Vector3(1.7, 0, 0), -0.35)
	await _zombie("b", Vector3(0.1, 0, 0), 0.2)
	await _zombie("c", Vector3(-1.5, 0, 0), 0.45)
	await _shot("prop_infectados", Vector2i(1400, 900), Vector3(0.1, 1.3, -5.6), Vector3(0.1, 0.95, 0), 30)
	_clear()
	ground.call()
	await _zombie("a", Vector3(1.7, 0, 0), PI / 2.0)
	await _zombie("b", Vector3(0.1, 0, 0), PI / 2.0)
	await _zombie("c", Vector3(-1.5, 0, 0), PI / 2.0)
	await _shot("prop_infectados_lado", Vector2i(1400, 900), Vector3(0.1, 1.3, -5.6), Vector3(0.1, 0.95, 0), 30)


## Superviviente de frente para la pantalla de mochila.
func _inventory() -> void:
	var M := {"sex": "m", "skin": 1, "hair": 4, "hair_color": 1, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 4}
	var F := {"sex": "f", "skin": 2, "hair": 1, "hair_color": 0, "eyes": 1, "eye_color": 2, "nose": 0, "mouth": 2}
	var sets := [
		["inv_m_ropa", M, {"fuerza": 0.35}, {"cabeza": "gorra", "torso": "chaqueta_piel", "piernas": "pantalon_cargo", "pies": "botas", "manos": "guantes", "espalda": "mochila"}, "hacha_hierro"],
		["inv_m_basico", M, {}, {"torso": "camiseta", "piernas": "pantalon_tela", "pies": "zapatillas"}, "hacha_piedra"],
		["inv_f_ropa", F, {"fuerza": 0.2}, {"cabeza": "casco_obra", "torso": "chaleco", "piernas": "pantalon_cargo", "pies": "botas", "espalda": "mochila"}, "machete"],
		["inv_m_interior", M, {}, {}, ""],
	]
	for st in sets:
		_clear()
		var c := _char(st[1], st[2], st[3], Vector3.ZERO, 0.18)
		if st[4] != "" and false:
			var t := Builder.tool_mesh(st[4])
			t.rotation_degrees.x = -80.0
			c.hand.add_child(t)
		await _shot(st[0], Vector2i(520, 1000), Vector3(0.0, 1.0, -4.7), Vector3(0, 0.92, 0), 26)
	# Agachado, de lado y de frente
	_clear()
	var cr := _char(M, {}, {"torso": "camiseta", "piernas": "pantalon_cargo", "pies": "botas", "espalda": "mochila"}, Vector3.ZERO, 0.0)
	cr.animate_walk(0.0, 0.0)
	cr.animate_crouch(1.0)
	await _shot("agachado_lado", Vector2i(700, 800), Vector3(-4.2, 0.9, 0.0), Vector3(0, 0.7, 0), 26)
	await _shot("agachado_frente", Vector2i(700, 800), Vector3(1.5, 1.4, -3.8), Vector3(0, 0.7, 0), 26)


func _all(only_heads := false) -> void:
	var M := {"sex": "m", "skin": 1, "hair": 1, "hair_color": 1, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 1}
	var F := {"sex": "f", "skin": 2, "hair": 2, "hair_color": 0, "eyes": 1, "eye_color": 2, "nose": 4, "mouth": 2}
	var body_eye := Vector3(1.6, 1.25, -4.2)
	var body_t := Vector3(0, 0.88, 0)

	# 1. Personaje principal (cuerpo entero, tres cuartos)
	for pair in ([] if only_heads else [["hero_m", M], ["hero_f", F]]):
		_clear()
		_char(pair[1])
		await _shot(pair[0], Vector2i(600, 1000), body_eye, body_t, 28)

	# 2. Cabezas para las opciones (5 de cada)
	var head_eye := Vector3(0.18, 1.76, -0.95)
	var head_t := Vector3(0, 1.67, 0)
	for sex in ["m", "f"]:
		var base: Dictionary = (M if sex == "m" else F).duplicate()
		for i in 5:
			_clear()
			var l := base.duplicate()
			l["hair"] = i
			_char(l)
			await _shot("pelo_%s_%d" % [sex, i], Vector2i(260, 260), head_eye * Vector3(1, 1 if sex == "m" else 0.97, 1), head_t * Vector3(1, 1 if sex == "m" else 0.95, 1), 26)
		for i in 5:
			_clear()
			var l2 := base.duplicate()
			l2["hair_color"] = i
			_char(l2)
			await _shot("color_pelo_%s_%d" % [sex, i], Vector2i(260, 260), head_eye * Vector3(1, 1 if sex == "m" else 0.97, 1), head_t * Vector3(1, 1 if sex == "m" else 0.95, 1), 26)
		for i in 5:
			_clear()
			var l3 := base.duplicate()
			l3["skin"] = i
			_char(l3)
			await _shot("piel_%s_%d" % [sex, i], Vector2i(260, 260), head_eye * Vector3(1, 1 if sex == "m" else 0.97, 1), head_t * Vector3(1, 1 if sex == "m" else 0.95, 1), 26)
	var face_eye := Vector3(0.0, 1.64, -0.55)
	var face_t := Vector3(0, 1.6, 0)
	for feat in ["eyes", "nose", "mouth", "eye_color"]:
		for i in 5:
			_clear()
			var l4 := M.duplicate()
			l4[feat] = i
			_char(l4)
			var ty := 1.698 if feat == "eyes" or feat == "eye_color" else (1.675 if feat == "nose" else 1.63)
			var side_x := 0.0 if feat == "eyes" or feat == "eye_color" else 0.2
			await _shot("%s_%d" % [feat, i], Vector2i(260, 260), Vector3(side_x, ty + 0.02, -0.42), Vector3(0, ty, 0), 24)

	if only_heads:
		return
	# 3. Despiece de partes
	_clear()
	_char(M, {}, {}, Vector3.ZERO, 0.35, 1.0)
	await _shot("despiece_m", Vector2i(700, 1100), Vector3(1.4, 1.35, -4.9), Vector3(0, 0.95, 0), 28)

	# 4. Ropa: llegada, primeros días, veterano
	var outfits := [
		{},
		{"torso": "camiseta", "piernas": "pantalon_tela", "pies": "zapatillas"},
		{"torso": "chaqueta_piel", "piernas": "pantalon_cargo", "pies": "botas", "cabeza": "casco_obra", "manos": "guantes", "espalda": "mochila"},
	]
	for sex in ["m", "f"]:
		for i in 3:
			_clear()
			_char(M if sex == "m" else F, {"fuerza": 0.2 * i, "resistencia": 0.2 * i}, outfits[i])
			await _shot("ropa_%s_%d" % [sex, i], Vector2i(420, 760), body_eye, body_t, 28)
	# mochila vista desde atrás
	_clear()
	_char(M, {"fuerza": 0.4, "resistencia": 0.4}, outfits[2], Vector3.ZERO, PI - 0.5)
	await _shot("ropa_m_2_espalda", Vector2i(420, 760), body_eye, body_t, 28)

	# 5. Físico: inicio, en forma, curtido
	for sex in ["m", "f"]:
		for i in 3:
			_clear()
			_char(M if sex == "m" else F, {"fuerza": [0.0, 0.5, 1.0][i], "resistencia": [0.0, 0.6, 1.0][i]})
			await _shot("fisico_%s_%d" % [sex, i], Vector2i(420, 760), Vector3(0.6, 1.2, -4.3), body_t, 28)

	# 6. Pareja para la portada
	_clear()
	_char(M, {}, {}, Vector3(-0.45, 0, 0), 0.25)
	_char(F, {}, {}, Vector3(0.45, 0, 0), -0.25)
	await _shot("pareja", Vector2i(900, 1000), Vector3(0.6, 1.3, -4.8), Vector3(0, 0.88, 0), 30)


func _quick() -> void:
	var M := {"sex": "m", "skin": 1, "hair": 1, "hair_color": 1, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 1}
	var F := {"sex": "f", "skin": 2, "hair": 2, "hair_color": 0, "eyes": 1, "eye_color": 2, "nose": 4, "mouth": 2}
	_clear()
	_char(M, {}, {}, Vector3(-0.45, 0, 0), 0.25)
	_char(F, {}, {}, Vector3(0.45, 0, 0), -0.25)
	await _shot("quick", Vector2i(900, 1000), Vector3(0.6, 1.3, -4.8), Vector3(0, 0.88, 0), 30)
	_clear()
	_char(M, {"fuerza": 0.4, "resistencia": 0.4}, {"torso": "chaqueta_piel", "piernas": "pantalon_cargo", "pies": "botas", "cabeza": "casco_obra", "manos": "guantes", "espalda": "mochila"}, Vector3(-0.45, 0, 0), 0.25)
	_char(F, {"fuerza": 0.2}, {"torso": "camiseta", "piernas": "pantalon_tela", "pies": "zapatillas"}, Vector3(0.45, 0, 0), -0.25)
	await _shot("quick2", Vector2i(900, 1000), Vector3(0.6, 1.3, -4.8), Vector3(0, 0.88, 0), 30)
	_clear()
	_char(M)
	await _shot("quick3", Vector2i(400, 400), Vector3(0.25, 1.72, -0.8), Vector3(0, 1.67, 0), 28)
